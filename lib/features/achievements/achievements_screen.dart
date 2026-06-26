import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/location_service.dart';
import '../../services/achievement_service.dart';

class TierDefinition {
  final String id;
  final String name;
  final double goal;
  final String medalType;
  final String desc;

  const TierDefinition({
    required this.id,
    required this.name,
    required this.goal,
    required this.medalType,
    required this.desc,
  });
}

class ChainProgress {
  final String chainId;
  final String title;
  final String icon;
  final String description;
  final List<TierDefinition> tiers;
  final double currentValue;
  final String unit;

  ChainProgress({
    required this.chainId,
    required this.title,
    required this.icon,
    required this.description,
    required this.tiers,
    required this.currentValue,
    required this.unit,
  });

  int get highestUnlockedIndex {
    int idx = -1;
    for (int i = 0; i < tiers.length; i++) {
      if (currentValue >= tiers[i].goal) {
        idx = i;
      }
    }
    return idx;
  }

  bool get isAnyUnlocked => highestUnlockedIndex >= 0;

  TierDefinition get displayTier {
    if (!isAnyUnlocked) {
      return tiers.first;
    }
    return tiers[highestUnlockedIndex];
  }

  TierDefinition? get nextTier {
    final idx = highestUnlockedIndex;
    if (idx + 1 < tiers.length) {
      return tiers[idx + 1];
    }
    return null;
  }

