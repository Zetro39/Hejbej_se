import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepTrackerService {
  static final StepTrackerService _instance = StepTrackerService._internal();
  factory StepTrackerService() => _instance;
  StepTrackerService._internal();

  StreamSubscription<StepCount>? _pedometerSubscription;
  
  final ValueNotifier<int> stepsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> goalNotifier = ValueNotifier<int>(10000);
  final ValueNotifier<bool> goalCompletedToday = ValueNotifier<bool>(false);
  final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await loadGoalAndStreak();
    await checkPermissionAndStart();
  }

  Future<void> loadGoalAndStreak() async {
    final prefs = await SharedPreferences.getInstance();
    goalNotifier.value = prefs.getInt('daily_steps_goal') ?? 10000;
    stepsNotifier.value = prefs.getInt('pedometer_today_steps') ?? 0;
    streakNotifier.value = prefs.getInt('steps_streak') ?? 0;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastGoalDate = prefs.getString('last_steps_goal_date') ?? '';
    goalCompletedToday.value = (lastGoalDate == todayStr);
  }

  Future<void> setStepsGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_steps_goal', newGoal);
    goalNotifier.value = newGoal;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'daily_steps_goal': newGoal,
        });
      } catch (_) {}
    }

    _checkGoalCompletion(stepsNotifier.value, newGoal);
  }

  Future<bool> checkPermissionAndStart() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Check permission using permission_handler on Android
      var status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        status = await Permission.activityRecognition.request();
      }

      if (status.isGranted) {
        _startPedometer();
        return true;
      } else {
        debugPrint('Activity recognition permission denied');
        return false;
      }
    } else {
      // On iOS, Pedometer package manages permission implicitly when listening.
      _startPedometer();
      return true;
    }
  }

  void _startPedometer() {
    _pedometerSubscription?.cancel();
    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('Pedometer error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to start Pedometer stream: $e');
    }
  }

  Future<void> _onStepCount(StepCount event) async {
    final eventSteps = event.steps;
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    
    final savedDate = prefs.getString('pedometer_baseline_date') ?? '';
    int baseline = prefs.getInt('pedometer_baseline_steps') ?? -1;
    int accumulated = prefs.getInt('pedometer_today_accumulated') ?? 0;
    int lastRaw = prefs.getInt('pedometer_last_seen_raw_steps') ?? 0;

    if (savedDate != todayStr || baseline == -1) {
      // New day or first run
      baseline = eventSteps;
      accumulated = 0;
      lastRaw = eventSteps;
      await prefs.setString('pedometer_baseline_date', todayStr);
      await prefs.setInt('pedometer_baseline_steps', baseline);
      await prefs.setInt('pedometer_today_accumulated', 0);
      await prefs.setInt('pedometer_last_seen_raw_steps', lastRaw);
    } else {
      if (eventSteps < lastRaw) {
        // Device rebooted, sensor reset to 0
        final walkedBeforeReboot = lastRaw - baseline;
        if (walkedBeforeReboot > 0) {
          accumulated += walkedBeforeReboot;
        }
        baseline = 0;
        await prefs.setInt('pedometer_baseline_steps', baseline);
        await prefs.setInt('pedometer_today_accumulated', accumulated);
      }
      lastRaw = eventSteps;
      await prefs.setInt('pedometer_last_seen_raw_steps', lastRaw);
    }

    int todaySteps = accumulated + (eventSteps - baseline);
    if (todaySteps < 0) todaySteps = 0;

    stepsNotifier.value = todaySteps;
    await prefs.setInt('pedometer_today_steps', todaySteps);
    await prefs.setInt('daily_steps_$todayStr', todaySteps);

    // Sync to HomeWidget
    try {
      await HomeWidget.saveWidgetData<int>('today_steps', todaySteps);
      await HomeWidget.saveWidgetData<int>('steps_goal', goalNotifier.value);
      await HomeWidget.updateWidget(name: 'HejbejSeWidgetProvider');
    } catch (_) {}

    // Sync to Firestore periodically or on change
    _syncStepsToFirestore(todaySteps);

    _checkGoalCompletion(todaySteps, goalNotifier.value);
  }

  Future<void> _syncStepsToFirestore(int steps) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'today_steps': steps,
        'last_steps_update': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _checkGoalCompletion(int steps, int goal) async {
    if (steps >= goal && !goalCompletedToday.value) {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      
      await prefs.setString('last_steps_goal_date', todayStr);
      goalCompletedToday.value = true;

      // Update calendar history (GitHub contribution style grid)
      await _updateGoalHistory(todayStr);

      // Calculate streak
      await _updateStreak(todayStr);
    }
  }

  Future<void> _updateGoalHistory(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('steps_goal_history') ?? [];
    if (!history.contains(dateStr)) {
      history.add(dateStr);
      await prefs.setStringList('steps_goal_history', history);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'steps_goal_history': FieldValue.arrayUnion([dateStr]),
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _updateStreak(String todayStr) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Find yesterday date string
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = yesterday.toIso8601String().substring(0, 10);
    
    final lastGoalDateBeforeToday = prefs.getString('previous_steps_goal_date') ?? '';
    int currentStreak = prefs.getInt('steps_streak') ?? 0;

    if (lastGoalDateBeforeToday == yesterdayStr) {
      currentStreak++;
    } else if (lastGoalDateBeforeToday.isEmpty || lastGoalDateBeforeToday != todayStr) {
      currentStreak = 1;
    }

    await prefs.setInt('steps_streak', currentStreak);
    await prefs.setString('previous_steps_goal_date', todayStr);
    streakNotifier.value = currentStreak;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'steps_streak': currentStreak,
        });
      } catch (_) {}
    }

    _checkAndUnlockAchievements(currentStreak);
  }

  Future<void> _checkAndUnlockAchievements(int streak) async {
    final milestones = [5, 10, 25, 50, 100, 365];
    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < milestones.length; i++) {
      final key = 'steps_achievement_${milestones[i]}';
      final isUnlocked = prefs.getBool(key) ?? false;

      if (streak >= milestones[i] && !isUnlocked) {
        await prefs.setBool(key, true);
        await logAchievementUnlock('${milestones[i]} dní plnění cíle');
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              key: true,
              'updated_at': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      }
    }
  }

  Future<void> logAchievementUnlock(String achievementTitle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'daily_achievements_$todayStr';
      List<String> list = prefs.getStringList(key) ?? [];
      if (!list.contains(achievementTitle)) {
        list.add(achievementTitle);
        await prefs.setStringList(key, list);
      }
    } catch (_) {}
  }

  void dispose() {
    _pedometerSubscription?.cancel();
  }
}
