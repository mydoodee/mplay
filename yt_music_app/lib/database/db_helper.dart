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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_local INTEGER DEFAULT 0,
        file_path TEXT
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
        played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_local INTEGER DEFAULT 0,
        file_path TEXT
      )
    ''');

    await _createPlaylistTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPlaylistTables(db);
    }
    if (oldVersion < 3) {
      // Add local music support columns to existing tables
      await db.execute('ALTER TABLE favorites ADD COLUMN is_local INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE favorites ADD COLUMN file_path TEXT');
      
      await db.execute('ALTER TABLE history ADD COLUMN is_local INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE history ADD COLUMN file_path TEXT');
      
      await db.execute('ALTER TABLE playlist_songs ADD COLUMN is_local INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE playlist_songs ADD COLUMN file_path TEXT');
    }
  }

  Future _createPlaylistTables(Database db) async {
    await db.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL,
        video_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        thumbnail TEXT,
        duration INTEGER,
        added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        is_local INTEGER DEFAULT 0,
        file_path TEXT,
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
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

  Future<int> removeFromHistory(String videoId) async {
    final db = await database;
    return await db.delete(
      'history',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  // ─── Playlists ───
  Future<int> createPlaylist(String name) async {
    final db = await database;
    return await db.insert('playlists', {'name': name});
  }

  Future<int> deletePlaylist(int id) async {
    final db = await database;
    // Manual cascade delete since foreign keys might be OFF by default
    await db.delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
    return await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    return await db.query('playlists', orderBy: 'created_at DESC');
  }

  Future<int> addSongToPlaylist(int playlistId, Song song) async {
    final db = await database;
    final map = song.toMap();
    map['playlist_id'] = playlistId;
    return await db.insert('playlist_songs', map);
  }

  Future<int> removeSongFromPlaylist(int playlistId, String videoId) async {
    final db = await database;
    return await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND video_id = ?',
      whereArgs: [playlistId, videoId],
    );
  }

  Future<List<Song>> getSongsForPlaylist(int playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'added_at DESC',
    );
    return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
  }
}
