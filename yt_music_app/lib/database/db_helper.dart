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
      version: 7,
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
        is_live INTEGER DEFAULT 0,
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
        is_live INTEGER DEFAULT 0,
        file_path TEXT
      )
    ''');

    await _createPlaylistTables(db);
    await _createLocalSongsTable(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createPlaylistTables(db);
    }
    if (oldVersion < 3) {
      await _addColumnIfNotExists(db, 'favorites', 'is_local', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'favorites', 'file_path', 'TEXT');
      await _addColumnIfNotExists(db, 'history', 'is_local', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'history', 'file_path', 'TEXT');
      await _addColumnIfNotExists(db, 'playlist_songs', 'is_local', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'playlist_songs', 'file_path', 'TEXT');
    }
    if (oldVersion < 4) {
      await _createLocalSongsTable(db);
    }
    if (oldVersion < 5) {
      await _addColumnIfNotExists(db, 'playlist_songs', 'added_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
      await _addColumnIfNotExists(db, 'favorites', 'created_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
      await _addColumnIfNotExists(db, 'history', 'played_at', 'TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
    }
    if (oldVersion < 6) {
      // เพิ่ม is_live column สำหรับรองรับ Live Stream
      await _addColumnIfNotExists(db, 'history', 'is_live', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'favorites', 'is_live', 'INTEGER DEFAULT 0');
      await _addColumnIfNotExists(db, 'playlist_songs', 'is_live', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 7) {
      // แก้ไขบั๊กสำหรับคนที่ล้างแอป/ลงใหม่ตอนเป็น v6 แล้วตาราง playlist_songs ขาดคอลัมน์ is_live
      await _addColumnIfNotExists(db, 'playlist_songs', 'is_live', 'INTEGER DEFAULT 0');
    }
  }

  Future<void> _addColumnIfNotExists(Database db, String tableName, String columnName, String columnType) async {
    try {
      var columns = await db.rawQuery('PRAGMA table_info($tableName)');
      bool exists = columns.any((column) => column['name'] == columnName);
      if (!exists) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
      }
    } catch (e) {
      print('Error adding column $columnName to $tableName: $e');
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
        is_live INTEGER DEFAULT 0,
        file_path TEXT,
        FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── Favorites ───
  Future<int> addFavorite(Song song) async {
    try {
      final db = await database;
      return await db.insert(
        'favorites',
        song.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('DB Error addFavorite: $e');
      return -1;
    }
  }

  Future<int> removeFavorite(String videoId) async {
    try {
      final db = await database;
      return await db.delete(
        'favorites',
        where: 'video_id = ?',
        whereArgs: [videoId],
      );
    } catch (e) {
      print('DB Error removeFavorite: $e');
      return -1;
    }
  }

  Future<List<Song>> getFavorites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('favorites', orderBy: 'created_at DESC');
      return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
    } catch (e) {
      print('DB Error getFavorites: $e');
      return [];
    }
  }

  Future<bool> isFavorite(String videoId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'favorites',
        where: 'video_id = ?',
        whereArgs: [videoId],
      );
      return maps.isNotEmpty;
    } catch (e) {
      print('DB Error isFavorite: $e');
      return false;
    }
  }

  // ─── History ───
  Future<void> addToHistory(Song song) async {
    try {
      final db = await database;
      // Remove if exists to move to top
      await db.delete('history', where: 'video_id = ?', whereArgs: [song.id]);
      await db.insert('history', song.toMap());
    } catch (e) {
      print('DB Error addToHistory: $e');
    }
  }

  Future<List<Song>> getHistory() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('history', orderBy: 'played_at DESC', limit: 50);
      return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
    } catch (e) {
      print('DB Error getHistory: $e');
      return [];
    }
  }

  Future<int> removeFromHistory(String videoId) async {
    try {
      final db = await database;
      return await db.delete(
        'history',
        where: 'video_id = ?',
        whereArgs: [videoId],
      );
    } catch (e) {
      print('DB Error removeFromHistory: $e');
      return -1;
    }
  }

  Future<int> clearHistory() async {
    try {
      final db = await database;
      return await db.delete('history');
    } catch (e) {
      print('DB Error clearHistory: $e');
      return -1;
    }
  }

  // ─── Playlists ───
  Future<int> createPlaylist(String name) async {
    try {
      final db = await database;
      return await db.insert('playlists', {'name': name});
    } catch (e) {
      print('DB Error createPlaylist: $e');
      return -1;
    }
  }

  Future<int> deletePlaylist(int id) async {
    try {
      final db = await database;
      // Manual cascade delete since foreign keys might be OFF by default
      await db
          .delete('playlist_songs', where: 'playlist_id = ?', whereArgs: [id]);
      return await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('DB Error deletePlaylist: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    try {
      final db = await database;
      return await db.query('playlists', orderBy: 'created_at DESC');
    } catch (e) {
      print('DB Error getPlaylists: $e');
      return [];
    }
  }

  Future<int> addSongToPlaylist(int playlistId, Song song) async {
    try {
      final db = await database;
      final map = song.toMap();
      map['playlist_id'] = playlistId;
      return await db.insert('playlist_songs', map);
    } catch (e) {
      print('DB Error addSongToPlaylist: $e');
      return -1;
    }
  }

  Future<int> removeSongFromPlaylist(int playlistId, String videoId) async {
    try {
      final db = await database;
      return await db.delete(
        'playlist_songs',
        where: 'playlist_id = ? AND video_id = ?',
        whereArgs: [playlistId, videoId],
      );
    } catch (e) {
      print('DB Error removeSongFromPlaylist: $e');
      return -1;
    }
  }

  Future<List<Song>> getSongsForPlaylist(int playlistId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'added_at DESC',
      );
      return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
    } catch (e) {
      print('DB Error getSongsForPlaylist: $e');
      return [];
    }
  }

  // ─── Local Songs (Persistent) ───

  Future _createLocalSongsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        video_id TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        thumbnail TEXT,
        duration INTEGER,
        is_local INTEGER DEFAULT 1,
        file_path TEXT NOT NULL,
        added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<int> addLocalSong(Song song) async {
    final db = await database;
    final map = song.toMap();
    return await db.insert(
      'local_songs',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Song>> getLocalSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_songs',
      orderBy: 'added_at DESC',
    );
    return List.generate(maps.length, (i) => Song.fromMap(maps[i]));
  }

  Future<int> removeLocalSong(String videoId) async {
    final db = await database;
    return await db.delete(
      'local_songs',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  Future<int> clearLocalSongs() async {
    final db = await database;
    return await db.delete('local_songs');
  }
}
