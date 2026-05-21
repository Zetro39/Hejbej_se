import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _storage = FlutterSecureStorage();
  static const _keyUserName = 'user_name';
  static const _keyAuthPrefix = 'auth_';

  Future<void> saveUserName(String name) async {
    try {
      await _storage.write(key: _keyUserName, value: name);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save user name: $e');
    }
  }

  Future<String?> getUserName() async {
    try {
      return await _storage.read(key: _keyUserName);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to read user name: $e');
      return null;
    }
  }

  Future<void> saveAuthCredentials(String provider, Map<String, String?> data) async {
    try {
      final key = '$_keyAuthPrefix$provider';
      final json = data.entries.map((e) => '"${e.key}":"${e.value ?? ''}"').join(',');
      await _storage.write(key: key, value: '{${json}}');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to save auth credentials for $provider: $e');
    }
  }

  Future<String?> getAuthCredentials(String provider) async {
    try {
      final key = '$_keyAuthPrefix$provider';
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to read auth credentials for $provider: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _keyUserName);
      // remove any stored provider credentials
      // flutter_secure_storage doesn't provide listing across platforms reliably here,
      // so attempt to delete common keys if present
      await _storage.delete(key: '${_keyAuthPrefix}google');
      await _storage.delete(key: '${_keyAuthPrefix}apple');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear user name: $e');
    }
  }
}
