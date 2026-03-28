import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  factory DbHelper() => _instance;

  DbHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'yt_music.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    // Favorites table
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        thumbnail TEXT,
        duration INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // History table
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        thumbnail TEXT,
        duration INTEGER,
        played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // ─── Favorites ───
  Future<int> addFavorite(Song song) async {
    final db = await database;
    return await db.insert(
      'favorites',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> removeFavorite(String videoId) async {
    final db = await database;
    return await db.delete(
      'favorites',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  Future<List<Song>> getFavorites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorites', orderBy: 'created_at DESC');
    return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
  }

  Future<bool> isFavorite(String videoId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
    return maps.isNotEmpty;
  }

  // ─── History ───
  Future<void> addToHistory(Song song) async {
    final db = await database;
    // Remove if exists to move to top
    await db.delete('history', where: 'video_id = ?', whereArgs: [song.id]);
    await db.insert('history', song.toMap());
  }

  Future<List<Song>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('history', orderBy: 'played_at DESC', limit: 50);
    return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
  }
}
