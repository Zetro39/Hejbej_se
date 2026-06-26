import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

class AchievementService {
  static final List<String> achievementIds = [
    // 1. Chůze celkově (6 tiers)
    'dist_1km', 'dist_10km', 'dist_100km', 'dist_1000km', 'dist_10000km', 'dist_40000km',
    
    // 2. Kolo celkově (6 tiers)
    'bike_10km', 'bike_50km', 'bike_200km', 'bike_1000km', 'bike_5000km', 'bike_15000km',
    
    // 3. Dlouhá jízda (2 tiers)
    'bike_single_50km', 'bike_single_100km',
    
    // 4. Vrchařská prémie (2 tiers)
    'bike_climb_500m', 'bike_climb_2000m',
    
    // 5. Věrný uživatel (2 tiers)
    'loyalty_half_year', 'loyalty_anniversary',
    
    // 6. Série přihlášení (3 tiers)
    'loyaltyAchievement_0', 'loyaltyAchievement_1', 'loyaltyAchievement_2',
    
    // 7. Svědomitý chodec (6 tiers)
    'steps_achievement_5', 'steps_achievement_10', 'steps_achievement_25',
    'steps_achievement_50', 'steps_achievement_100', 'steps_achievement_365',
    
    // 8. Hledač checkpointů (5 tiers)
    'checkpoint_1', 'checkpoint_2', 'checkpoint_3', 'checkpoint_4', 'checkpoint_5',
    
    // 9. Mistr okruhů (3 tiers)
    'route_first_loop', 'route_10_loops', 'route_50_loops',
    
    // 10. Krajský turista (3 tiers)
    'route_explore_kraj_3', 'route_explore_kraj_7', 'route_explore_kraj_14',
    
    // 11. Podporovatel reklamami (2 tiers)
    'shop_ad_first', 'shop_ad_50',
    
    // 12. Limetkový magnát (3 tiers)
    'shop_limetky_10', 'shop_limetky_100', 'shop_limetky_500',
    
    // 13. Sběratel společníků (2 tiers)
    'shop_companion_buy_1', 'shop_companion_buy_3',
    
    // 14. Mecenáš (2 tiers)
    'ever_owned_premium', 'premium_for_year',
    
    // 15. Encyklopedie (3 tiers)
    'trivia_first_correct', 'trivia_10_correct', 'trivia_50_correct',
    
    // 16. Fair Play (3 tiers)
    'anticheat_clean_10', 'anticheat_clean_50', 'anticheat_clean_100',
    
    // 17. Nová krev (3 tiers)
    'invited_friends_1', 'invited_friends_5', 'invited_friends_10',
    
    // Single Achievements (15)
    'loyalty_pioneer',
    'loyalty_early_bird',
    'loyalty_night_owl',
    'loyalty_new_year',
    'loyalty_weekend_warrior',
    'route_first_atob',
    'route_atob_long',
    'route_scan_qr',
    'route_share_code',
    'shop_ad_3_days',
    'trivia_perfect_route',
    'trivia_unlocked_10',
    'misc_premium_first_day',
    'misc_tutorial_finished',
    'achievement_hero_lost_amulet',
    'achievement_story_difficulty_easy',
    'achievement_story_difficulty_medium',
    'achievement_story_difficulty_hard',
    'achievement_story_difficulty_hardcore',
  ];

  static Map<String, double>? _raritiesCache;
  static DateTime? _lastCacheFetch;

  /// Calculates the current user's achievement stats.
  /// Returns a map with 'unlocked' achievement IDs, the completion 'ratio', and total 'count'.
  static Future<Map<String, dynamic>> calculateCompletionRate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Total walking distance
    final totalDistance = DistanceManager().totalDistance;
    
    // Total cycling distance
    final totalDistanceCycling = DistanceManager().totalDistanceCycling;

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

    // 1. Walking Distance
    if (totalDistance >= 1.0) unlocked.add('dist_1km');
    if (totalDistance >= 10.0) unlocked.add('dist_10km');
    if (totalDistance >= 100.0) unlocked.add('dist_100km');
    if (totalDistance >= 1000.0) unlocked.add('dist_1000km');
    if (totalDistance >= 10000.0) unlocked.add('dist_10000km');
    if (totalDistance >= 40000.0) unlocked.add('dist_40000km');

