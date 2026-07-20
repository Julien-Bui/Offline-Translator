import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'db/local_db.dart';
import 'sync/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database;
  runApp(const OfflineTranslatorApp());
}

class OfflineTranslatorApp extends StatelessWidget {
  const OfflineTranslatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Trad Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const TranslationScreen(),
    );
  }
}

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});
  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  String _translatedText = "";
  bool _isTranslating = false;
  bool _isListening = false;
  
  String _sourceLang = "Français";
  String _targetLang = "Anglais";

  // Dictionnaire des langues supportées (Interface -> ML Kit)
  final Map<String, TranslateLanguage> _supportedLanguages = {
    "Français": TranslateLanguage.french,
    "Anglais": TranslateLanguage.english,
    "Espagnol": TranslateLanguage.spanish,
    "Allemand": TranslateLanguage.german,
    "Italien": TranslateLanguage.italian,
    "Portugais": TranslateLanguage.portuguese,
  };

  // Dictionnaire pour la reconnaissance vocale (Interface -> Locale Android/iOS)
  final Map<String, String> _sttLocales = {
    "Français": "fr_FR",
    "Anglais": "en_US",
    "Espagnol": "es_ES",
    "Allemand": "de_DE",
    "Italien": "it_IT",
    "Portugais": "pt_PT",
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
      
      // Swap texts visually as well if translation exists
      if (_translatedText.isNotEmpty && !_translatedText.startsWith("Erreur")) {
         _inputController.text = _translatedText;
         _translatedText = "";
      }
    });
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    
    setState(() { _isTranslating = true; _translatedText = "Vérification des modèles linguistiques..."; });

    try {
      final source = _supportedLanguages[_sourceLang]!;
      final target = _supportedLanguages[_targetLang]!;
      
      setState(() => _translatedText = "Traduction en cours (ou téléchargement du modèle, patientez)...");
      
      final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
      final realTranslation = await translator.translateText(text);
      await translator.close();
      
      setState(() {
        _translatedText = realTranslation;
        _isTranslating = false;
      });

      await LocalDatabase.instance.insertTranslation(
        sourceLang: _sourceLang.substring(0, 2).toLowerCase(),
        targetLang: _targetLang.substring(0, 2).toLowerCase(),
        original: text,
        translated: realTranslation,
      );
      SyncService.syncTranslations();
    } catch (e, stackTrace) {
      setState(() {
        _translatedText = "Erreur: $e\n\nStack: ${stackTrace.toString().substring(0, (stackTrace.toString().length > 500) ? 500 : stackTrace.toString().length)}";
        _isTranslating = false;
      });
    }
  }

  void _startListening() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _inputController.text = val.recognizedWords;
          });
        },
        localeId: _sttLocales[_sourceLang] ?? "en_US",
      );
    }
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
    if (_inputController.text.isNotEmpty) {
      _translate();
    }
  }

  Widget _buildLanguageDropdown(String currentValue, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: currentValue,
      underline: const SizedBox(), // Masque la ligne par défaut
      icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      onChanged: onChanged,
      items: _supportedLanguages.keys.map((lang) {
        return DropdownMenuItem(value: lang, child: Text(lang));
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Traduction Offline', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.blueAccent),
            onPressed: () => SyncService.syncTranslations(),
          )
        ],
      ),
      body: Column(
        children: [
          // Language Bar with Dropdowns
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Center(
                    child: _buildLanguageDropdown(_sourceLang, (val) {
                      if (val != null) setState(() => _sourceLang = val);
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 28, color: Colors.grey),
                  onPressed: _swapLanguages,
                ),
                Expanded(
                  child: Center(
                    child: _buildLanguageDropdown(_targetLang, (val) {
                      if (val != null) setState(() => _targetLang = val);
                    }),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Input Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _inputController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: "Saisissez du texte ou maintenez le micro...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[400]),
                          ),
                          onSubmitted: (_) => _translate(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
                            onPressed: _isTranslating ? null : _translate,
                            child: _isTranslating 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.arrow_forward),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Result Card
                if (_translatedText.isNotEmpty)
                  Card(
                    elevation: 0,
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _translatedText,
                        style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                
                if (_isTranslating)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Center(child: Text("Traduction (ou téléchargement du modèle hors-ligne si 1ère fois)...", style: TextStyle(color: Colors.grey, fontSize: 12))),
                  )
              ],
            ),
          ),
          
          // Mic Button area
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 90 : 70,
                height: _isListening ? 90 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening ? Colors.redAccent : Colors.blueAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : Colors.blueAccent).withOpacity(0.4),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 10 : 2,
                    )
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 36),
              ),
            ),
          ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text("Je vous écoute...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            )
        ],
      ),
    );
  }
}
