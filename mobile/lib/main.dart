import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'sync/sync_service.dart';
import 'services/image_translator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final ImageTranslator _imageTranslator = ImageTranslator();
  
  String _translatedText = "";
  bool _isTranslating = false;
  bool _isListening = false;
  bool _isProcessingImage = false;
  String? _ocrRectoText; // Text from front side (for recto-verso)
  
  String _sourceLang = "Français";
  String _targetLang = "Anglais";

  // Dictionnaire des langues supportées (Interface -> ML Kit)
  Map<String, TranslateLanguage> _supportedLanguages = {
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

  Future<bool> _promptDownload(String languageName) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Téléchargement Requis'),
        content: Text('Le modèle de traduction pour $languageName (~30 Mo) n\'est pas encore installé sur votre appareil.\n\nVoulez-vous le télécharger maintenant ?\nCela consommera des données internet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Télécharger', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    
    setState(() { _isTranslating = true; _translatedText = "Vérification des modèles linguistiques..."; });

    try {
      final source = _supportedLanguages[_sourceLang]!;
      final target = _supportedLanguages[_targetLang]!;

      final modelManager = OnDeviceTranslatorModelManager();
      
      final bool sourceDownloaded = await modelManager.isModelDownloaded(source.bcpCode);
      if (!sourceDownloaded) {
        bool confirm = await _promptDownload(_sourceLang);
        if (!confirm) {
          setState(() { _isTranslating = false; _translatedText = "Traduction annulée : modèle $_sourceLang manquant."; });
          return;
        }
        setState(() => _translatedText = "Téléchargement du modèle $_sourceLang en cours (~30 Mo)...");
        final s = await modelManager.downloadModel(source.bcpCode);
        if (!s) throw Exception("Impossible de télécharger le modèle $_sourceLang.");
      }
      
      final bool targetDownloaded = await modelManager.isModelDownloaded(target.bcpCode);
      if (!targetDownloaded) {
        bool confirm = await _promptDownload(_targetLang);
        if (!confirm) {
          setState(() { _isTranslating = false; _translatedText = "Traduction annulée : modèle $_targetLang manquant."; });
          return;
        }
        setState(() => _translatedText = "Téléchargement du modèle $_targetLang en cours (~30 Mo)...");
        final s = await modelManager.downloadModel(target.bcpCode);
        if (!s) throw Exception("Impossible de télécharger le modèle $_targetLang.");
      }

      setState(() => _translatedText = "Traduction en cours...");
      
      final translator = OnDeviceTranslator(sourceLanguage: source, targetLanguage: target);
      final realTranslation = await translator.translateText(text);
      await translator.close();
      
      setState(() {
        _translatedText = realTranslation;
        _isTranslating = false;
      });

      // Privacy-First: NO history saved, NO data retained
    } catch (e) {
      debugPrint("Translation error: $e");
      setState(() {
        _translatedText = "Translation failed. Please check your internet connection and try again.";
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
        listenOptions: stt.SpeechListenOptions(localeId: _sttLocales[_sourceLang] ?? "en_US"),
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

  /// Requests camera permission with a clear explanation dialog.
  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isDenied) {
      if (!mounted) return false;
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Caméra'),
          content: const Text(
            'L\'application a besoin d\'accéder à votre caméra pour photographier du texte et le traduire.\n\n'
            '📸 La photo est analysée localement puis supprimée immédiatement.\n'
            '🔒 Aucune image n\'est sauvegardée ni envoyée sur Internet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Refuser', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text('Autoriser', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldRequest) return false;
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caméra refusée. Activez-la dans les Paramètres de votre téléphone.')),
        );
      }
      return false;
    }

    return status.isGranted;
  }

  /// Captures a photo, runs OCR, and translates the extracted text.
  /// This is the "Recto" capture — front side of a document.
  Future<void> _captureAndTranslate() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;

    setState(() {
      _isProcessingImage = true;
      _translatedText = "Capture de la photo...";
      _ocrRectoText = null; // Reset recto-verso state
    });

    try {
      setState(() => _translatedText = "Extraction du texte (OCR)...");
      final extractedText = await _imageTranslator.captureAndExtract();

      if (extractedText == null) {
        setState(() {
          _isProcessingImage = false;
          _translatedText = "";
        });
        return; // User cancelled camera
      }

      // Store recto text for potential verso capture
      setState(() {
        _ocrRectoText = extractedText;
        _inputController.text = extractedText;
      });

      // Translate immediately
      await _translate();
    } catch (e) {
      debugPrint("Camera OCR error: $e");
      setState(() {
        _translatedText = "Erreur lors de l'extraction du texte. Veuillez réessayer.";
      });
    } finally {
      setState(() => _isProcessingImage = false);
    }
  }

  /// Captures the back side (verso) of a document, appends text to recto,
  /// and translates the combined text.
  Future<void> _captureVerso() async {
    setState(() {
      _isProcessingImage = true;
      _translatedText = "Capture du verso...";
    });

    try {
      final versoText = await _imageTranslator.captureAndExtract();

      if (versoText == null) {
        setState(() => _isProcessingImage = false);
        return; // User cancelled
      }

      // Combine recto + verso
      final combinedText = "${_ocrRectoText ?? ''}\n\n--- Verso ---\n\n$versoText";
      setState(() {
        _inputController.text = combinedText;
        _ocrRectoText = null; // Reset — verso captured, no more captures needed
      });

      // Translate the full combined text
      await _translate();
    } catch (e) {
      debugPrint("Verso OCR error: $e");
      setState(() {
        _translatedText = "Erreur lors de l'extraction du verso. Veuillez réessayer.";
      });
    } finally {
      setState(() => _isProcessingImage = false);
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
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mise à jour du catalogue des langues...'), duration: Duration(seconds: 1)));
              final newCatalog = await SyncService.fetchLanguageCatalog();
              if (!context.mounted) return;
              
              if (newCatalog != null && newCatalog.isNotEmpty) {
                setState(() {
                  _supportedLanguages = newCatalog;
                  if (!_supportedLanguages.containsKey(_sourceLang)) _sourceLang = _supportedLanguages.keys.first;
                  if (!_supportedLanguages.containsKey(_targetLang)) _targetLang = _supportedLanguages.keys.last;
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalogue mis à jour avec succès !')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur réseau ou catalogue indisponible.')));
              }
            },
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
                    color: Colors.blueAccent.withValues(alpha: 0.1),
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
          
          // Action Buttons Row (Mic + Camera)
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mic Button
                GestureDetector(
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
                          color: (_isListening ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.4),
                          blurRadius: _isListening ? 20 : 10,
                          spreadRadius: _isListening ? 10 : 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.mic, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(width: 30),
                // Camera Button
                GestureDetector(
                  onTap: _isProcessingImage ? null : _captureAndTranslate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isProcessingImage ? Colors.grey : Colors.deepOrange,
                      boxShadow: [
                        BoxShadow(
                          color: (_isProcessingImage ? Colors.grey : Colors.deepOrange).withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: _isProcessingImage
                        ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                  ),
                ),
              ],
            ),
          ),
          if (_isListening)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text("Je vous écoute...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          if (_ocrRectoText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flip),
                label: const Text('Capturer le Verso'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessingImage ? null : _captureVerso,
              ),
            )
        ],
      ),
    );
  }
}
