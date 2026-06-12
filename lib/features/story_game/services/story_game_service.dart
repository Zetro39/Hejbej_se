import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/step_tracker_service.dart';
import '../models/story_quest_model.dart';

class StoryGameService {
  static final StoryGameService _instance = StoryGameService._internal();
  factory StoryGameService() => _instance;
  StoryGameService._internal();

  final ValueNotifier<QuestState> stateNotifier = ValueNotifier<QuestState>(QuestState.initial());
  bool _isInitialized = false;
  String? currentDifficulty;

  final List<QuestNode> nodes = [
    QuestNode(
      id: 'node1',
      name: 'Lesní brána',
      description: 'Vstup do hlubokého lesa chráněný starou bránou.',
      requiredDistance: 0,
      mapPosition: const Offset(0.4945, 0.9442),
    ),
    QuestNode(
      id: 'node2',
      name: 'Starý dub',
      description: 'Prastarý strom s vyřezanými magickými symboly.',
      requiredDistance: 400,
      mapPosition: const Offset(0.6353, 0.8153),
    ),
    QuestNode(
      id: 'node3',
      name: 'Zřícenina chýše',
      description: 'Zřícenina domku bývalého hajného.',
      requiredDistance: 1000,
      mapPosition: const Offset(0.4648, 0.6549),
    ),
    QuestNode(
      id: 'node4',
      name: 'Bažina & Studna',
      description: 'Svatyně skrytá v mlžném oparu bažin.',
      requiredDistance: 2500,
      mapPosition: const Offset(0.4131, 0.5005),
    ),
    QuestNode(
      id: 'node5',
      name: 'Zapomenutá pevnost',
      description: 'Opuštěná kamenná pevnost s vysokou věží.',
      requiredDistance: 4500,
      mapPosition: const Offset(0.5064, 0.3767),
    ),
    QuestNode(
      id: 'node6',
      name: 'Kamenný oltář',
      description: 'Vrcholek skály s rituálním kruhem.',
      requiredDistance: 6000,
      mapPosition: const Offset(0.5072, 0.2473),
    ),
  ];

  final Map<String, List<Offset>> segmentPaths = {
    'node1_node2': [
      const Offset(0.5148, 0.8890),
      const Offset(0.5615, 0.8298),
    ],
    'node2_node3': [
      const Offset(0.5174, 0.8238),
      const Offset(0.3732, 0.7808),
      const Offset(0.3045, 0.7386),
      const Offset(0.3876, 0.6838),
    ],
    'node3_node4': [
      const Offset(0.6565, 0.6043),
      const Offset(0.6243, 0.5658),
      const Offset(0.5488, 0.5336),
    ],
    'node4_node5': [
      const Offset(0.5242, 0.4716),
      const Offset(0.5869, 0.4490),
      const Offset(0.5013, 0.4186),
    ],
    'node5_node6': [],
  };

  List<Offset> getFullSegmentPath(QuestNode nodeA, QuestNode nodeB) {
    final key = "${nodeA.id}_${nodeB.id}";
    final intermediate = segmentPaths[key];
    if (intermediate == null || intermediate.isEmpty) {
      return [nodeA.mapPosition, nodeB.mapPosition];
    }
    return [nodeA.mapPosition, ...intermediate, nodeB.mapPosition];
  }

