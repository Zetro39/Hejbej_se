import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/location_service.dart';

const List<Map<String, dynamic>> _achievementData = [
  {
    'id': 'dist_1km',
    'title': 'První kilometr',
    'description': 'Ujdi 1 km a odemkni první odznak',
    'goal': 1.0,
    'medalType': 'bronze',
  },
  {
    'id': 'dist_10km',
    'title': 'Deset kilometrů',
    'description': 'Ujdi 10 km a získej další odznak',
    'goal': 10.0,
    'medalType': 'silver',
  },
  {
    'id': 'dist_100km',
    'title': 'Sto kilometrů',
    'description': 'Ujdi 100 km a slav svůj pokrok',
    'goal': 100.0,
    'medalType': 'gold',
  },
  {
    'id': 'dist_1000km',
    'title': 'Tisíc kilometrů',
    'description': 'Ujdi 1 000 km a dostaň speciální medaili',
    'goal': 1000.0,
    'medalType': 'platinum',
  },
  {
    'id': 'dist_10000km',
    'title': 'Deset tisíc km',
    'description': 'Ujdi 10 000 km a získej mistrovský odznak',
    'goal': 10000.0,
    'medalType': 'emerald',
  },
  {
    'id': 'dist_40000km',
    'title': 'Cesta kolem světa',
    'description': 'Ujdi 40 000 km a dohledej slávu',
    'goal': 40000.0,
    'medalType': 'cosmic',
  },
  {
    'id': 'checkpoint_1',
    'title': 'První checkpoint',
    'description': 'Najdi a dosáhni severovýchodní checkpoint',
    'type': 'checkpoint',
    'medalType': 'bronze',
  },
  {
    'id': 'checkpoint_2',
    'title': 'Druhý checkpoint',
    'description': 'Najdi a dosáhni jižovýchodní checkpoint',
    'type': 'checkpoint',
    'medalType': 'silver',
  },
  {
    'id': 'checkpoint_3',
    'title': 'Třetí checkpoint',
    'description': 'Najdi a dosáhni jihozápadní checkpoint',
    'type': 'checkpoint',
    'medalType': 'gold',
  },
  {
    'id': 'checkpoint_4',
    'title': 'Čtvrtý checkpoint',
    'description': 'Najdi a dosáhni severozápadní checkpoint',
    'type': 'checkpoint',
    'medalType': 'platinum',
  },
  {
    'id': 'checkpoint_5',
    'title': 'Pátý checkpoint',
    'description': 'Najdi a dosáhni východní checkpoint',
    'type': 'checkpoint',
    'medalType': 'emerald',
  },
];

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final DistanceManager _distanceManager;
  final List<bool> _loyaltyAchievements = [false, false, false];
  final List<bool> _stepsAchievements = List.filled(6, false);
  bool _storyAmuletCompleted = false;
  bool _storyDifficultyEasy = false;
  bool _storyDifficultyMedium = false;
  bool _storyDifficultyHard = false;
  bool _storyDifficultyHardcore = false;
  final Map<String, bool> _checkpointAchievements = {};
  int _invitedFriendsCount = 0;
  bool _hasOwnedPremium = false;
  bool _premiumForYear = false;
  
  // Confetti controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _distanceManager = DistanceManager();
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

    setState(() {
      _invitedFriendsCount = friendsCount;
      _hasOwnedPremium = everOwned;
      _premiumForYear = premForYear;

      _loyaltyAchievements[0] = prefs.getBool('loyaltyAchievement_0') ?? false;
      _loyaltyAchievements[1] = prefs.getBool('loyaltyAchievement_1') ?? false;
      _loyaltyAchievements[2] = prefs.getBool('loyaltyAchievement_2') ?? false;

      final milestones = [5, 10, 25, 50, 100, 365];
      for (int i = 0; i < milestones.length; i++) {
        _stepsAchievements[i] = prefs.getBool('steps_achievement_${milestones[i]}') ?? false;
      }

      _storyAmuletCompleted = prefs.getBool('achievement_hero_lost_amulet') ?? false;
      _storyDifficultyEasy = prefs.getBool('achievement_story_difficulty_easy') ?? false;
      _storyDifficultyMedium = prefs.getBool('achievement_story_difficulty_medium') ?? false;
      _storyDifficultyHard = prefs.getBool('achievement_story_difficulty_hard') ?? false;
      _storyDifficultyHardcore = prefs.getBool('achievement_story_difficulty_hardcore') ?? false;

      for (int i = 1; i <= 5; i++) {
        _checkpointAchievements['checkpoint_$i'] = prefs.getBool('achievement_checkpoint_${i}_reached') ?? false;
      }
    });
  }

  void _triggerConfetti() {
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = _distanceManager.totalDistance;

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
              Tab(text: 'Chůze'),
              Tab(text: 'Série'),
              Tab(text: 'Checky'),
              Tab(text: 'Výpravy'),
              Tab(text: 'Sociální'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [
                // 1. Chůze Tab
                _buildDistanceGrid(totalDistance),

                // 2. Série Tab
                _buildStreaksTab(),

                // 3. Checkpointy Tab
                _buildCheckpointsGrid(),

                // 4. Výpravy Tab
                _buildQuestsTab(),

                // 5. Sociální Tab
                _buildSocialTab(),
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

  Widget _buildDistanceGrid(double totalDistance) {
    final list = _achievementData.where((item) => item.containsKey('goal')).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200.0,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final goal = item['goal'] as double;
        final reached = totalDistance >= goal;
        final progress = math.min(totalDistance / goal, 1.0);

        return AchievementCard(
          title: item['title'] as String,
          description: item['description'] as String,
          unlocked: reached,
          progress: progress,
          medalType: item['medalType'] as String,
          subLabel: reached ? 'Splněno!' : '${totalDistance.toStringAsFixed(1)} / ${goal.toInt()} km',
          onFlip: _triggerConfetti,
        );
      },
    );
  }

  Widget _buildStreaksTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader('🔥 Každodenní série přihlášení'),
        const SizedBox(height: 12),
        _buildStreakTile('10 dnů v řadě', 'Udržuj sérii 10 dnů aktivní chůze', _loyaltyAchievements[0], 'bronze'),
        _buildStreakTile('50 dnů v řadě', 'Udržuj sérii 50 dnů aktivní chůze', _loyaltyAchievements[1], 'silver'),
        _buildStreakTile('250 dnů v řadě', 'Udržuj sérii 250 dnů aktivní chůze', _loyaltyAchievements[2], 'gold'),
        
        const SizedBox(height: 24),
        _buildSectionHeader('🎯 Plnění denního krokového cíle'),
        const SizedBox(height: 12),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
          children: [
            _buildGridStreakTile('Svědomitý I', '5 dní splněno', _stepsAchievements[0], 'bronze'),
            _buildGridStreakTile('Svědomitý II', '10 dní splněno', _stepsAchievements[1], 'silver'),
            _buildGridStreakTile('Svědomitý III', '25 dní splněno', _stepsAchievements[2], 'gold'),
            _buildGridStreakTile('Svědomitý IV', '50 dní splněno', _stepsAchievements[3], 'platinum'),
            _buildGridStreakTile('Svědomitý V', '100 dní splněno', _stepsAchievements[4], 'emerald'),
            _buildGridStreakTile('Legenda', '365 dní splněno', _stepsAchievements[5], 'cosmic'),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckpointsGrid() {
    final list = _achievementData.where((item) => item['type'] == 'checkpoint').toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200.0,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.85,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final id = item['id'] as String;
        final reached = _checkpointAchievements[id] ?? false;

        return AchievementCard(
          title: item['title'] as String,
          description: item['description'] as String,
          unlocked: reached,
          progress: reached ? 1.0 : 0.0,
          medalType: item['medalType'] as String,
          subLabel: reached ? 'Checkpoint nalezen!' : 'Hledej body na mapě',
          onFlip: _triggerConfetti,
        );
      },
    );
  }

  Widget _buildQuestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader('📖 Hlavní příběhová dobrodružství'),
        const SizedBox(height: 12),
        
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: _storyAmuletCompleted 
                    ? [Colors.deepPurple.shade900, Colors.black87] 
                    : [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _storyAmuletCompleted ? const Color(0xFFBFFF00) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _storyAmuletCompleted ? Icons.auto_stories : Icons.lock_outline,
                  color: _storyAmuletCompleted ? Colors.black : Colors.grey.shade600,
                  size: 28,
                ),
              ),
              title: Text(
                'Cesta živlů',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _storyAmuletCompleted ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Dokonči celou příběhovou linku Cesta živlů a získej legendární odznak.',
                style: TextStyle(
                  color: _storyAmuletCompleted ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              trailing: Text(
                _storyAmuletCompleted ? '100%' : '0%',
                style: TextStyle(
                  color: _storyAmuletCompleted ? const Color(0xFFBFFF00) : Colors.black45,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        _buildSectionHeader('⚙️ Obtížnosti příběhu'),
        const SizedBox(height: 12),
        
        _buildStoryDifficultyRow('Lehká (6 km)', _storyDifficultyEasy, Colors.green, 'Pohodový poutník'),
        _buildStoryDifficultyRow('Střední (10 km)', _storyDifficultyMedium, Colors.cyan, 'Zkušený dobrodruh'),
        _buildStoryDifficultyRow('Těžká (15 km)', _storyDifficultyHard, Colors.orange, 'Vytrvalý hrdina'),
        _buildStoryDifficultyRow('Hardcore (20 km)', _storyDifficultyHardcore, Colors.redAccent, 'Legenda z bažin'),
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

  Widget _buildStreakTile(String title, String desc, bool unlocked, String medalType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: SizedBox(
          width: 50,
          height: 50,
          child: CustomPaint(
            painter: MedalPainter(medalType: medalType, unlocked: unlocked),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
        trailing: Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: unlocked ? const Color(0xFFBFFF00) : Colors.grey.shade400,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildGridStreakTile(String title, String desc, bool unlocked, String medalType) {
    return AchievementCard(
      title: title,
      description: desc,
      unlocked: unlocked,
      progress: unlocked ? 1.0 : 0.0,
      medalType: medalType,
      subLabel: unlocked ? 'Hotovo!' : 'Pokračuj v sérii',
      onFlip: _triggerConfetti,
    );
  }

  Widget _buildStoryDifficultyRow(String label, bool unlocked, Color activeColor, String badgeTitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          unlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
          color: unlocked ? activeColor : Colors.grey.shade400,
          size: 28,
        ),
        title: Text(badgeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(label),
        trailing: Text(
          unlocked ? 'Odemčeno' : 'Zámek',
          style: TextStyle(
            color: unlocked ? activeColor : Colors.grey.shade400,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  Widget _buildSocialTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader('👥 POZVANÍ PŘÁTELÉ'),
        const SizedBox(height: 12),
        _buildStreakTile(
          'Nová krev I',
          'Měj alespoň 1 spojeného přítele v aplikaci (${_invitedFriendsCount}/1)',
          _invitedFriendsCount >= 1,
          'bronze',
        ),
        _buildStreakTile(
          'Nová krev II',
          'Měj alespoň 5 spojených přátel v aplikaci (${_invitedFriendsCount}/5)',
          _invitedFriendsCount >= 5,
          'silver',
        ),
        _buildStreakTile(
          'Nová krev III',
          'Měj alespoň 10 spojených přátel v aplikaci (${_invitedFriendsCount}/10)',
          _invitedFriendsCount >= 10,
          'gold',
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('💖 DONÁTOŘI A SPONZOŘI'),
        const SizedBox(height: 12),
        _buildStreakTile(
          'Věrný sponzor',
          'Podpoř vývoj projektu dobrovolným členstvím (Premium)',
          _hasOwnedPremium,
          'platinum',
        ),
        _buildStreakTile(
          'Patron na věky',
          'Podporuj projekt dobrovolným členstvím po dobu jednoho roku',
          _premiumForYear,
          'cosmic',
        ),
      ],
    );
  }
}

class AchievementCard extends StatefulWidget {
  final String title;
  final String description;
  final bool unlocked;
  final double progress;
  final String medalType;
  final String subLabel;
  final VoidCallback onFlip;

  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.progress,
    required this.medalType,
    required this.subLabel,
    required this.onFlip,
  });

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard> with SingleTickerProviderStateMixin {
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
    if (widget.unlocked) {
      widget.onFlip();
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: widget.unlocked 
              ? Border.all(color: const Color(0xFFBFFF00).withOpacity(0.8), width: 2.0)
              : Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: CustomPaint(
                    painter: MedalPainter(
                      medalType: widget.medalType,
                      unlocked: widget.unlocked,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: widget.progress,
                color: widget.unlocked ? const Color(0xFF5C9E00) : Colors.grey.shade400,
                backgroundColor: Colors.grey.shade200,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: widget.unlocked ? const Color(0xFF5C9E00) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack() {
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
            const Icon(Icons.info_outline_rounded, color: Color(0xFFBFFF00), size: 28),
            const SizedBox(height: 10),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.unlocked ? '🏆 ODEMČENO' : '🔒 UZAMČENO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.unlocked ? const Color(0xFFBFFF00) : Colors.grey.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 10,
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