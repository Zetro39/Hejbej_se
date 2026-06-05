import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationInboxItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool read;

  NotificationInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
  };

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) => NotificationInboxItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    read: json['read'] as bool? ?? false,
  );
}

class NotificationManager {
  static const String _keyNotifications = 'local_notifications_inbox';

  static Future<void> saveNotification(String title, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyNotifications) ?? [];
      
      final newItem = NotificationInboxItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
      );
      
      listJson.insert(0, jsonEncode(newItem.toJson())); // Newest first
      
      // Limit inbox to last 50 notifications
      if (listJson.length > 50) {
        listJson.removeRange(50, listJson.length);
      }
      
      await prefs.setStringList(_keyNotifications, listJson);
    } catch (_) {}
  }

  static Future<List<NotificationInboxItem>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyNotifications) ?? [];
      return listJson
          .map((e) => NotificationInboxItem.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyNotifications) ?? [];
      final updated = <String>[];
      for (final itemStr in listJson) {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        if (map['id'] == id) {
          map['read'] = true;
        }
        updated.add(jsonEncode(map));
      }
      await prefs.setStringList(_keyNotifications, updated);
    } catch (_) {}
  }

  static Future<void> deleteNotification(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_keyNotifications) ?? [];
      final updated = <String>[];
      for (final itemStr in listJson) {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        if (map['id'] != id) {
          updated.add(itemStr);
        }
      }
      await prefs.setStringList(_keyNotifications, updated);
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotifications);
    } catch (_) {}
  }
  
  static Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((item) => !item.read).length;
  }
}
