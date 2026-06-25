import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      // 1. Nastavení výchozích hodnot (defaults)
      await _remoteConfig.setDefaults(const {
        'use_math_fallback': false,
        'gemini_model': 'gemini-1.5-flash',
      });

      // 2. Konfigurace intervalu stahování (min. 1 hodina pro produkci, kratší pro debug)
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 1),
      ));

      // 3. Stažení a aktivace nejnovějších hodnot z Firebase
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Firebase Remote Config inicializace selhala: $e');
    }
  }

  // 4. Gettery pro snadný přístup k hodnotám
  bool get useMathFallback => _remoteConfig.getBool('use_math_fallback');
  String get geminiModel {
    final model = _remoteConfig.getString('gemini_model');
    return model.isNotEmpty ? model : 'gemini-1.5-flash';
  }
}
