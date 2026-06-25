import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Nahraje lokální soubor obrázku do Firebase Storage
  /// pod cestu `routes/{userId}/{timestamp}.jpg` a vrátí download URL.
  Future<String?> uploadRouteImage({
    required String localPath,
    required String userId,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('Soubor na cestě $localPath neexistuje.');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref().child('routes').child(userId).child('$timestamp.jpg');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Chyba při nahrávání obrázku na Cloud Storage: $e');
      return null;
    }
  }
}
