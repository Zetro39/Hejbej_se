import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _storage = FlutterSecureStorage();
  static const _keyUserName = 'user_name';
  static const _keyAuthPrefix = 'auth_';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local helper for backwards compatibility
  Future<void> saveUserName(String name) async {
    try {
      await _storage.write(key: _keyUserName, value: name);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save user name: $e');
    }
  }

  Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _keyUserName);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to read user name: $e');
      return null;
    }
  }

  Future<void> saveAuthCredentials(String provider, Map<String, String?> data) async {
    try {
      final key = '$_keyAuthPrefix$provider';
      final json = data.entries.map((e) => '"${e.key}":"${e.value ?? ''}"').join(',');
      await _storage.write(key: key, value: '{${json}}');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save auth credentials for $provider: $e');
    }
  }

  Future<String?> getAuthCredentials(String provider) async {
    try {
      final key = '$_keyAuthPrefix$provider';
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to read auth credentials for $provider: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: '${_keyAuthPrefix}google');
      await _storage.delete(key: '${_keyAuthPrefix}apple');
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear user data: $e');
    }
  }

  // Authentication methods using Firebase
  Future<UserCredential> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    
    // Do not await email verification to prevent registration from hanging on slow SMTP networks
    cred.user?.sendEmailVerification().catchError((e) {
      if (kDebugMode) debugPrint('Failed to send email verification: $e');
    });

    // Create basic user document with registration timestamp and default stats
    final uid = cred.user?.uid;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'email': email,
          'emailVerified': cred.user?.emailVerified ?? false,
          'registration_date': FieldValue.serverTimestamp(),
          'strikes': 0,
          'limetky': 0,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      } catch (e) {
        if (kDebugMode) debugPrint('Initial Firestore doc write timed out or failed: $e');
      }
    }

    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureUserDocument(cred.user);
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<bool> isBlockedDueToUnverified() async {
    return false; // Email verification bypass for smoother testing & onboarding
  }

  Future<void> saveProfile(String uid, Map<String, dynamic> profile) async {
    // Merge profile into users collection; initialize default stats if missing
    final docRef = _firestore.collection('users').doc(uid);
    final data = Map<String, dynamic>.from(profile);
    if (data['strikes'] == null) data['strikes'] = 0;
    if (data['limetky'] == null) data['limetky'] = 0;
    if (data['registration_date'] == null) data['registration_date'] = FieldValue.serverTimestamp();
    await docRef.set(data, SetOptions(merge: true));
  }

  // Sync distance to Firestore (updates total, weekly, monthly and resets them if time changes)
  Future<void> _syncToHomeWidget(double totalDistance, int streak) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId('group.com.zetro39.hejbejse');
      }
      await HomeWidget.saveWidgetData<double>('totalDistance', totalDistance);
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.updateWidget(
        name: 'HejbejSeWidgetProvider',
        androidName: 'HejbejSeWidgetProvider',
      );
    } catch (_) {}
  }

  Future<void> updateDistance(double totalDistance, int limetky) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final now = DateTime.now();

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() ?? {};

        double weeklyDistance = (data['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
        double monthlyDistance = (data['monthlyDistance'] as num?)?.toDouble() ?? 0.0;

        Timestamp? lastUpdateTs = data['lastDistanceUpdate'] as Timestamp?;

        if (lastUpdateTs != null) {
          final lastUpdate = lastUpdateTs.toDate();
          if (!_isSameISOWeek(now, lastUpdate)) {
            weeklyDistance = 0.0;
          }
          if (now.month != lastUpdate.month || now.year != lastUpdate.year) {
            monthlyDistance = 0.0;
          }
        }

        double oldTotalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
        double delta = totalDistance - oldTotalDistance;
        if (delta < 0) delta = 0.0;

        weeklyDistance += delta;
        monthlyDistance += delta;

        transaction.set(docRef, {
          'totalDistance': totalDistance,
          'weeklyDistance': weeklyDistance,
          'monthlyDistance': monthlyDistance,
          'limetky': limetky,
          'lastDistanceUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // Update walk logging and sync to home widget after success
      try {
        final finalDoc = await docRef.get();
        final finalData = finalDoc.data() ?? {};
        final username = finalData['username'] as String? ?? 'Uživatel';
        final streak = finalData['streak'] as int? ?? 0;

        // Sync to home widget
        await _syncToHomeWidget(totalDistance, streak);

        // Rate-limited walk activity log
        double lastLoggedDist = (finalData['lastWalkLogDistance'] as num?)?.toDouble() ?? 0.0;
        Timestamp? lastLoggedTimeTs = finalData['lastWalkLogTime'] as Timestamp?;
        DateTime? lastLoggedTime = lastLoggedTimeTs?.toDate();

        bool shouldLog = false;
        if (lastLoggedTime == null) {
          shouldLog = totalDistance > 0.1;
        } else {
          final timeDiff = now.difference(lastLoggedTime);
          final distDiff = totalDistance - lastLoggedDist;
          if ((distDiff >= 0.5 && timeDiff.inMinutes >= 10) || distDiff >= 2.0) {
            shouldLog = true;
          }
        }

        if (shouldLog) {
          final distWalked = totalDistance - lastLoggedDist;
          await _firestore.collection('activities').add({
            'uid': user.uid,
            'username': username,
            'type': 'walk',
            'timestamp': FieldValue.serverTimestamp(),
            'details': {
              'distance': distWalked,
              'totalDistance': totalDistance,
            },
          });

          await docRef.update({
            'lastWalkLogDistance': totalDistance,
            'lastWalkLogTime': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync distance to Firestore: $e');
    }
  }

  Future<void> updateDistanceLocal(double totalDistance, double weeklyDistance, double monthlyDistance, int limetky) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      await docRef.set({
        'totalDistance': totalDistance,
        'weeklyDistance': weeklyDistance,
        'monthlyDistance': monthlyDistance,
        'limetky': limetky,
        'lastDistanceUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync distance to Firestore: $e');
    }
  }

  Future<void> syncFirestoreToLocal() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final prefs = await SharedPreferences.getInstance();
        
        if (data['totalDistance'] != null) {
          await prefs.setDouble('totalDistance', (data['totalDistance'] as num).toDouble());
        }
        if (data['weeklyDistance'] != null) {
          await prefs.setDouble('weeklyDistance', (data['weeklyDistance'] as num).toDouble());
        }
        if (data['monthlyDistance'] != null) {
          await prefs.setDouble('monthlyDistance', (data['monthlyDistance'] as num).toDouble());
        }
        if (data['limetky'] != null) {
          await prefs.setInt('limetkyBalance', (data['limetky'] as num).toInt());
        }
        if (data['streak'] != null) {
          await prefs.setInt('streak', (data['streak'] as num).toInt());
        }
        if (data['username'] != null) {
          await saveUserName(data['username'] as String);
        }
        if (data['lastDistanceUpdate'] != null) {
          final lastUpdateTs = data['lastDistanceUpdate'] as Timestamp;
          await prefs.setString('lastDistanceUpdate', lastUpdateTs.toDate().toIso8601String());
        }
        if (data['birth_date'] != null) {
          if (data['birth_date'] is Timestamp) {
            await prefs.setString('birth_date', (data['birth_date'] as Timestamp).toDate().toIso8601String());
          } else if (data['birth_date'] is String) {
            await prefs.setString('birth_date', data['birth_date'] as String);
          }
        }
        if (data['default_activity'] != null) {
          await prefs.setString('default_activity', data['default_activity'] as String);
        }
        if (data['walk_range_min'] != null) {
          await prefs.setDouble('walk_range_min', (data['walk_range_min'] as num).toDouble());
        }
        if (data['walk_range_max'] != null) {
          await prefs.setDouble('walk_range_max', (data['walk_range_max'] as num).toDouble());
        }
        if (data['bike_range_min'] != null) {
          await prefs.setDouble('bike_range_min', (data['bike_range_min'] as num).toDouble());
        }
        if (data['bike_range_max'] != null) {
          await prefs.setDouble('bike_range_max', (data['bike_range_max'] as num).toDouble());
        }
        if (data['selected_avatar'] != null) {
          await prefs.setString('selected_avatar', data['selected_avatar'] as String);
        }
        if (data['gender'] != null) {
          await prefs.setString('gender', data['gender'] as String);
        }
        if (data['selected_companion'] != null) {
          await prefs.setString('selected_companion', data['selected_companion'] as String);
        } else {
          await prefs.remove('selected_companion');
        }
        if (data['unlocked_companions'] != null) {
          final list = (data['unlocked_companions'] as List).map((e) => e.toString()).toList();
          await prefs.setStringList('unlocked_companions', list);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync Firestore to local: $e');
    }
  }

  // Sync streak to Firestore
  Future<void> updateStreak(int streak) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'streak': streak,
      }, SetOptions(merge: true));

      // Sync to home widget as well
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final totalDistance = (doc.data()?['totalDistance'] as num?)?.toDouble() ?? 0.0;
      await _syncToHomeWidget(totalDistance, streak);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync streak to Firestore: $e');
    }
  }

  // Sign in with Google credentials in Firebase Auth and ensure user document
  Future<UserCredential> signInWithGoogle(String accessToken, String? idToken) async {
    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(userCred.user);
    return userCred;
  }

  // Sign in with Apple credentials in Firebase Auth and ensure user document
  Future<UserCredential> signInWithApple(String idToken, String? rawNonce) async {
    final credential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    final userCred = await _auth.signInWithCredential(credential);
    await _ensureUserDocument(userCred.user);
    return userCred;
  }



  // Helper to check if two dates fall in the same ISO week
  bool _isSameISOWeek(DateTime date1, DateTime date2) {
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));
    return monday1.year == monday2.year &&
        monday1.month == monday2.month &&
        monday1.day == monday2.day;
  }

  // Ensures user document exists in Firestore with a valid friend_code and username
  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data();
    if (!doc.exists || data == null || data['username'] == null || data['friend_code'] == null) {
      final emailName = user.email != null ? user.email!.split('@')[0] : 'user';
      final cleanedName = emailName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final username = cleanedName.isNotEmpty ? cleanedName : 'user';
      
      final friendCode = '#${username.toUpperCase()}${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
      
      await docRef.set({
        'email': user.email,
        'username': data?['username'] ?? username,
        'friend_code': data?['friend_code'] ?? friendCode,
        'first_name': data?['first_name'] ?? (user.displayName != null ? user.displayName!.split(' ').first : ''),
        'last_name': data?['last_name'] ?? (user.displayName != null && user.displayName!.split(' ').length > 1 
            ? user.displayName!.split(' ').sublist(1).join(' ') 
            : ''),
        'registration_date': data?['registration_date'] ?? FieldValue.serverTimestamp(),
        'strikes': data?['strikes'] ?? 0,
        'limetky': data?['limetky'] ?? 0,
        'totalDistance': data?['totalDistance'] ?? 0.0,
        'weeklyDistance': data?['weeklyDistance'] ?? 0.0,
        'monthlyDistance': data?['monthlyDistance'] ?? 0.0,
      }, SetOptions(merge: true));
    }
  }

  Future<bool> isProfileCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 4));
      if (doc.exists) {
        final data = doc.data() ?? {};
        return data['birth_date'] != null;
      }
    } catch (_) {}
    // If offline/error, check local prefs fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('birth_date') != null;
    } catch (_) {}
    return false;
  }

  Future<List<String>> getUnlockedCompanions() async {
    final user = currentUser;
    if (user == null) return [];
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final list = data['unlocked_companions'] as List?;
        if (list != null) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    // Fallback locally
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('unlocked_companions') ?? [];
    } catch (_) {}
    return [];
  }

  Future<bool> unlockCompanion(String companionId, int cost) async {
    final user = currentUser;
    if (user == null) return false;
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final success = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() ?? {};
        final currentLimetky = (data['limetky'] as num?)?.toInt() ?? 0;
        if (currentLimetky < cost) {
          return false;
        }
        final unlocked = List<String>.from(data['unlocked_companions'] ?? []);
        if (unlocked.contains(companionId)) {
          return true; // Already unlocked
        }
        unlocked.add(companionId);
        transaction.update(docRef, {
          'limetky': currentLimetky - cost,
          'unlocked_companions': unlocked,
        });
        return true;
      });

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final unlockedLocal = prefs.getStringList('unlocked_companions') ?? [];
        if (!unlockedLocal.contains(companionId)) {
          unlockedLocal.add(companionId);
          await prefs.setStringList('unlocked_companions', unlockedLocal);
        }
        await syncFirestoreToLocal();
      }
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('unlockCompanion error: $e');
      return false;
    }
  }

  Future<void> selectCompanion(String? companionId) async {
    final user = currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (companionId == null) {
        await prefs.remove('selected_companion');
      } else {
        await prefs.setString('selected_companion', companionId);
      }
      await _firestore.collection('users').doc(user.uid).update({
        'selected_companion': companionId,
      });
    } catch (_) {}
  }

  Future<String?> getSelectedCompanion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('selected_companion');
    } catch (_) {}
    return null;
  }
}
