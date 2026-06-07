import 'dart:convert';
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

  final List<QuestNode> nodes = [
    QuestNode(
      id: 'node1',
      name: 'Lesní brána',
      description: 'Vstup do hlubokého lesa chráněný starou bránou.',
      requiredDistance: 0,
      mapPosition: const Offset(0.2, 0.85),
    ),
    QuestNode(
      id: 'node2',
      name: 'Starý dub',
      description: 'Prastarý strom s vyřezanými magickými symboly.',
      requiredDistance: 400,
      mapPosition: const Offset(0.5, 0.7),
    ),
    QuestNode(
      id: 'node3',
      name: 'Zřícenina chýše',
      description: 'Zřícenina domku bývalého hajného.',
      requiredDistance: 1000,
      mapPosition: const Offset(0.3, 0.5),
    ),
    QuestNode(
      id: 'node4',
      name: 'Bažina & Studna',
      description: 'Svatyně skrytá v mlžném oparu bažin.',
      requiredDistance: 2500,
      mapPosition: const Offset(0.7, 0.4),
    ),
    QuestNode(
      id: 'node5',
      name: 'Zapomenutá pevnost',
      description: 'Opuštěná kamenná pevnost s vysokou věží.',
      requiredDistance: 4500,
      mapPosition: const Offset(0.4, 0.2),
    ),
    QuestNode(
      id: 'node6',
      name: 'Kamenný oltář',
      description: 'Vrcholek skály s rituálním kruhem.',
      requiredDistance: 6000,
      mapPosition: const Offset(0.8, 0.1),
    ),
  ];

  final Map<String, QuestItem> allItems = {
    'iron_handle': QuestItem(
      id: 'iron_handle',
      name: 'Kovaná klika',
      description: 'Stará železná klika, která pasuje do lesní brány.',
      assetPath: 'assets/images/story_item_handle.png',
    ),
    'lens': QuestItem(
      id: 'lens',
      name: 'Prasklá lupa',
      description: 'Díky loupání slunce s ní lze zažehnout suchý troud.',
      assetPath: 'assets/images/story_item_lens.png',
    ),
    'tinder': QuestItem(
      id: 'tinder',
      name: 'Suchý mech',
      description: 'Velmi suchý lesní mech, skvělý pro rozdělání ohně.',
      assetPath: 'assets/images/story_item_tinder.png',
    ),
    'smoldering_tinder': QuestItem(
      id: 'smoldering_tinder',
      name: 'Doutnající troud',
      description: 'Doutnající mech, který dokáže zapálit oheň.',
      assetPath: 'assets/images/story_item_smoldering.png',
    ),
    'oil': QuestItem(
      id: 'oil',
      name: 'Olej na rez',
      description: 'Mazadlo pro uvolnění zrezivělých mechanismů.',
      assetPath: 'assets/images/story_item_oil.png',
    ),
    'dirty_key': QuestItem(
      id: 'dirty_key',
      name: 'Zanesený klíč',
      description: 'Klíč od lesní brány pokrytý rzí. Chce to obrousit.',
      assetPath: 'assets/images/story_item_dirty_key.png',
    ),
    'fixed_key': QuestItem(
      id: 'fixed_key',
      name: 'Klíč od brány',
      description: 'Obroušený a namazaný klíč k lesní bráně.',
      assetPath: 'assets/images/story_item_fixed_key.png',
    ),
    'blue_mushrooms': QuestItem(
      id: 'blue_mushrooms',
      name: 'Modré houby',
      description: 'Vzácné houby z bažiny se silnými hojivými účinky.',
      assetPath: 'assets/images/story_item_mushrooms.png',
    ),
    'copper_pipe': QuestItem(
      id: 'copper_pipe',
      name: 'Měděná trubka',
      description: 'Ohebná trubka, užitečná pro odvádění páry.',
      assetPath: 'assets/images/story_item_pipe.png',
    ),
    'pot': QuestItem(
      id: 'pot',
      name: 'Kotlík',
      description: 'Kovový kotlík pro vaření vody a lektvarů.',
      assetPath: 'assets/images/story_item_pot.png',
    ),
    'pure_water': QuestItem(
      id: 'pure_water',
      name: 'Destilovaná voda',
      description: 'Čistá, nezávadná voda získaná destilací.',
      assetPath: 'assets/images/story_item_water.png',
    ),
    'potion': QuestItem(
      id: 'potion',
      name: 'Léčivý elixír',
      description: 'Modrý lektvar, který spolehlivě léčí horečku.',
      assetPath: 'assets/images/story_item_potion.png',
    ),
    'well_handle': QuestItem(
      id: 'well_handle',
      name: 'Klika navijáku',
      description: 'Klika ke studni, slouží k vytažení vědra.',
      assetPath: 'assets/images/story_item_well_handle.png',
    ),
    'triangular_key': QuestItem(
      id: 'triangular_key',
      name: 'Trojúhelníkový klíč',
      description: 'Starobylý klíč s trojúhelníkovým profilem.',
      assetPath: 'assets/images/story_item_triangular_key.png',
    ),
    'amulet': QuestItem(
      id: 'amulet',
      name: 'Vyhaslý amulet',
      description: 'Prázdný kovový amulet. Potřebuje nabít živly.',
      assetPath: 'assets/images/story_item_amulet.png',
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
    'acid': QuestItem(
      id: 'acid',
      name: 'Kyselina v lahvičce',
      description: 'Silná kyselina, rozpouští pryskyřici a čistí sklo.',
      assetPath: 'assets/images/story_item_acid.png',
    ),
    'clean_lens': QuestItem(
      id: 'clean_lens',
      name: 'Čistá čočka',
      description: 'Vyleštěná čočka pro dalekohled.',
      assetPath: 'assets/images/story_item_clean_lens.png',
    ),
    'item_ash': QuestItem(
      id: 'item_ash',
      name: 'Element Ohně (Popel)',
      description: 'Popel z ohniště strážců, symbolizuje oheň.',
      assetPath: 'assets/images/story_item_ash.png',
    ),
    'item_salt': QuestItem(
      id: 'item_salt',
      name: 'Element Země (Sůl)',
      description: 'Horská sůl ze skalního průsmyku.',
      assetPath: 'assets/images/story_item_salt.png',
    ),
    'item_dust': QuestItem(
      id: 'item_dust',
      name: 'Element Vzduchu (Prach)',
      description: 'Prach ze starobylé knihovny pevnosti.',
      assetPath: 'assets/images/story_item_dust.png',
    ),
    'item_water': QuestItem(
      id: 'item_water',
      name: 'Element Vody',
      description: 'Destilovaná voda bažiny.',
      assetPath: 'assets/images/story_item_water.png',
    ),
    'stick': QuestItem(
      id: 'stick',
      name: 'Suchá větev',
      description: 'Dlouhá suchá větev. Ideální základ pro pochodeň.',
      assetPath: 'assets/images/story_item_stick.png',
    ),
    'cloth': QuestItem(
      id: 'cloth',
      name: 'Mastný hadr',
      description: 'Mastný hadr nalezený v chýši. Skvěle hoří.',
      assetPath: 'assets/images/story_item_cloth.png',
    ),
    'torch': QuestItem(
      id: 'torch',
      name: 'Nezapálená pochodeň',
      description: 'Nezapálená pochodeň vyrobená z větve a hadru. Musíš ji něčím zapálit.',
      assetPath: 'assets/images/story_item_torch.png',
    ),
    'burning_torch': QuestItem(
      id: 'burning_torch',
      name: 'Zapálená pochodeň',
      description: 'Jasně planoucí pochodeň. Osvětlí temná místa a spálí překážky.',
      assetPath: 'assets/images/story_item_burning_torch.png',
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

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
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

      if (!alreadyCompleted) {
        final currentLimetky = data['limetky'] as int? ?? 0;
        final newLimetky = currentLimetky + 50;

        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'limetky': newLimetky,
          'achievement_hero_lost_amulet': true,
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
          },
        });

        // Also set locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('limetky', newLimetky);
        await prefs.setBool('achievement_hero_lost_amulet', true);
      }
    } catch (_) {}
  }
}
