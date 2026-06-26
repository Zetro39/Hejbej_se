import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class AchievementService {
  static final List<String> achievementIds = [
    'dist_1km', 'dist_10km', 'dist_100km', 'dist_1000km', 'dist_10000km', 'dist_40000km',
    'loyaltyAchievement_0', 'loyaltyAchievement_1', 'loyaltyAchievement_2',
    'steps_achievement_5', 'steps_achievement_10', 'steps_achievement_25',
    'steps_achievement_50', 'steps_achievement_100', 'steps_achievement_365',
    'achievement_hero_lost_amulet', 'achievement_story_difficulty_easy',
    'achievement_story_difficulty_medium', 'achievement_story_difficulty_hard',
    'achievement_story_difficulty_hardcore',
    'checkpoint_1', 'checkpoint_2', 'checkpoint_3', 'checkpoint_4', 'checkpoint_5',
    'invited_friends_1', 'invited_friends_5', 'invited_friends_10',
    'ever_owned_premium', 'premium_for_year'
  ];

  static Map<String, double>? _raritiesCache;
  static DateTime? _lastCacheFetch;

  /// Calculates the current user's achievement stats.
  /// Returns a map with 'unlocked' achievement IDs, the completion 'ratio', and total 'count'.
  static Future<Map<String, dynamic>> calculateCompletionRate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Total distance from DistanceManager
    final totalDistance = DistanceManager().totalDistance;

    // Friends count
    int friendsCount = prefs.getInt('invited_friends_count') ?? 0;
    
    // Check if premium is active or ever owned
    final isPrem = prefs.getBool('isPremium') ?? false;
    final everOwned = prefs.getBool('ever_owned_premium') ?? false || isPrem;
    final premiumStartTimeStr = prefs.getString('premium_start_time');
    bool premForYear = prefs.getBool('premium_for_year') ?? false;
    if (premiumStartTimeStr != null) {
      try {
        final startTime = DateTime.parse(premiumStartTimeStr);
        if (DateTime.now().difference(startTime).inDays >= 365) {
          premForYear = true;
        }
      } catch (_) {}
    }
    if (prefs.getBool('simulate_year_premium') == true) {
      premForYear = true;
    }

    final List<String> unlocked = [];

    // 1. Distance
    if (totalDistance >= 1.0) unlocked.add('dist_1km');
    if (totalDistance >= 10.0) unlocked.add('dist_10km');
    if (totalDistance >= 100.0) unlocked.add('dist_100km');
    if (totalDistance >= 1000.0) unlocked.add('dist_1000km');
    if (totalDistance >= 10000.0) unlocked.add('dist_10000km');
    if (totalDistance >= 40000.0) unlocked.add('dist_40000km');

    // 2. Loyalty (streaks)
    if (prefs.getBool('loyaltyAchievement_0') == true) unlocked.add('loyaltyAchievement_0');
    if (prefs.getBool('loyaltyAchievement_1') == true) unlocked.add('loyaltyAchievement_1');
    if (prefs.getBool('loyaltyAchievement_2') == true) unlocked.add('loyaltyAchievement_2');

    // 3. Steps
    final milestones = [5, 10, 25, 50, 100, 365];
    for (final m in milestones) {
      if (prefs.getBool('steps_achievement_$m') == true) {
        unlocked.add('steps_achievement_$m');
      }
    }

    // 4. Story
    if (prefs.getBool('achievement_hero_lost_amulet') == true) unlocked.add('achievement_hero_lost_amulet');
    if (prefs.getBool('achievement_story_difficulty_easy') == true) unlocked.add('achievement_story_difficulty_easy');
    if (prefs.getBool('achievement_story_difficulty_medium') == true) unlocked.add('achievement_story_difficulty_medium');
    if (prefs.getBool('achievement_story_difficulty_hard') == true) unlocked.add('achievement_story_difficulty_hard');
    if (prefs.getBool('achievement_story_difficulty_hardcore') == true) unlocked.add('achievement_story_difficulty_hardcore');

    // 5. Checkpoints
    for (int i = 1; i <= 5; i++) {
      if (prefs.getBool('achievement_checkpoint_${i}_reached') == true) {
        unlocked.add('checkpoint_$i');
      }
    }

    // 6. Social
    if (friendsCount >= 1) unlocked.add('invited_friends_1');
    if (friendsCount >= 5) unlocked.add('invited_friends_5');
    if (friendsCount >= 10) unlocked.add('invited_friends_10');
    if (everOwned) unlocked.add('ever_owned_premium');
    if (premForYear) unlocked.add('premium_for_year');

    final ratio = unlocked.length / achievementIds.length;
    return {
      'unlocked': unlocked,
      'ratio': ratio,
      'count': unlocked.length,
    };
  }

  /// Synchronizes the user's achievements stats to Firestore if they are opted-in as a collector.
  /// If [optIn] is true, sets their status as collector.
  static Future<void> syncUserAchievements({bool optIn = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    bool isCollector = prefs.getBool('is_achievement_collector') ?? false;
    
    if (optIn) {
      isCollector = true;
      await prefs.setBool('is_achievement_collector', true);
    }
    
    if (!isCollector) {
      // Check database status for fallback
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          isCollector = doc.data()?['is_achievement_collector'] as bool? ?? false;
          if (isCollector) {
            await prefs.setBool('is_achievement_collector', true);
          }
        }
      } catch (_) {}
    }
    
    if (!isCollector) return;

    final completion = await calculateCompletionRate();
    final unlocked = completion['unlocked'] as List<String>;
    final ratio = completion['ratio'] as double;
    final count = completion['count'] as int;
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'is_achievement_collector': true,
        'unlocked_achievements': unlocked,
        'achievement_completion_ratio': ratio,
        'achievement_count': count,
      });
    } catch (_) {
      // In case update fails because document doesn't have it or set is needed
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'is_achievement_collector': true,
        'unlocked_achievements': unlocked,
        'achievement_completion_ratio': ratio,
        'achievement_count': count,
      }, SetOptions(merge: true));
    }
  }

  /// Fetches achievement rarities from Firestore count queries.
  static Future<Map<String, double>> getAchievementRarities() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get total number of registered collectors
      final totalQuery = await firestore
          .collection('users')
          .where('is_achievement_collector', isEqualTo: true)
          .count()
          .get();
      final total = totalQuery.count ?? 0;
      
      if (total == 0) {
        return {};
      }
      
      final Map<String, double> rarities = {};
      
      // Query in parallel
      final futures = achievementIds.map((id) async {
        try {
          final countQuery = await firestore
              .collection('users')
              .where('is_achievement_collector', isEqualTo: true)
              .where('unlocked_achievements', arrayContains: id)
              .count()
              .get();
          final unlockedCount = countQuery.count ?? 0;
          final percentage = (unlockedCount / total) * 100.0;
          rarities[id] = percentage;
        } catch (_) {
          rarities[id] = 0.0;
        }
      }).toList();
      
      await Future.wait(futures);
      return rarities;
    } catch (_) {
      return {};
    }
  }

  /// Fetches achievement rarities using a 10-minute cache layer to protect Firestore query usage.
  static Future<Map<String, double>> getCachedAchievementRarities() async {
    final now = DateTime.now();
    if (_raritiesCache != null && _lastCacheFetch != null && now.difference(_lastCacheFetch!).inMinutes < 10) {
      return _raritiesCache!;
    }
    
    final fetched = await getAchievementRarities();
    if (fetched.isNotEmpty) {
      _raritiesCache = fetched;
      _lastCacheFetch = now;
    }
    return fetched;
  }
}