    // 2. Cycling Distance
    if (totalDistanceCycling >= 10.0) unlocked.add('bike_10km');
    if (totalDistanceCycling >= 50.0) unlocked.add('bike_50km');
    if (totalDistanceCycling >= 200.0) unlocked.add('bike_200km');
    if (totalDistanceCycling >= 1000.0) unlocked.add('bike_1000km');
    if (totalDistanceCycling >= 5000.0) unlocked.add('bike_5000km');
    if (totalDistanceCycling >= 15000.0) unlocked.add('bike_15000km');

    // 3. Single Bike Ride
    final maxSingleBike = prefs.getDouble('max_single_bike_distance') ?? 0.0;
    if (maxSingleBike >= 50.0) unlocked.add('bike_single_50km');
    if (maxSingleBike >= 100.0) unlocked.add('bike_single_100km');

    // 4. Cycling Climb
    final maxClimb = prefs.getDouble('max_single_bike_climb') ?? 0.0;
    if (maxClimb >= 500.0) unlocked.add('bike_climb_500m');
    if (maxClimb >= 2000.0) unlocked.add('bike_climb_2000m');

    // 5. Loyalty Duration
    final creationTime = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    if (creationTime != null) {
      final days = DateTime.now().difference(creationTime).inDays;
      if (days >= 180) unlocked.add('loyalty_half_year');
      if (days >= 365) unlocked.add('loyalty_anniversary');
      if (creationTime.year == 2026 && creationTime.month == 7) {
        unlocked.add('loyalty_pioneer');
      }
    }

    // 6. Daily Login Streaks
    final maxStreak = prefs.getInt('max_streak') ?? prefs.getInt('streak') ?? 0;
    if (maxStreak >= 10 || prefs.getBool('loyaltyAchievement_0') == true) {
      unlocked.add('loyaltyAchievement_0');
    }
    if (maxStreak >= 50 || prefs.getBool('loyaltyAchievement_1') == true) {
      unlocked.add('loyaltyAchievement_1');
    }
    if (maxStreak >= 250 || prefs.getBool('loyaltyAchievement_2') == true) {
      unlocked.add('loyaltyAchievement_2');
    }

    // 7. Step Streaks
    final milestones = [5, 10, 25, 50, 100, 365];
    for (final m in milestones) {
      if (prefs.getBool('steps_achievement_$m') == true) {
        unlocked.add('steps_achievement_$m');
      }
    }

    // 8. Checkpoints
    for (int i = 1; i <= 5; i++) {
      if (prefs.getBool('achievement_checkpoint_${i}_reached') == true) {
        unlocked.add('checkpoint_$i');
      }
    }

    // 9. Loop Routes
    final loopCount = prefs.getInt('completed_loop_routes_count') ?? 0;
    if (loopCount >= 1) unlocked.add('route_first_loop');
    if (loopCount >= 10) unlocked.add('route_10_loops');
    if (loopCount >= 50) unlocked.add('route_50_loops');

    // 10. Regions Visited
    final visitedKrajs = prefs.getStringList('visited_krajs') ?? [];
    if (visitedKrajs.length >= 3) unlocked.add('route_explore_kraj_3');
    if (visitedKrajs.length >= 7) unlocked.add('route_explore_kraj_7');
    if (visitedKrajs.length >= 14) unlocked.add('route_explore_kraj_14');

    // 11. Ads Watched
    final totalAds = prefs.getInt('total_rewarded_ads_count') ?? 0;
    if (totalAds >= 1) unlocked.add('shop_ad_first');
    if (totalAds >= 50) unlocked.add('shop_ad_50');
    if (prefs.getBool('shop_ad_3_days_unlocked') == true) unlocked.add('shop_ad_3_days');

    // 12. Limetky Earned
    final limetky = prefs.getInt('limetkyBalance') ?? 0;
    if (limetky >= 10 || prefs.getBool('shop_limetky_10_unlocked') == true) {
      if (prefs.getBool('shop_limetky_10_unlocked') != true) {
        await prefs.setBool('shop_limetky_10_unlocked', true);
      }
      unlocked.add('shop_limetky_10');
    }
    if (limetky >= 100 || prefs.getBool('shop_limetky_100_unlocked') == true) {
      if (prefs.getBool('shop_limetky_100_unlocked') != true) {
        await prefs.setBool('shop_limetky_100_unlocked', true);
      }
      unlocked.add('shop_limetky_100');
    }
    if (limetky >= 500 || prefs.getBool('shop_limetky_500_unlocked') == true) {
      if (prefs.getBool('shop_limetky_500_unlocked') != true) {
        await prefs.setBool('shop_limetky_500_unlocked', true);
      }
      unlocked.add('shop_limetky_500');
    }

