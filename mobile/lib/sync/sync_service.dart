import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class SyncService {
  static const String _backendUrl = 'https://offline-translator-production.up.railway.app';
  static const String _cacheFileName = 'languages_catalog_cache.json';
  static const Duration _networkTimeout = Duration(seconds: 10);

  /// Returns the cache file location in the application documents directory.
  static Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  /// Parses and validates a JSON list of language objects into a Map<String, TranslateLanguage>.
  static Map<String, TranslateLanguage> _parseCatalogList(List<dynamic> catalog) {
    final Map<String, TranslateLanguage> languages = {};
    for (var lang in catalog) {
      if (lang is! Map<String, dynamic>) continue;
      final name = lang['name'];
      final bcp47 = lang['bcp47_code'];
      if (name is! String || bcp47 is! String) continue;

      try {
        final enumVal = TranslateLanguage.values.firstWhere(
          (e) => e.bcpCode == bcp47,
        );
        languages[name.trim()] = enumVal;
      } catch (_) {
        // Unsupported or unrecognized BCP-47 language code ignored
      }
    }
    return languages;
  }

  /// Loads the cached language catalog from local storage if available.
  static Future<Map<String, TranslateLanguage>?> loadCachedCatalog() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        if (data is List) {
          final parsed = _parseCatalogList(data);
          if (parsed.isNotEmpty) {
            debugPrint("SyncService: Loaded ${parsed.length} languages from local cache.");
            return parsed;
          }
        }
      }
    } catch (e) {
      debugPrint("SyncService: Error reading local catalog cache: $e");
    }
    return null;
  }

  /// Fetches the language catalog from Railway backend and updates local cache.
  static Future<Map<String, TranslateLanguage>?> fetchLanguageCatalog() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/catalog'))
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'success' && data['catalog'] is List) {
          final List catalogList = data['catalog'];
          final parsedLanguages = _parseCatalogList(catalogList);

          if (parsedLanguages.isNotEmpty) {
            // Save raw catalog to local cache for offline persistence
            try {
              final file = await _getCacheFile();
              await file.writeAsString(jsonEncode(catalogList), flush: true);
              debugPrint("SyncService: Successfully cached ${parsedLanguages.length} languages.");
            } catch (cacheErr) {
              debugPrint("SyncService: Warning - failed to write cache: $cacheErr");
            }
            return parsedLanguages;
          }
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

