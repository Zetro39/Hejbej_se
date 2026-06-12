import 'package:flutter/material.dart';

class QuestNode {
  final String id;
  final String name;
  final String description;
  int requiredDistance; // Cumulative meters from start to unlock
  final Offset mapPosition; // Coordinate on the 2D canvas map (0-1 range for responsive drawing)

  QuestNode({
    required this.id,
    required this.name,
    required this.description,
    required this.requiredDistance,
    required this.mapPosition,
  });
}

class QuestItem {
  final String id;
  final String name;
  final String description;
  final String assetPath;

  QuestItem({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
  });
}

class QuestState {
  final int currentDistanceWalked;
  final List<String> inventory;
  final List<String> unlockedNodes;
  final List<String> completedNodes;
  final Map<String, dynamic> roomStates;
  final String? currentRoomId;

  QuestState({
    required this.currentDistanceWalked,
    required this.inventory,
    required this.unlockedNodes,
    required this.completedNodes,
    required this.roomStates,
    this.currentRoomId,
  });

  QuestState copyWith({
    int? currentDistanceWalked,
    List<String>? inventory,
    List<String>? unlockedNodes,
    List<String>? completedNodes,
    Map<String, dynamic>? roomStates,
    String? currentRoomId,
    bool clearCurrentRoom = false,
  }) {
    return QuestState(
      currentDistanceWalked: currentDistanceWalked ?? this.currentDistanceWalked,
      inventory: inventory ?? this.inventory,
      unlockedNodes: unlockedNodes ?? this.unlockedNodes,
      completedNodes: completedNodes ?? this.completedNodes,
      roomStates: roomStates ?? this.roomStates,
      currentRoomId: clearCurrentRoom ? null : (currentRoomId ?? this.currentRoomId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentDistanceWalked': currentDistanceWalked,
      'inventory': inventory,
      'unlockedNodes': unlockedNodes,
      'completedNodes': completedNodes,
      'roomStates': roomStates,
      'currentRoomId': currentRoomId,
    };
  }

  factory QuestState.fromJson(Map<String, dynamic> json) {
    return QuestState(
      currentDistanceWalked: json['currentDistanceWalked'] as int? ?? 0,
      inventory: List<String>.from(json['inventory'] as List? ?? []),
      unlockedNodes: List<String>.from(json['unlockedNodes'] as List? ?? []),
      completedNodes: List<String>.from(json['completedNodes'] as List? ?? []),
      roomStates: Map<String, dynamic>.from(json['roomStates'] as Map? ?? {}),
      currentRoomId: json['currentRoomId'] as String?,
    );
  }

  factory QuestState.initial() {
    return QuestState(
      currentDistanceWalked: 0,
      inventory: [],
      unlockedNodes: ['node1'], // Node 1 is unlocked by default
      completedNodes: [],
      roomStates: {
        'node1_gate_open': false,
        'node1_has_handle': false,
        'node2_chest_open': false,
        'node2_chest_taken': false,
        'node2_has_amulet': false,
        'node3_has_key': false,
        'node3_has_moss': false,
        'node3_has_lens': false,
        'node3_vines_burned': false,
        'node3_tinder_lit': false,
        'node4_water_distilled': false,
        'node4_has_pipe': false,
        'node4_has_jar': false,
        'node4_has_herbs': false,
        'node4_tea_brewed': false,
        'node4_hermit_healed': false,
        'node4_barn_cleaned': false,
        'node5_gate_open': false,
        'node5_has_sword': false,
        'node5_has_acid': false,
        'node5_lens_cleaned': false,
        'node5_lens_placed': false,
        'node5_gears_fixed': false,
        'node5_puzzle_solved': false,
        'node6_gate_open': false,
        'node6_ash_collected': false,
        'node6_salt_collected': false,
        'node6_dust_collected': false,
        'node6_water_collected': false,
        'node6_elements_placed': false,
        'node6_amulet_active': false,
      },
      currentRoomId: null,
    );
  }
}
