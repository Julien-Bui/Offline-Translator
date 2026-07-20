import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/local_db.dart';

class SyncService {
  static const String _backendUrl = 'https://offline-translator-production.up.railway.app';
  static const String _userId = 'device-12345';

  static Future<void> syncTranslations() async {
    try {
      final unsynced = await LocalDatabase.instance.getUnsyncedTranslations();
      if (unsynced.isEmpty) return;

      final payload = {
        "user_id": _userId,
        "translations": unsynced.map((item) => {
          "source_lang": item['sourceLang'],
          "target_lang": item['targetLang'],
          "original_text": item['original'],
          "translated_text": item['translated'],
          "timestamp": item['timestamp'],
        }).toList()
      };

      // Future http call here
      await Future.delayed(const Duration(seconds: 1));
      final idsToUpdate = unsynced.map((e) => e['id'] as int).toList();
      await LocalDatabase.instance.markAsSynced(idsToUpdate);
    } catch (e) {
      print("Offline mode: Sync delayed.");
    }
  }
}