  double get progressPercentage {
    final next = nextTier;
    if (next == null) return 1.0;
    return (currentValue / next.goal).clamp(0.0, 1.0);
  }
}

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  // Stats
  double _totalDistance = 0.0;
  double _totalDistanceCycling = 0.0;
  double _maxSingleBike = 0.0;
  double _maxClimb = 0.0;
  int _daysSinceRegistration = 0;
  int _maxStreak = 0;
  int _stepsStreak = 0;
  int _loopCount = 0;
  int _visitedKrajsCount = 0;
  int _totalAds = 0;
  int _limetky = 0;
  int _unlockedCompanionsCount = 0;
  bool _isPremium = false;
  String _premiumTier = '';
  int _correctAnswers = 0;
  int _cleanRoutes = 0;
  int _invitedFriendsCount = 0;

  final Map<String, bool> _checkpointAchievements = {};
  final Map<String, bool> _unlockedSingleMap = {};
  Map<String, double> _rarities = {};

  // Confetti controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Distances
    final totalDistance = DistanceManager().totalDistance;
    final totalDistanceCycling = DistanceManager().totalDistanceCycling;

    // Friends
    int friendsCount = prefs.getInt('invited_friends_count') ?? 0;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('friends')
            .where('status', isEqualTo: 'friends')
            .get();
        friendsCount = snap.docs.length;
        await prefs.setInt('invited_friends_count', friendsCount);
      } catch (_) {}
    }

    // Premium
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

    // Registration duration
    int days = 0;
    bool isPioneer = false;
    if (currentUser?.metadata.creationTime != null) {
      days = DateTime.now().difference(currentUser!.metadata.creationTime!).inDays;
      final creation = currentUser.metadata.creationTime!;
      if (creation.year == 2026 && creation.month == 7) {
        isPioneer = true;
      }
    }

    // Checkpoints
    for (int i = 1; i <= 5; i++) {
      _checkpointAchievements['checkpoint_$i'] = prefs.getBool('achievement_checkpoint_${i}_reached') ?? false;
    }

    setState(() {
      _totalDistance = totalDistance;
      _totalDistanceCycling = totalDistanceCycling;
      _maxSingleBike = prefs.getDouble('max_single_bike_distance') ?? 0.0;
      _maxClimb = prefs.getDouble('max_single_bike_climb') ?? 0.0;
      _daysSinceRegistration = days;
      _maxStreak = prefs.getInt('max_streak') ?? prefs.getInt('streak') ?? 0;
      _stepsStreak = prefs.getInt('steps_streak') ?? 0;
      _loopCount = prefs.getInt('completed_loop_routes_count') ?? 0;
      _visitedKrajsCount = (prefs.getStringList('visited_krajs') ?? []).length;
      _totalAds = prefs.getInt('total_rewarded_ads_count') ?? 0;
      _limetky = prefs.getInt('limetkyBalance') ?? 0;
      _unlockedCompanionsCount = (prefs.getStringList('unlocked_companions') ?? []).length;
      _isPremium = isPrem;
      _premiumTier = prefs.getString('premiumTier') ?? '';
      _correctAnswers = prefs.getInt('trivia_correct_answers_count') ?? 0;
      _cleanRoutes = prefs.getInt('clean_routes_completed_count') ?? 0;
      _invitedFriendsCount = friendsCount;

      // Singles
      _unlockedSingleMap['loyalty_pioneer'] = isPioneer;
      _unlockedSingleMap['loyalty_early_bird'] = prefs.getBool('loyalty_early_bird_unlocked') == true;
      _unlockedSingleMap['loyalty_night_owl'] = prefs.getBool('loyalty_night_owl_unlocked') == true;
      _unlockedSingleMap['loyalty_new_year'] = prefs.getBool('loyalty_new_year_unlocked') == true;
      _unlockedSingleMap['loyalty_weekend_warrior'] = prefs.getBool('loyalty_weekend_warrior_unlocked') == true;
      
      _unlockedSingleMap['route_first_atob'] = (prefs.getInt('completed_atob_routes_count') ?? 0) >= 1;
      _unlockedSingleMap['route_atob_long'] = (prefs.getDouble('max_single_atob_distance') ?? 0.0) >= 20.0;
      _unlockedSingleMap['route_scan_qr'] = prefs.getBool('route_scan_qr_unlocked') == true;
      _unlockedSingleMap['route_share_code'] = prefs.getBool('route_share_code_unlocked') == true;
      
      _unlockedSingleMap['shop_ad_3_days'] = prefs.getBool('shop_ad_3_days_unlocked') == true;
      
      _unlockedSingleMap['trivia_perfect_route'] = prefs.getBool('trivia_perfect_route_unlocked') == true;
      _unlockedSingleMap['trivia_unlocked_10'] = (prefs.getInt('completed_routes_with_trivia_count') ?? 0) >= 10;
      
      _unlockedSingleMap['misc_premium_first_day'] = prefs.getBool('misc_premium_first_day_unlocked') == true ||
          (everOwned && days <= 1);
      _unlockedSingleMap['misc_tutorial_finished'] = prefs.getBool('has_seen_tutorial') == true ||
          prefs.getBool('misc_tutorial_finished_unlocked') == true;
          
      _unlockedSingleMap['achievement_hero_lost_amulet'] = prefs.getBool('achievement_hero_lost_amulet') == true;
      _unlockedSingleMap['achievement_story_difficulty_easy'] = prefs.getBool('achievement_story_difficulty_easy') == true;
      _unlockedSingleMap['achievement_story_difficulty_medium'] = prefs.getBool('achievement_story_difficulty_medium') == true;
      _unlockedSingleMap['achievement_story_difficulty_hard'] = prefs.getBool('achievement_story_difficulty_hard') == true;
      _unlockedSingleMap['achievement_story_difficulty_hardcore'] = prefs.getBool('achievement_story_difficulty_hardcore') == true;
    });

    try {
      final rarities = await AchievementService.getCachedAchievementRarities();
      if (mounted) {
        setState(() {
          _rarities = rarities;
        });
      }
      await AchievementService.syncUserAchievements();
    } catch (_) {}
  }

  double _checkpointCount() {
    int count = 0;
    _checkpointAchievements.forEach((k, v) {
      if (v == true) count++;
    });
    return count.toDouble();
  }

  double _supportLevelValue() {
    if (_unlockedSingleMap['premium_for_year'] == true || _premiumTier == '500') return 2.0;
    if (_isPremium) return 1.0;
    return 0.0;
  }

  List<ChainProgress> _getChains() {
    return [
      ChainProgress(
        chainId: 'chain_walk_distance',
        title: 'Chodecká vytrvalost',
        icon: '🚶',
        description: 'Celková nachozená vzdálenost v aplikaci.',
        currentValue: _totalDistance,
        unit: 'km',
        tiers: const [
          TierDefinition(id: 'dist_1km', name: 'První kilometr', goal: 1.0, medalType: 'bronze', desc: 'Ujdi 1 km a odemkni první odznak'),
          TierDefinition(id: 'dist_10km', name: 'Deset kilometrů', goal: 10.0, medalType: 'silver', desc: 'Ujdi 10 km a získej další odznak'),
          TierDefinition(id: 'dist_100km', name: 'Sto kilometrů', goal: 100.0, medalType: 'gold', desc: 'Ujdi 100 km a slav svůj pokrok'),
          TierDefinition(id: 'dist_1000km', name: 'Tisíc kilometrů', goal: 1000.0, medalType: 'platinum', desc: 'Ujdi 1 000 km a dostaň speciální medaili'),
          TierDefinition(id: 'dist_10000km', name: 'Deset tisíc km', goal: 10000.0, medalType: 'emerald', desc: 'Ujdi 10 000 km a získej mistrovský odznak'),
          TierDefinition(id: 'dist_40000km', name: 'Cesta kolem světa', goal: 40000.0, medalType: 'cosmic', desc: 'Ujdi 40 000 km a dohledej slávu'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_bike_distance',
        title: 'Cyklo maratónec',
        icon: '🚴',
        description: 'Celková vzdálenost ujetá na kole.',
        currentValue: _totalDistanceCycling,
        unit: 'km',
        tiers: const [
          TierDefinition(id: 'bike_10km', name: 'První šlápnutí', goal: 10.0, medalType: 'bronze', desc: 'Ujeď celkově 10 km na kole'),
          TierDefinition(id: 'bike_50km', name: 'Nedělní vyjížďka', goal: 50.0, medalType: 'bronze', desc: 'Ujeď celkově 50 km na kole'),
          TierDefinition(id: 'bike_200km', name: 'Horský jezdec', goal: 200.0, medalType: 'silver', desc: 'Ujeď celkově 200 km na kole'),
          TierDefinition(id: 'bike_1000km', name: 'Silniční maratónec', goal: 1000.0, medalType: 'gold', desc: 'Ujeď celkově 1 000 km na kole'),
          TierDefinition(id: 'bike_5000km', name: 'Zeměpisný cyklista', goal: 5000.0, medalType: 'emerald', desc: 'Ujeď celkově 5 000 km na kole'),
          TierDefinition(id: 'bike_15000km', name: 'Tour de ČR', goal: 15000.0, medalType: 'cosmic', desc: 'Ujeď celkově 15 000 km na kole'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_bike_single',
        title: 'Dálkový cyklista',
        icon: '⚡',
        description: 'Nejdelší ujetá cyklotrasa na jeden zátah.',
        currentValue: _maxSingleBike,
        unit: 'km',
        tiers: const [
          TierDefinition(id: 'bike_single_50km', name: 'Cyklo půlmaraton', goal: 50.0, medalType: 'silver', desc: 'Dokonči jedinou cyklotrasu delší než 50 km'),
          TierDefinition(id: 'bike_single_100km', name: 'Cyklo stovka', goal: 100.0, medalType: 'gold', desc: 'Dokonči jedinou cyklotrasu delší než 100 km'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_bike_climb',
        title: 'Vrchařský specialista',
        icon: '⛰️',
        description: 'Maximální nastoupané metry na jedné cyklotrase.',
        currentValue: _maxClimb,
        unit: 'm',
        tiers: const [
          TierDefinition(id: 'bike_climb_500m', name: 'Vrchařská prémie', goal: 500.0, medalType: 'silver', desc: 'Dokonči cyklotrasu s celkovým stoupáním přes 500 m'),
          TierDefinition(id: 'bike_climb_2000m', name: 'Král kopců', goal: 2000.0, medalType: 'gold', desc: 'Dokonči cyklotrasu s celkovým stoupáním přes 2 000 m'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_loyalty_time',
        title: 'Věrný společník',
        icon: '📅',
        description: 'Jak dlouho již používáš naši aplikaci.',
        currentValue: _daysSinceRegistration.toDouble(),
        unit: 'dní',
        tiers: const [
          TierDefinition(id: 'loyalty_half_year', name: 'Půl roku v pohybu', goal: 180.0, medalType: 'gold', desc: 'Buď aktivním uživatelem po dobu 6 měsíců'),
          TierDefinition(id: 'loyalty_anniversary', name: 'Roční jubileum', goal: 365.0, medalType: 'emerald', desc: 'Oslav 1 rok aktivního používání aplikace'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_streaks',
        title: 'Denní poutník',
        icon: '🔥',
        description: 'Maximální nepřerušená denní série přihlášení.',
        currentValue: _maxStreak.toDouble(),
        unit: 'dní',
        tiers: const [
          TierDefinition(id: 'loyaltyAchievement_0', name: '10 dnů v řadě', goal: 10.0, medalType: 'bronze', desc: 'Udržuj sérii 10 dnů aktivní chůze'),
          TierDefinition(id: 'loyaltyAchievement_1', name: '50 dnů v řadě', goal: 50.0, medalType: 'silver', desc: 'Udržuj sérii 50 dnů aktivní chůze'),
          TierDefinition(id: 'loyaltyAchievement_2', name: '250 dnů v řadě', goal: 250.0, medalType: 'gold', desc: 'Udržuj sérii 250 dnů aktivní chůze'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_steps',
        title: 'Svědomitý plnič',
        icon: '🎯',
        description: 'Série splnění denního krokového cíle.',
        currentValue: _stepsStreak.toDouble(),
        unit: 'dní',
        tiers: const [
          TierDefinition(id: 'steps_achievement_5', name: 'Svědomitý I', goal: 5.0, medalType: 'bronze', desc: 'Denní krokový cíl splněn 5 dní po sobě'),
          TierDefinition(id: 'steps_achievement_10', name: 'Svědomitý II', goal: 10.0, medalType: 'silver', desc: 'Denní krokový cíl splněn 10 dní po sobě'),
          TierDefinition(id: 'steps_achievement_25', name: 'Svědomitý III', goal: 25.0, medalType: 'gold', desc: 'Denní krokový cíl splněn 25 dní po sobě'),
          TierDefinition(id: 'steps_achievement_50', name: 'Svědomitý IV', goal: 50.0, medalType: 'platinum', desc: 'Denní krokový cíl splněn 50 dní po sobě'),
          TierDefinition(id: 'steps_achievement_100', name: 'Svědomitý V', goal: 100.0, medalType: 'emerald', desc: 'Denní krokový cíl splněn 100 dní po sobě'),
          TierDefinition(id: 'steps_achievement_365', name: 'Legenda chůze', goal: 365.0, medalType: 'cosmic', desc: 'Denní krokový cíl splněn 365 dní po sobě'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_checkpoints',
        title: 'Průzkumník mapy',
        icon: '📍',
        description: 'Počet objevených a dosažených checkpointů na mapě.',
        currentValue: _checkpointCount(),
        unit: 'bodů',
        tiers: const [
          TierDefinition(id: 'checkpoint_1', name: 'První checkpoint', goal: 1.0, medalType: 'bronze', desc: 'Najdi a dosáhni severovýchodní checkpoint'),
          TierDefinition(id: 'checkpoint_2', name: 'Druhý checkpoint', goal: 2.0, medalType: 'silver', desc: 'Najdi a dosáhni jižovýchodní checkpoint'),
          TierDefinition(id: 'checkpoint_3', name: 'Třetí checkpoint', goal: 3.0, medalType: 'gold', desc: 'Najdi a dosáhni jihozápadní checkpoint'),
          TierDefinition(id: 'checkpoint_4', name: 'Čtvrtý checkpoint', goal: 4.0, medalType: 'platinum', desc: 'Najdi a dosáhni severozápadní checkpoint'),
          TierDefinition(id: 'checkpoint_5', name: 'Pátý checkpoint', goal: 5.0, medalType: 'emerald', desc: 'Najdi a dosáhni východní checkpoint'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_route_loops',
        title: 'Mistr okruhů',
        icon: '🔁',
        description: 'Počet dokončených vygenerovaných okružních tras.',
        currentValue: _loopCount.toDouble(),
        unit: 'okruhů',
        tiers: const [
          TierDefinition(id: 'route_first_loop', name: 'Kruh se uzavřel', goal: 1.0, medalType: 'bronze', desc: 'Dokonči svou první vygenerovanou okružní trasu'),
          TierDefinition(id: 'route_10_loops', name: 'Zpátky na startu', goal: 10.0, medalType: 'silver', desc: 'Dokonči celkem 10 vygenerovaných okružních tras'),
          TierDefinition(id: 'route_50_loops', name: 'Mistr okruhů', goal: 50.0, medalType: 'gold', desc: 'Dokonči celkem 50 vygenerovaných okružních tras'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_regions',
        title: 'Krajský turista',
        icon: '🗺️',
        description: 'Počet navštívených a prošlých krajů ČR.',
        currentValue: _visitedKrajsCount.toDouble(),
        unit: 'krajů',
        tiers: const [
          TierDefinition(id: 'route_explore_kraj_3', name: 'Krajský turista', goal: 3.0, medalType: 'silver', desc: 'Dokonči trasy ve 3 různých krajích ČR'),
          TierDefinition(id: 'route_explore_kraj_7', name: 'Napříč republikou', goal: 7.0, medalType: 'gold', desc: 'Dokonči trasy v 7 různých krajích ČR'),
          TierDefinition(id: 'route_explore_kraj_14', name: 'Český patriot 🇨🇿', goal: 14.0, medalType: 'cosmic', desc: 'Dokonči trasy ve všech 14 krajích České republiky'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_ads',
        title: 'Podporovatel reklamou',
        icon: '📺',
        description: 'Celkový počet zhlédnutých reklam v limetkovém měšci.',
        currentValue: _totalAds.toDouble(),
        unit: 'reklam',
        tiers: const [
          TierDefinition(id: 'shop_ad_first', name: 'Podpora zdarma', goal: 1.0, medalType: 'bronze', desc: 'Podpoř vývoj zhlédnutím první reklamy v limetkovém měšci'),
          TierDefinition(id: 'shop_ad_50', name: 'Filantrop', goal: 50.0, medalType: 'silver', desc: 'Podpoř projekt zhlédnutím 50 reklam za odměnu'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_limetky',
        title: 'Limetkový magnát',
        icon: '🍋',
        description: 'Nejvyšší dosažené množství nasbíraných Limetek.',
        currentValue: _limetky.toDouble(),
        unit: 'Limetek',
        tiers: const [
          TierDefinition(id: 'shop_limetky_10', name: 'Drobné do kapsy', goal: 10.0, medalType: 'bronze', desc: 'Nasbírej celkově 10 Limetek'),
          TierDefinition(id: 'shop_limetky_100', name: 'Limetkový boháč', goal: 100.0, medalType: 'silver', desc: 'Nasbírej celkově 100 Limetek'),
          TierDefinition(id: 'shop_limetky_500', name: 'Limetkový magnát', goal: 500.0, medalType: 'gold', desc: 'Nasbírej celkově 500 Limetek'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_companions',
        title: 'Sběratel společníků',
        icon: '🐾',
        description: 'Počet zakoupených společníků v obchodě.',
        currentValue: _unlockedCompanionsCount.toDouble(),
        unit: 'společníků',
        tiers: const [
          TierDefinition(id: 'shop_companion_buy_1', name: 'Zvířecí doprovod', goal: 1.0, medalType: 'silver', desc: 'Kup si svého prvního společníka (pet) v obchodě'),
          TierDefinition(id: 'shop_companion_buy_3', name: 'Limetková zoo', goal: 3.0, medalType: 'gold', desc: 'Kup si alespoň 3 různé společníky do doprovodu'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_support',
        title: 'Mecenáš projektu',
        icon: '💖',
        description: 'Úroveň tvé dobrovolné finanční podpory.',
        currentValue: _supportLevelValue(),
        unit: 'úroveň',
        tiers: const [
          TierDefinition(id: 'ever_owned_premium', name: 'Věrný sponzor', goal: 1.0, medalType: 'platinum', desc: 'Podpoř vývoj projektu dobrovolným členstvím (Premium)'),
          TierDefinition(id: 'premium_for_year', name: 'Patron na věky', goal: 2.0, medalType: 'cosmic', desc: 'Podporuj projekt dobrovolným členstvím po dobu jednoho roku'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_trivia',
        title: 'Chodící encyklopedie',
        icon: '🧠',
        description: 'Počet správně zodpovězených kvízových otázek.',
        currentValue: _correctAnswers.toDouble(),
        unit: 'otázek',
        tiers: const [
          TierDefinition(id: 'trivia_first_correct', name: 'Chytrá hlava', goal: 1.0, medalType: 'bronze', desc: 'Odpověz správně na svou první kvízovou otázku na trase'),
          TierDefinition(id: 'trivia_10_correct', name: 'Znalec okolí', goal: 10.0, medalType: 'silver', desc: 'Odpověz správně na 10 kvízových otázek'),
          TierDefinition(id: 'trivia_50_correct', name: 'Chodící encyklopedie', goal: 50.0, medalType: 'gold', desc: 'Odpověz správně na 50 kvízových otázek'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_anticheat',
        title: 'Fair Play šampión',
        icon: '🛡️',
        description: 'Počet dokončených tras bez detekce podvodné rychlosti.',
        currentValue: _cleanRoutes.toDouble(),
        unit: 'tras',
        tiers: const [
          TierDefinition(id: 'anticheat_clean_10', name: 'Poctivý sportovec', goal: 10.0, medalType: 'silver', desc: 'Dokonči 10 tras bez jediné detekce podvádění (rychlá jízda)'),
          TierDefinition(id: 'anticheat_clean_50', name: 'Čestný šampión', goal: 50.0, medalType: 'gold', desc: 'Dokonči 50 tras bez jediné detekce rychlého pohybu autem/MHD'),
          TierDefinition(id: 'anticheat_clean_100', name: 'Fair Play legenda', goal: 100.0, medalType: 'cosmic', desc: 'Dokonči 100 tras bez varování a s ověřeným pohybem'),
        ],
      ),
      ChainProgress(
        chainId: 'chain_friends',
        title: 'Nová krev',
        icon: '👥',
        description: 'Počet připojených přátel v aplikaci.',
        currentValue: _invitedFriendsCount.toDouble(),
        unit: 'přátel',
        tiers: const [
          TierDefinition(id: 'invited_friends_1', name: 'Nová krev I', goal: 1.0, medalType: 'bronze', desc: 'Měj alespoň 1 spojeného přítele v aplikaci'),
          TierDefinition(id: 'invited_friends_5', name: 'Nová krev II', goal: 5.0, medalType: 'silver', desc: 'Měj alespoň 5 spojených přátel v aplikaci'),
          TierDefinition(id: 'invited_friends_10', name: 'Nová krev III', goal: 10.0, medalType: 'gold', desc: 'Měj alespoň 10 spojených přátel v aplikaci'),
        ],
      ),
    ];
  }

  void _triggerConfetti() {
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final chains = _getChains();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Síň slávy',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          backgroundColor: const Color(0xFF263238),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFBFFF00)),
              onPressed: _triggerConfetti,
              tooltip: 'Oslavit ohňostrojem',
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFFBFFF00),
            unselectedLabelColor: Colors.white70,
            indicatorColor: Color(0xFFBFFF00),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'Aktivita'),
              Tab(text: 'Vytrvalost'),
              Tab(text: 'Průzkum'),
              Tab(text: 'Obchod'),
              Tab(text: 'Sociální'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                // 1. Aktivita Tab
                _buildChainsTab(chains.where((c) => [
                  'chain_walk_distance',
                  'chain_bike_distance',
                  'chain_bike_single',
                  'chain_bike_climb'
                ].contains(c.chainId)).toList(), []),

                // 2. Vytrvalost Tab
                _buildChainsTab(chains.where((c) => [
                  'chain_streaks',
                  'chain_steps'
                ].contains(c.chainId)).toList(), [
                  _createSingleItem('loyalty_pioneer', 'Od začátku 💖', 'Používej aplikaci od prvního měsíce jejího spuštění', 'cosmic'),
                  _createSingleItem('loyalty_early_bird', 'Ranní ptáče 🌅', 'Dokonči trasu zahájenou před 6:00 ráno', 'bronze'),
                  _createSingleItem('loyalty_night_owl', 'Noční jezdec 🌃', 'Dokonči trasu po 22:00 večer', 'bronze'),
                  _createSingleItem('loyalty_new_year', 'Jak na Nový rok... 🎆', 'Dokonči trasu 1. ledna a vykroč správným směrem', 'silver'),
                  _createSingleItem('loyalty_weekend_warrior', 'Víkendový bojovník ⚔️', 'Dokonči alespoň jednu trasu v sobotu i v neděli v rámci jednoho víkendu', 'silver'),
                  _createSingleItem('misc_tutorial_finished', 'Všechno je mi jasné! 🎓', 'Dokonči celého interaktivního průvodce aplikací při prvním zapnutí', 'bronze'),
                ]),

                // 3. Průzkum Tab
                _buildChainsTab(chains.where((c) => [
                  'chain_route_loops',
                  'chain_regions',
                  'chain_checkpoints'
                ].contains(c.chainId)).toList(), [
                  _createSingleItem('route_first_atob', 'Z bodu A do bodu B 🗺️', 'Dokonči svou první trasu s vlastním cílem', 'bronze'),
                  _createSingleItem('route_atob_long', 'Dálková pouť 🥾', 'Dokonči trasu typu A-to-B delší než 20 km', 'silver'),
                  _createSingleItem('route_scan_qr', 'Společná cesta 🤝', 'Načti a dokonči sdílenou trasu od kamaráda přes QR kód', 'silver'),
                  _createSingleItem('route_share_code', 'Průvodce krajem 📢', 'Nasdílej svou trasu kamarádovi, který ji dokončí', 'silver'),
                ]),

                // 4. Obchod Tab
                _buildChainsTab(chains.where((c) => [
                  'chain_ads',
                  'chain_limetky',
                  'chain_companions',
                  'chain_support'
                ].contains(c.chainId)).toList(), [
                  _createSingleItem('shop_ad_3_days', 'Maximální podpora 💎', 'Zhlédni maximální počet 3 reklam za jeden den', 'bronze'),
                ]),

                // 5. Sociální Tab
                _buildChainsTab(chains.where((c) => [
                  'chain_friends',
                  'chain_trivia',
                  'chain_anticheat'
                ].contains(c.chainId)).toList(), [
                  _createSingleItem('misc_premium_first_day', 'Rychlá víra ⚡', 'Aktivuj si předplatné do 24 hodin od registrace', 'silver'),
                  _createSingleItem('trivia_perfect_route', 'Bez ztráty květinky 🌸', 'Odpověz správně na všechny 3 otázky během jedné trasy', 'silver'),
                  _createSingleItem('trivia_unlocked_10', 'Sběratel vědomostí 📚', 'Vygeneruj a projdi 10 tras s aktivním AI kvízem', 'silver'),
                  _createSingleItem('achievement_hero_lost_amulet', 'Cesta živlů 🔮', 'Dokonči celou příběhovou linku Cesta živlů a získej legendární odznak', 'cosmic'),
                  _createSingleItem('achievement_story_difficulty_easy', 'Pohodový poutník 🟢', 'Dokonči příběh na lehkou obtížnost (6 km)', 'bronze'),
                  _createSingleItem('achievement_story_difficulty_medium', 'Zkušený dobrodruh 🔵', 'Dokonči příběh na střední obtížnost (10 km)', 'silver'),
                  _createSingleItem('achievement_story_difficulty_hard', 'Vytrvalý hrdina 🟡', 'Dokonči příběh na těžkou obtížnost (15 km)', 'gold'),
                  _createSingleItem('achievement_story_difficulty_hardcore', 'Legenda z bažin 🔴', 'Dokonči příběh na hardcore obtížnost (20 km)', 'emerald'),
                ]),
              ],
            ),

            // Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Colors.lime],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _createSingleItem(String id, String title, String desc, String medalType) {
    return {
      'id': id,
      'title': title,
      'description': desc,
      'medalType': medalType,
    };
  }

  Widget _buildChainsTab(List<ChainProgress> tabChains, List<Map<String, dynamic>> tabSingles) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (tabChains.isNotEmpty) ...[
          _buildSectionHeader('📈 Postupové trofeje (Úrovně)'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220.0,
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              childAspectRatio: 0.82,
            ),
            itemCount: tabChains.length,
            itemBuilder: (context, index) {
              final chain = tabChains[index];
              return UpgradeableChainCard(
                chain: chain,
                rarity: _rarities[chain.displayTier.id],
                onShowRoadmap: () => _showRoadmapDialog(chain),
                onUnlockReveal: _triggerConfetti,
              );
            },
          ),
        ],
        if (tabSingles.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSectionHeader('🏆 Speciální výzvy'),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tabSingles.length,
            itemBuilder: (context, index) {
              final single = tabSingles[index];
              final id = single['id'] as String;
              final unlocked = _unlockedSingleMap[id] ?? false;
              final rarity = _rarities[id];
              return _buildStreakTile(
                single['title'] as String,
                single['description'] as String,
                unlocked,
                single['medalType'] as String,
                rarity: rarity,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF263238),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStreakTile(String title, String desc, bool unlocked, String medalType, {double? rarity}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(
            painter: MedalPainter(medalType: medalType, unlocked: unlocked),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: unlocked ? const Color(0xFF263238) : Colors.black45,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: unlocked ? Colors.black87 : Colors.black38,
              ),
            ),
            if (rarity != null) ...[
              const SizedBox(height: 3),
              Text(
                'Získalo: ${rarity.toStringAsFixed(1)}% sběračů',
                style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        trailing: Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: unlocked ? const Color(0xFF5C9E00) : Colors.grey.shade300,
          size: 26,
        ),
      ),
    );
  }

  void _showRoadmapDialog(ChainProgress chain) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF263238),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Text(
                chain.icon,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chain.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Aktuálně: ${chain.currentValue.toStringAsFixed(1)} ${chain.unit}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: chain.tiers.length,
              itemBuilder: (context, index) {
                final tier = chain.tiers[index];
                final isUnlocked = chain.currentValue >= tier.goal;
                final isCurrentTarget = !isUnlocked && (index == 0 || chain.currentValue >= chain.tiers[index - 1].goal);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      // Badge
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CustomPaint(
                          painter: MedalPainter(medalType: tier.medalType, unlocked: isUnlocked),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Title, Goal & Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tier.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isUnlocked
                                        ? Colors.white
                                        : isCurrentTarget
                                            ? const Color(0xFFBFFF00)
                                            : Colors.white38,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${tier.goal.toInt()} ${chain.unit}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isUnlocked
                                        ? const Color(0xFFBFFF00)
                                        : isCurrentTarget
                                            ? Colors.white60
                                            : Colors.white24,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tier.desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnlocked
                                    ? Colors.white70
                                    : isCurrentTarget
                                        ? Colors.white54
                                        : Colors.white24,
                              ),
                            ),
                            if (isCurrentTarget) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (chain.currentValue / tier.goal).clamp(0.0, 1.0),
                                  color: const Color(0xFFBFFF00),
                                  backgroundColor: Colors.white12,
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zavřít', style: TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class UpgradeableChainCard extends StatefulWidget {
  final ChainProgress chain;
  final double? rarity;
  final VoidCallback onShowRoadmap;
  final VoidCallback onUnlockReveal;

  const UpgradeableChainCard({
    super.key,
    required this.chain,
    this.rarity,
    required this.onShowRoadmap,
    required this.onUnlockReveal,
  });

  @override
  State<UpgradeableChainCard> createState() => _UpgradeableChainCardState();
}

class _UpgradeableChainCardState extends State<UpgradeableChainCard> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_flipController.isAnimating) return;
    if (widget.chain.isAnyUnlocked) {
      widget.onUnlockReveal();
    }
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _showBack = !_showBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, child) {
          final double angle = _flipController.value * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // Perspective depth
              ..rotateY(angle),
            child: angle >= math.pi / 2
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardBack(),
                  )
                : _buildCardFront(),
          );
        },
      ),
    );
  }

  Widget _buildCardFront() {
    final chain = widget.chain;
    final displayTier = chain.displayTier;
    final unlocked = chain.isAnyUnlocked;
    final next = chain.nextTier;
    
    String progressStr = '';
    if (next == null) {
      progressStr = 'MAX';
    } else {
      // Format to avoid decimals if they are integer values
      final double curr = chain.currentValue;
      final double goal = next.goal;
      progressStr = '${curr.toStringAsFixed(curr % 1 == 0 ? 0 : 1)} / ${goal.toInt()} ${chain.unit}';
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: unlocked 
              ? Border.all(color: const Color(0xFFBFFF00).withOpacity(0.8), width: 2.0)
              : Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  chain.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                if (unlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFFF00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayTier.medalType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF5C9E00),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 66,
                  height: 66,
                  child: CustomPaint(
                    painter: MedalPainter(
                      medalType: displayTier.medalType,
                      unlocked: unlocked,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              chain.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: chain.progressPercentage,
                color: unlocked ? const Color(0xFF5C9E00) : Colors.grey.shade400,
                backgroundColor: Colors.grey.shade200,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progressStr,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: unlocked ? const Color(0xFF5C9E00) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    final chain = widget.chain;
    final displayTier = chain.displayTier;
    final unlocked = chain.isAnyUnlocked;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF263238),
          border: Border.all(color: const Color(0xFFBFFF00), width: 1.5),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFBFFF00), size: 24),
            const SizedBox(height: 6),
            Text(
              chain.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  chain.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: widget.onShowRoadmap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFFF00),
                foregroundColor: Colors.black,
                elevation: 0,
                minimumSize: const Size(double.infinity, 28),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'ZOBRAZIT POSTUP',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: 0.3),
              ),
            ),
            const SizedBox(height: 4),
            if (widget.rarity != null)
              Text(
                'Úroveň získalo: ${widget.rarity!.toStringAsFixed(1)}% sběračů',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MedalPainter extends CustomPainter {
  final String medalType;
  final bool unlocked;

  MedalPainter({required this.medalType, required this.unlocked});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final center = Offset(radius, radius);
    final paint = Paint()..style = PaintingStyle.fill;

    // Define colors depending on type and lock state
    Color primaryColor = Colors.grey.shade400;
    Color secondaryColor = Colors.grey.shade600;
    Color glowColor = Colors.transparent;

    if (unlocked) {
      switch (medalType) {
        case 'bronze':
          primaryColor = const Color(0xFFCD7F32);
          secondaryColor = const Color(0xFF8B4513);
          glowColor = const Color(0xFFCD7F32).withOpacity(0.2);
          break;
        case 'silver':
          primaryColor = const Color(0xFFC0C0C0);
          secondaryColor = const Color(0xFF707070);
          glowColor = const Color(0xFFC0C0C0).withOpacity(0.2);
          break;
        case 'gold':
          primaryColor = const Color(0xFFFFD700);
          secondaryColor = const Color(0xFFD4AF37);
          glowColor = const Color(0xFFFFD700).withOpacity(0.35);
          break;
        case 'platinum':
          primaryColor = const Color(0xFFE5E4E2);
          secondaryColor = const Color(0xFFA0A0A0);
          glowColor = const Color(0xFFE5E4E2).withOpacity(0.3);
          break;
        case 'emerald':
          primaryColor = const Color(0xFF50C878);
          secondaryColor = const Color(0xFF0F52BA);
          glowColor = const Color(0xFF50C878).withOpacity(0.35);
          break;
        case 'cosmic':
          primaryColor = const Color(0xFF8A2BE2);
          secondaryColor = const Color(0xFF4B0082);
          glowColor = const Color(0xFF8A2BE2).withOpacity(0.4);
          break;
      }
    } else {
      primaryColor = Colors.grey.shade400;
      secondaryColor = Colors.grey.shade500;
    }

    // Outer glow
    if (unlocked && glowColor != Colors.transparent) {
      final glowPaint = Paint()
        ..color = glowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.35);
      canvas.drawCircle(center, radius * 0.9, glowPaint);
    }

    // Medal Body (Circle)
    final gradient = RadialGradient(
      colors: [primaryColor, secondaryColor],
    );
    paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius * 0.8));
    canvas.drawCircle(center, radius * 0.8, paint);
    paint.shader = null;

    // Outer Rim Border
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..color = unlocked ? const Color(0xFFBFFF00).withOpacity(0.8) : Colors.grey.shade300;
    canvas.drawCircle(center, radius * 0.75, rimPaint);

    // Inner details (Star / Trophy icon shape)
    canvas.save();
    canvas.translate(radius, radius);
    if (unlocked) {
      final iconPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      
      // Draw a star shape inside the medal
      final path = Path();
      const int points = 5;
      const double innerRadius = 8.0;
      const double outerRadius = 18.0;
      const double angleStep = math.pi / points;

      for (int i = 0; i < points * 2; i++) {
        final double r = i.isEven ? outerRadius : innerRadius;
        final double a = i * angleStep - math.pi / 2;
        final double x = r * math.cos(a);
        final double y = r * math.sin(a);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, iconPaint);
    } else {
      // Draw lock icon shape
      final lockPaint = Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromCenter(center: const Offset(0, 4), width: 16, height: 12), lockPaint);
      
      final shacklePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white54;
      canvas.drawArc(Rect.fromCenter(center: const Offset(0, -2), width: 10, height: 10), math.pi, math.pi, false, shacklePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MedalPainter oldDelegate) {
    return oldDelegate.medalType != medalType || oldDelegate.unlocked != unlocked;
  }
}