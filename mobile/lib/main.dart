import 'package:flutter/material.dart';
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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent), useMaterial3: true),
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
  String _translatedText = "";
  bool _isTranslating = false;

  Future<void> _translate() async {
    final text = _inputController.text;
    if (text.isEmpty) return;
    setState(() { _isTranslating = true; });

    // ONNX Runtime Inference Mock
    await Future.delayed(const Duration(milliseconds: 300));
    final fakeTranslation = "[Traduit par ONNX]: $text";
    
    setState(() {
      _translatedText = fakeTranslation;
      _isTranslating = false;
    });

    await LocalDatabase.instance.insertTranslation(
      sourceLang: "fr", targetLang: "en", original: text, translated: fakeTranslation,
    );
    SyncService.syncTranslations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traducteur Offline'),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: () => SyncService.syncTranslations())
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _inputController, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _isTranslating ? null : _translate, child: const Text("Traduire")),
            const SizedBox(height: 32),
            Text(_translatedText, style: const TextStyle(fontSize: 18))
          ],
        ),
      ),
    );
  }
}
