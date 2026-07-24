import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class SyncService {
  static const String _backendUrl = 'https://offline-translator-production.up.railway.app';

  static Future<Map<String, TranslateLanguage>?> fetchLanguageCatalog() async {
    try {
      final response = await http.get(Uri.parse('$_backendUrl/catalog'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List catalog = data['catalog'];
          Map<String, TranslateLanguage> newSupportedLanguages = {};
          for (var lang in catalog) {
            try {
              final bcp47 = lang['bcp47_code'];
              // Map the BCP-47 string to ML Kit's TranslateLanguage enum
              final enumVal = TranslateLanguage.values.firstWhere(
                (e) => e.bcpCode == bcp47,
              );
              newSupportedLanguages[lang['name']] = enumVal;
            } catch (_) {
              // Ignore invalid/unsupported languages
            }
          }
          return newSupportedLanguages;
        }
      }
      debugPrint("HTTP error fetching catalog: ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("Connection error fetching catalog: $e");
      return null;
    }
  }
}

