import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'step_tracker_service.dart';

enum MovementType { walking, cycling, driving, unknown }

class AntiCheatService {
  static final AntiCheatService _instance = AntiCheatService._internal();
  factory AntiCheatService() => _instance;
  AntiCheatService._internal() {
    // Listen to steps from StepTrackerService to track pedometer activity
    StepTrackerService().stepsNotifier.addListener(_onStepsUpdated);
    _lastStepCount = StepTrackerService().stepsNotifier.value;
  }

  Position? _lastPos;
  final List<double> _speedHistory = [];
  final List<bool> _violationHistory = [];
  
  final ValueNotifier<bool> isCheatingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> cheatReasonNotifier = ValueNotifier<String>('');
  final ValueNotifier<double> currentSpeedNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<MovementType> movementTypeNotifier = ValueNotifier<MovementType>(MovementType.unknown);

  int _lastStepCount = 0;
  bool _pedometerActive = false;
  DateTime? _lastStepTime;

  bool get isCheating => isCheatingNotifier.value;
  String get cheatReason => cheatReasonNotifier.value;
  double get currentSpeedKmH => currentSpeedNotifier.value;
  MovementType get currentMovementType => movementTypeNotifier.value;

  void _onStepsUpdated() {
    final steps = StepTrackerService().stepsNotifier.value;
    if (_lastStepCount == 0) {
      _lastStepCount = steps;
      return;
    }
    final diff = steps - _lastStepCount;
    if (diff > 0) {
      _pedometerActive = true;
      _lastStepTime = DateTime.now();
      _lastStepCount = steps;
    }
  }

  /// Reset history (e.g. when starting a new route)
  void reset() {
    _lastPos = null;
    _speedHistory.clear();
    _violationHistory.clear();
    isCheatingNotifier.value = false;
    cheatReasonNotifier.value = '';
    currentSpeedNotifier.value = 0.0;
    movementTypeNotifier.value = MovementType.unknown;
    _lastStepCount = StepTrackerService().stepsNotifier.value;
  }

  /// Processes location update and returns true if distance should be counted
  bool checkLocationUpdate(Position position, bool usingBike) {
    if (_lastPos == null) {
      _lastPos = position;
      _lastStepCount = StepTrackerService().stepsNotifier.value;
      return true;
    }

    final distanceMeters = Geolocator.distanceBetween(
      _lastPos!.latitude,
      _lastPos!.longitude,
      position.latitude,
      position.longitude,
    );

    final timeDiffSeconds = position.timestamp.difference(_lastPos!.timestamp).inSeconds;
    _lastPos = position;

    if (timeDiffSeconds <= 0) {
      // Ignore duplicates
      return !isCheating;
    }

    // Calculate speed in km/h
    double speedKmH = (distanceMeters / timeDiffSeconds) * 3.6;
    // Fallback/Validation with device speed reporting (in m/s)
    if (position.speed > 0.0) {
      final gpsSpeedKmH = position.speed * 3.6;
      // If there's a huge discrepancy, prefer GPS speed if calculated is affected by warp/spikes
      if ((speedKmH - gpsSpeedKmH).abs() > 30.0) {
        speedKmH = gpsSpeedKmH;
      }
    }

    currentSpeedNotifier.value = speedKmH;

    // Check step increment in this interval
    final currentSteps = StepTrackerService().stepsNotifier.value;
    final stepDiff = currentSteps - _lastStepCount;
    _lastStepCount = currentSteps;

    // If pedometer was recently active (updated in last 5 minutes), check steps
    if (_lastStepTime != null && DateTime.now().difference(_lastStepTime!).inMinutes > 5) {
      // Pedometer has been silent for 5+ minutes, might be pocketed or inactive
      _pedometerActive = false;
    }

    // Determine violation
    bool violation = false;
    String reason = '';
    MovementType detectedType = MovementType.unknown;

    // Speeds:
    // Walking/Running: < 20 km/h
    // Cycling: 10 - 45 km/h
    // Driving: > 45 km/h
    if (speedKmH > 45.0) {
      violation = true;
      reason = 'Detekována jízda autem / MHD (${speedKmH.toStringAsFixed(1)} km/h)';
      detectedType = MovementType.driving;
    } else if (speedKmH > 20.0) {
      detectedType = MovementType.cycling;
      if (!usingBike) {
        violation = true;
        reason = 'Detekována jízda na kole v režimu pro pěší (${speedKmH.toStringAsFixed(1)} km/h)';
      }
    } else if (speedKmH > 6.0 && _pedometerActive && stepDiff < 2 && !usingBike) {
      // Moving fast (> 6 km/h) but taking 0 steps, likely cycling slowly or riding scooter
      violation = true;
      reason = 'Detekována jízda bez kroků (${speedKmH.toStringAsFixed(1)} km/h)';
      detectedType = MovementType.cycling;
    } else {
      detectedType = speedKmH > 1.5 ? MovementType.walking : MovementType.unknown;
    }

    movementTypeNotifier.value = detectedType;

    // Add to rolling history
    _speedHistory.add(speedKmH);
    _violationHistory.add(violation);
    if (_speedHistory.length > 4) {
      _speedHistory.removeAt(0);
      _violationHistory.removeAt(0);
    }

    // Flag cheating if at least 2 out of the last 3 points are violations
    int violationCount = _violationHistory.where((v) => v).length;
    bool shouldFlagCheat = violationCount >= 2;

    if (shouldFlagCheat) {
      isCheatingNotifier.value = true;
      cheatReasonNotifier.value = reason;
      return false; // Cheat detected, discard distance
    } else {
      // To recover from cheat state, we need 2 consecutive non-violations
      if (isCheating) {
        int recentNonViolations = 0;
        for (int i = _violationHistory.length - 1; i >= 0; i--) {
          if (!_violationHistory[i]) {
            recentNonViolations++;
          } else {
            break;
          }
        }
        if (recentNonViolations >= 2) {
          isCheatingNotifier.value = false;
          cheatReasonNotifier.value = '';
        }
      }
      return !isCheating;
    }
  }
}
