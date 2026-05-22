import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    try {
      await cred.user?.sendEmailVerification();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to send email verification: $e');
    }

    // Create basic user document with registration timestamp and default stats
    final uid = cred.user?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'emailVerified': cred.user?.emailVerified ?? false,
        'registration_date': FieldValue.serverTimestamp(),
        'strikes': 0,
        'limetky': 0,
      }, SetOptions(merge: true));
    }

    return cred;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  Future<bool> isBlockedDueToUnverified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final verified = user.emailVerified;

    if (verified) {
      // Ensure Firestore reflects verification
      await _firestore.collection('users').doc(user.uid).set({'emailVerified': true}, SetOptions(merge: true));
      return false;
    }

    // Fetch registration date from Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final ts = doc.data()?['registration_date'];
    if (ts == null) return false;

    DateTime regDate;
    if (ts is Timestamp) {
      regDate = ts.toDate();
    } else if (ts is DateTime) {
      regDate = ts;
    } else {
      return false;
    }

    final diff = DateTime.now().difference(regDate);
    if (diff.inHours >= 1 && !verified) {
      return true; // blocked
    }
    return false;
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
}