  final Map<String, QuestItem> allItems = {
    'dirty_key': QuestItem(
      id: 'dirty_key',
      name: 'Zanesený klíč',
      description: 'Zanesený a rezavý klíč. Bude potřeba ho vyčistit a naolejovat.',
      assetPath: 'assets/images/story_item_dirty_key.png',
    ),
    'oil': QuestItem(
      id: 'oil',
      name: 'Olej na rez',
      description: 'Jemný mechanický olej. Skvělý na odstranění rzi a promazání zámků.',
      assetPath: 'assets/images/story_item_oil.png',
    ),
    'fixed_key': QuestItem(
      id: 'fixed_key',
      name: 'Klíč od brány',
      description: 'Vyčištěný a naolejovaný klíč k lesní bráně.',
      assetPath: 'assets/images/story_item_fixed_key.png',
    ),
    'stick': QuestItem(
      id: 'stick',
      name: 'Dřevěný sloupek',
      description: 'Dřevěný sloupek z rozpadlé lesní značky. Ideální základ pro pochodeň.',
      assetPath: 'assets/images/story_item_stick.png',
    ),
    'blue_mushrooms': QuestItem(
      id: 'blue_mushrooms',
      name: 'Modré houby',
      description: 'Vzácné houby se silnými léčivými účinky.',
      assetPath: 'assets/images/story_item_mushrooms.png',
    ),
    'cloth': QuestItem(
      id: 'cloth',
      name: 'Mastný hadr',
      description: 'Mastný hadr nalezený v chýši. Skvěle hoří.',
      assetPath: 'assets/images/story_item_cloth.png',
    ),
    'lens': QuestItem(
      id: 'lens',
      name: 'Prasklá lupa',
      description: 'Stará lupa s popraskaným sklem. Lze ji využít k zažehnutí troudu.',
      assetPath: 'assets/images/story_item_lens.png',
    ),
    'tinder': QuestItem(
      id: 'tinder',
      name: 'Suchý mech',
      description: 'Velmi suchý mech, skvělý pro rozdělání ohně.',
      assetPath: 'assets/images/story_item_tinder.png',
    ),
    'smoldering_tinder': QuestItem(
      id: 'smoldering_tinder',
      name: 'Doutnající troud',
      description: 'Doutnající mech, který dokáže zapálit oheň.',
      assetPath: 'assets/images/story_item_smoldering.png',
    ),
    'torch': QuestItem(
      id: 'torch',
      name: 'Nezapálená pochodeň',
      description: 'Nezapálená pochodeň vyrobená z větve a hadru.',
      assetPath: 'assets/images/story_item_torch.png',
    ),
    'burning_torch': QuestItem(
      id: 'burning_torch',
      name: 'Zapálená pochodeň',
      description: 'Jasně planoucí pochodeň. Slouží zároveň jako Element Ohně.',
      assetPath: 'assets/images/story_item_burning_torch.png',
    ),
    'item_ash': QuestItem(
      id: 'item_ash',
      name: 'Popel a prach',
      description: 'Popel ze spáleného křoví. Slouží zároveň jako Element Vzduchu.',
      assetPath: 'assets/images/story_item_ash.png',
    ),
    'item_water': QuestItem(
      id: 'item_water',
      name: 'Kbelík vody',
      description: 'Kbelík s čistou vodou vytažený ze studny. Slouží zároveň jako Element Vody.',
      assetPath: 'assets/images/story_item_water.png',
    ),
    'pot': QuestItem(
      id: 'pot',
      name: 'Měděný kotlík',
      description: 'Starý měděný kotlík. Hodí se na vaření elixírů.',
      assetPath: 'assets/images/story_item_pot.png',
    ),
    'well_handle': QuestItem(
      id: 'well_handle',
      name: 'Klika od studny',
      description: 'Těžká železná klika, která pasuje do navijáku studny.',
      assetPath: 'assets/images/story_item_well_handle.png',
    ),
    'potion': QuestItem(
      id: 'potion',
      name: 'Léčivý elixír',
      description: 'Modrý lektvar, který spolehlivě vyléčí poustevníkovu horečku.',
      assetPath: 'assets/images/story_item_potion.png',
    ),
    'key_armory': QuestItem(
      id: 'key_armory',
      name: 'Klíč od zbrojnice',
      description: 'Těžký železný klíč od zbrojnice v pevnosti.',
      assetPath: 'assets/images/story_item_key_armory.png',
    ),
    'stone_sword': QuestItem(
      id: 'stone_sword',
      name: 'Kamenný meč',
      description: 'Stará replika meče, pasuje do rukou sochy rytíře.',
      assetPath: 'assets/images/story_item_sword.png',
    ),
    'clean_lens': QuestItem(
      id: 'clean_lens',
      name: 'Čistá čočka',
      description: 'Vyleštěná skleněná čočka pro dalekohled.',
      assetPath: 'assets/images/story_item_clean_lens.png',
    ),
    'item_salt': QuestItem(
      id: 'item_salt',
      name: 'Posvátný kámen',
      description: 'Kámen ze starobylé kamenné mohyly u oltáře. Představuje Element Země.',
      assetPath: 'assets/images/story_item_salt.png',
    ),
  };

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await loadState();
    // Listen to steps changes from StepTrackerService to update distance walked
    StepTrackerService().stepsNotifier.addListener(_onStepsChanged);
  }

  void _onStepsChanged() async {
    final steps = StepTrackerService().stepsNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastSeen = prefs.getInt('quest_last_seen_steps') ?? steps;
    final lastSeenDate = prefs.getString('quest_last_seen_date') ?? todayStr;

    int diff = 0;
    if (lastSeenDate == todayStr && steps > lastSeen) {
      diff = steps - lastSeen;
    }

    await prefs.setInt('quest_last_seen_steps', steps);
    await prefs.setString('quest_last_seen_date', todayStr);

    if (diff > 0) {
      double deltaMeters = diff * 0.75;
      await addMeters(deltaMeters.toInt());
    }
  }

  Future<void> setDifficulty(String difficulty) async {
    currentDifficulty = difficulty;
    
    // Generate distances based on difficulty
    List<int> distances;
    if (difficulty == 'easy') {
      distances = [0, 1000, 2000, 3000, 4000, 6000];
    } else {
      int totalKm = difficulty == 'medium' ? 10 : (difficulty == 'hard' ? 15 : 20);
      final totalMeters = totalKm * 1000;
      final rand = Random();
      
      // Let's divide totalMeters into 5 segments.
      // Minimum segment length is 10% of total
      final minSegment = (totalMeters / 10).round();
      int remaining = totalMeters - (5 * minSegment);
      List<int> segments = List.filled(5, minSegment);
      
      for (int i = 0; i < 5; i++) {
        if (remaining <= 0) break;
        int share = i == 4 ? remaining : rand.nextInt(remaining ~/ 2 + 1);
        segments[i] += share;
        remaining -= share;
      }
      segments.shuffle(rand);
      
      distances = [0];
      int current = 0;
      for (var seg in segments) {
        current += seg;
        distances.add(current);
      }
    }

    // Apply to nodes
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].requiredDistance = distances[i];
    }

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('story_difficulty', difficulty);
    await prefs.setStringList('story_node_distances', distances.map((d) => d.toString()).toList());
    
    _checkUnlockConditions();
    await saveState();
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load difficulty and distances first
    final savedDifficulty = prefs.getString('story_difficulty');
    final savedDistances = prefs.getStringList('story_node_distances');
    
    if (savedDifficulty != null && savedDistances != null && savedDistances.length == nodes.length) {
      currentDifficulty = savedDifficulty;
      for (int i = 0; i < nodes.length; i++) {
        nodes[i].requiredDistance = int.parse(savedDistances[i]);
      }
    } else {
      currentDifficulty = null; // Needs choice
    }

    final stateJson = prefs.getString('story_quest_state');
    if (stateJson != null) {
      try {
        stateNotifier.value = QuestState.fromJson(jsonDecode(stateJson));
        _checkUnlockConditions();
        return;
      } catch (_) {}
    }

    // Try sync from Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null && data.containsKey('story_quest_state')) {
          final stateMap = Map<String, dynamic>.from(data['story_quest_state'] as Map);
          stateNotifier.value = QuestState.fromJson(stateMap);
          await saveState();
          return;
        }
      } catch (_) {}
    }

    // Fallback to initial
    stateNotifier.value = QuestState.initial();
    await saveState();
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(stateNotifier.value.toJson());
    await prefs.setString('story_quest_state', jsonStr);

    // Sync to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'story_quest_state': stateNotifier.value.toJson(),
        });
      } catch (_) {}
    }
  }

  Future<void> resetQuest() async {
    stateNotifier.value = QuestState.initial();
    final prefs = await SharedPreferences.getInstance();
    
    // Clear difficulty and distances
    await prefs.remove('story_difficulty');
    await prefs.remove('story_node_distances');
    currentDifficulty = null;
    
    // Reset nodes to default distances
    final defaultDistances = [0, 1000, 2000, 3000, 4000, 6000];
    for (int i = 0; i < nodes.length; i++) {
      nodes[i].requiredDistance = defaultDistances[i];
    }

    final steps = StepTrackerService().stepsNotifier.value;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setInt('quest_last_seen_steps', steps);
    await prefs.setString('quest_last_seen_date', todayStr);
    await saveState();
  }

  Future<void> addMeters(int meters) async {
    final currentDist = stateNotifier.value.currentDistanceWalked + meters;
    stateNotifier.value = stateNotifier.value.copyWith(
      currentDistanceWalked: currentDist,
    );
    _checkUnlockConditions();
    await saveState();
  }

  void _checkUnlockConditions() {
    final currentDist = stateNotifier.value.currentDistanceWalked;
    final List<String> newlyUnlocked = List.from(stateNotifier.value.unlockedNodes);

    for (var node in nodes) {
      if (currentDist >= node.requiredDistance && !newlyUnlocked.contains(node.id)) {
        newlyUnlocked.add(node.id);
      }
    }

    if (newlyUnlocked.length != stateNotifier.value.unlockedNodes.length) {
      stateNotifier.value = stateNotifier.value.copyWith(
        unlockedNodes: newlyUnlocked,
      );
    }
  }

  // Inventory logic
  void collectItem(String itemId) {
    if (!allItems.containsKey(itemId)) return;
    if (stateNotifier.value.inventory.contains(itemId)) return;

    final updatedInv = List<String>.from(stateNotifier.value.inventory)..add(itemId);
    stateNotifier.value = stateNotifier.value.copyWith(inventory: updatedInv);
    saveState();
  }

  void removeItem(String itemId) {
    if (!stateNotifier.value.inventory.contains(itemId)) return;

    final updatedInv = List<String>.from(stateNotifier.value.inventory)..remove(itemId);
    stateNotifier.value = stateNotifier.value.copyWith(inventory: updatedInv);
    saveState();
  }

  void updateRoomState(String key, dynamic value) {
    final updatedStates = Map<String, dynamic>.from(stateNotifier.value.roomStates);
    updatedStates[key] = value;
    stateNotifier.value = stateNotifier.value.copyWith(roomStates: updatedStates);
    saveState();
  }

  void batchUpdate({List<String>? itemsToRemove, Map<String, dynamic>? roomStatesToUpdate}) {
    var currentState = stateNotifier.value;
    List<String> updatedInv = List<String>.from(currentState.inventory);
    if (itemsToRemove != null) {
      for (final item in itemsToRemove) {
        updatedInv.remove(item);
      }
    }
    Map<String, dynamic> updatedStates = Map<String, dynamic>.from(currentState.roomStates);
    if (roomStatesToUpdate != null) {
      roomStatesToUpdate.forEach((key, value) {
        updatedStates[key] = value;
      });
    }
    stateNotifier.value = currentState.copyWith(
      inventory: updatedInv,
      roomStates: updatedStates,
    );
    saveState();
  }

  void completeNode(String nodeId) {
    if (stateNotifier.value.completedNodes.contains(nodeId)) return;

    final updatedCompleted = List<String>.from(stateNotifier.value.completedNodes)..add(nodeId);
    stateNotifier.value = stateNotifier.value.copyWith(completedNodes: updatedCompleted);
    saveState();
  }

  void enterRoom(String roomId) {
    stateNotifier.value = stateNotifier.value.copyWith(currentRoomId: roomId);
    saveState();
  }

  void exitRoom() {
    stateNotifier.value = stateNotifier.value.copyWith(clearCurrentRoom: true);
    saveState();
  }

  // Award rewards on final completion
  Future<void> claimFinalReward() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      final alreadyCompleted = data['achievement_hero_lost_amulet'] as bool? ?? false;
      
      final diff = currentDifficulty ?? 'easy';

      // Always save the difficulty completion locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('achievement_story_difficulty_$diff', true);

      final names = {
        'easy': 'Lehká trasa',
        'medium': 'Střední trasa',
        'hard': 'Těžká trasa',
        'hardcore': 'Hardcore trasa',
      };
      final title = names[diff] ?? 'Trasa';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      List<String> list = prefs.getStringList('daily_achievements_$todayStr') ?? [];
      if (!list.contains(title)) {
        list.add(title);
      }
      if (!list.contains('Ztracený amulet')) {
        list.add('Ztracený amulet');
      }
      await prefs.setStringList('daily_achievements_$todayStr', list);

      if (!alreadyCompleted) {
        final currentLimetky = data['limetky'] as int? ?? 0;
        final newLimetky = currentLimetky + 50;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'limetky': newLimetky,
          'achievement_hero_lost_amulet': true,
          'achievement_story_difficulty_$diff': true,
        });

        // Write to activities feed
        final username = data['username'] as String? ?? 'Uživatel';
        await FirebaseFirestore.instance.collection('activities').add({
          'uid': user.uid,
          'username': username,
          'type': 'story_completion',
          'timestamp': FieldValue.serverTimestamp(),
          'details': {
            'storyId': 'lost_amulet',
            'storyName': 'Ztracený amulet',
            'difficulty': diff,
          },
        });

        // Also set locally
        await prefs.setInt('limetky', newLimetky);
        await prefs.setBool('achievement_hero_lost_amulet', true);
      } else {
        // If already completed on another difficulty, we still sync the new difficulty achievement to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'achievement_story_difficulty_$diff': true,
        });
      }
    } catch (_) {}
  }
}
