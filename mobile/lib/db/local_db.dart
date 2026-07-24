import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('translator_history.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    return await openDatabase(join(dbPath, filePath), version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sourceLang TEXT NOT NULL,
        targetLang TEXT NOT NULL,
        original TEXT NOT NULL,
        translated TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertTranslation({required String sourceLang, required String targetLang, required String original, required String translated}) async {
    final db = await instance.database;
    await db.insert('history', {
      'sourceLang': sourceLang, 'targetLang': targetLang, 'original': original, 'translated': translated,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

