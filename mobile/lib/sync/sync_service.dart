import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db/local_db.dart';

class SyncService {
  static const String _backendUrl = 'https://offline-translator-production.up.railway.app';
  static const String _userId = 'device-12345';

  static Future<int> syncTranslations() async {
    try {
      final unsynced = await LocalDatabase.instance.getUnsyncedTranslations();
      if (unsynced.isEmpty) return 0;

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

      final response = await http.post(
        Uri.parse('$_backendUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final idsToUpdate = unsynced.map((e) => e['id'] as int).toList();
        await LocalDatabase.instance.markAsSynced(idsToUpdate);
        return idsToUpdate.length;
      } else {
        print("Erreur HTTP lors de la synchro: ${response.statusCode}");
        return 0;
      }
    } catch (e) {
      print("Erreur de connexion pour la synchro: $e");
      return 0;
    }
  }
}