    // 13. Companions Owned
    final unlockedCompanions = prefs.getStringList('unlocked_companions') ?? [];
    if (unlockedCompanions.isNotEmpty) unlocked.add('shop_companion_buy_1');
    if (unlockedCompanions.length >= 3) unlocked.add('shop_companion_buy_3');

    // 14. Voluntary Support / Premium
    if (everOwned) unlocked.add('ever_owned_premium');
    if (premForYear) unlocked.add('premium_for_year');

    // 15. Trivia Correct
    final correctAnswers = prefs.getInt('trivia_correct_answers_count') ?? 0;
    if (correctAnswers >= 1) unlocked.add('trivia_first_correct');
    if (correctAnswers >= 10) unlocked.add('trivia_10_correct');
    if (correctAnswers >= 50) unlocked.add('trivia_50_correct');
    if (prefs.getBool('trivia_perfect_route_unlocked') == true) unlocked.add('trivia_perfect_route');
    
    final triviaRoutes = prefs.getInt('completed_routes_with_trivia_count') ?? 0;
    if (triviaRoutes >= 10) unlocked.add('trivia_unlocked_10');

    // 16. Fair Play
    final cleanRoutes = prefs.getInt('clean_routes_completed_count') ?? 0;
    if (cleanRoutes >= 10) unlocked.add('anticheat_clean_10');
    if (cleanRoutes >= 50) unlocked.add('anticheat_clean_50');
    if (cleanRoutes >= 100) unlocked.add('anticheat_clean_100');

    // 17. Invited Friends
    if (friendsCount >= 1) unlocked.add('invited_friends_1');
    if (friendsCount >= 5) unlocked.add('invited_friends_5');
    if (friendsCount >= 10) unlocked.add('invited_friends_10');

    // Single Achievements / Story
    if (prefs.getBool('loyalty_early_bird_unlocked') == true) unlocked.add('loyalty_early_bird');
    if (prefs.getBool('loyalty_night_owl_unlocked') == true) unlocked.add('loyalty_night_owl');
    if (prefs.getBool('loyalty_new_year_unlocked') == true) unlocked.add('loyalty_new_year');
    if (prefs.getBool('loyalty_weekend_warrior_unlocked') == true) unlocked.add('loyalty_weekend_warrior');
    
    final atobCount = prefs.getInt('completed_atob_routes_count') ?? 0;
    if (atobCount >= 1) unlocked.add('route_first_atob');
    
    final maxAtoBDist = prefs.getDouble('max_single_atob_distance') ?? 0.0;
    if (maxAtoBDist >= 20.0) unlocked.add('route_atob_long');
    
    if (prefs.getBool('route_scan_qr_unlocked') == true) unlocked.add('route_scan_qr');
    if (prefs.getBool('route_share_code_unlocked') == true) unlocked.add('route_share_code');
    
    // Check misc premium first day (premium activated within 24h of registration)
    if (everOwned && creationTime != null) {
      final premiumStartTimeStr = prefs.getString('premium_start_time');
      if (premiumStartTimeStr != null) {
        try {
          final startTime = DateTime.parse(premiumStartTimeStr);
          if (startTime.difference(creationTime).inHours <= 24) {
            unlocked.add('misc_premium_first_day');
          }
        } catch (_) {}
      }
    }
    if (prefs.getBool('misc_premium_first_day_unlocked') == true) {
      unlocked.add('misc_premium_first_day');
    }
    
    // Check tutorial finished
    if (prefs.getBool('has_seen_tutorial') == true || prefs.getBool('misc_tutorial_finished_unlocked') == true) {
      unlocked.add('misc_tutorial_finished');
    }
    
    // Story Game Mode Achievements
    if (prefs.getBool('achievement_hero_lost_amulet') == true) unlocked.add('achievement_hero_lost_amulet');
    if (prefs.getBool('achievement_story_difficulty_easy') == true) unlocked.add('achievement_story_difficulty_easy');
    if (prefs.getBool('achievement_story_difficulty_medium') == true) unlocked.add('achievement_story_difficulty_medium');
    if (prefs.getBool('achievement_story_difficulty_hard') == true) unlocked.add('achievement_story_difficulty_hard');
    if (prefs.getBool('achievement_story_difficulty_hardcore') == true) unlocked.add('achievement_story_difficulty_hardcore');

    final ratio = unlocked.length / achievementIds.length;
    return {
      'unlocked': unlocked,
      'ratio': ratio,
      'count': unlocked.length,
    };
  }

  /// Synchronizes the user's achievements stats to Firestore if they are opted-in as a collector.
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

  /// Fetches achievement rarities using a 10-minute cache layer.
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
