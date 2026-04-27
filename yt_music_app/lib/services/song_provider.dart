import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'api_service.dart';
import 'local_music_service.dart';
import '../database/db_helper.dart';
import '../main.dart'; // To access audioHandler

class SongProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DbHelper _dbHelper = DbHelper();
  final LocalMusicService _localMusicService = LocalMusicService();

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;

  bool _hasMoreResults = true;
  bool get hasMoreResults => _hasMoreResults;

  String _currentSearchQuery = '';
  final int _pageSize = 20;

  Song? _currentSong;
  Song? get currentSong => _currentSong;

  List<Song> _favorites = [];
  List<Song> get favorites => _favorites;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  List<Song> _history = [];
  List<Song> get history => _history;

  // Local Music State
  final List<Song> _localSongs = [];
  List<Song> get localSongs => _localSongs;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<String> _addedFolders = [];
  List<String> get addedFolders => _addedFolders;

  SongProvider() {
    // Initialize lazily or after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
      _loadPlaylists();
      _loadHistory();
      _initAudioListener();
    });
  }

  void _initAudioListener() {
    // Sync current song with audio handler
    audioHandler?.mediaItem.listen((item) async {
      if (item != null && item.id.isNotEmpty) {
        final isLocal = item.extras?['isLocal'] == true;
        final filePath = item.extras?['filePath'] as String?;
        
        Uint8List? coverArtBytes;
        if (isLocal && filePath != null) {
          // If the song is already in _localSongs, just use its coverArtBytes
          try {
             final existing = _localSongs.firstWhere((s) => s.id == item.id);
             coverArtBytes = existing.coverArtBytes;
          } catch (_) {
             // Extract on the fly if not in RAM (e.g. played from Playlist/History)
             coverArtBytes = await _localMusicService.extractCoverArt(filePath);
          }
        }

        Future.microtask(() {
          _currentSong = Song(
            id: item.id,
            title: item.title,
            artist: item.artist ?? '',
            thumbnail: item.artUri?.toString() ?? '',
            duration: item.duration?.inSeconds ?? 0,
            isLocal: isLocal,
            filePath: filePath,
            coverArtBytes: coverArtBytes,
          );
          notifyListeners();
        });
      }
    });
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _currentSearchQuery = query;
    _isLoading = true;
    _hasMoreResults = true;
    _searchResults = [];
    notifyListeners();

    final results = await _apiService.searchSongs(
      query,
      limit: _pageSize,
      offset: 0,
    );
    _searchResults = results;

    if (results.length < _pageSize) {
      _hasMoreResults = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> searchMore() async {
    if (_isFetchingMore || !_hasMoreResults || _currentSearchQuery.isEmpty) {
      return;
    }

    _isFetchingMore = true;
    notifyListeners();

    final currentOffset = _searchResults.length;
    final moreResults = await _apiService.searchSongs(
      _currentSearchQuery,
      limit: _pageSize,
      offset: currentOffset,
    );

    if (moreResults.isEmpty) {
      _hasMoreResults = false;
    } else {
      _searchResults.addAll(moreResults);
      if (moreResults.length < _pageSize) {
        _hasMoreResults = false;
      }
    }

    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0}) async {
    try {
      if (queue != null && queue.isNotEmpty) {
        await audioHandler?.setQueue(queue, initialIndex: index);
      } else {
        await audioHandler?.playSong(song);
      }
      
      // 🚀 ทำงานเบื้องหลัง ไม่ต้องรอ (Non-blocking)
      _dbHelper.addToHistory(song).then((_) => _loadHistory());
    } catch (e) {
      if (kDebugMode) {
        print('DB/Audio Error in playSong: $e');
      }
    }
  }

  Future<void> playAll(List<Song> songs, {int initialIndex = 0}) async {
    await audioHandler?.setQueue(songs, initialIndex: initialIndex);
    
    // 🚀 บันทึกประวัติแบบเบื้องหลัง
    Future.microtask(() async {
      for (var song in songs) {
        await _dbHelper.addToHistory(song);
      }
      await _loadHistory();
    });
  }

  Future<void> shuffleAll(List<Song> songs) async {
    final shuffled = List<Song>.from(songs)..shuffle();
    await playAll(shuffled);
    await audioHandler?.setShuffleMode(AudioServiceShuffleMode.all);
  }

  Future<void> playNext() async => audioHandler?.skipToNext();
  Future<void> playPrevious() async => audioHandler?.skipToPrevious();

  Future<void> _loadFavorites() async {
    final rawFavorites = await _dbHelper.getFavorites();
    final validFavorites = <Song>[];
    for (final song in rawFavorites) {
      if (song.id.startsWith('local_') && (song.filePath == null || song.filePath!.isEmpty)) {
        await _dbHelper.removeFavorite(song.id);
      } else {
        validFavorites.add(song);
      }
    }
    _favorites = validFavorites;
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final rawHistory = await _dbHelper.getHistory();
    final validHistory = <Song>[];
    for (final song in rawHistory) {
      if (song.id.startsWith('local_') && (song.filePath == null || song.filePath!.isEmpty)) {
        await _dbHelper.removeFromHistory(song.id);
      } else {
        validHistory.add(song);
      }
    }
    _history = validHistory;
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    final isFav = await _dbHelper.isFavorite(song.id);
    if (isFav) {
      await _dbHelper.removeFavorite(song.id);
    } else {
      await _dbHelper.addFavorite(song);
    }
    await _loadFavorites();
  }

  Future<bool> isFavorite(String videoId) async {
    return await _dbHelper.isFavorite(videoId);
  }

  // ─── Playlists ───

  Future<void> _loadPlaylists() async {
    final maps = await _dbHelper.getPlaylists();
    _playlists = maps.map((m) => Playlist.fromMap(m)).toList();
    for (var playlist in _playlists) {
      final rawSongs = await _dbHelper.getSongsForPlaylist(playlist.id);
      final validSongs = <Song>[];
      for (final song in rawSongs) {
        if (song.id.startsWith('local_') && (song.filePath == null || song.filePath!.isEmpty)) {
          await _dbHelper.removeSongFromPlaylist(playlist.id, song.id);
        } else {
          validSongs.add(song);
        }
      }
      playlist.songs = validSongs;
    }
    notifyListeners();
  }

  Future<void> createNewPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    await _dbHelper.createPlaylist(name.trim());
    await _loadPlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    await _dbHelper.deletePlaylist(id);
    await _loadPlaylists();
  }

  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    await _dbHelper.addSongToPlaylist(playlistId, song);
    await _loadPlaylists();
  }

  Future<void> removeSongFromPlaylist(int playlistId, String videoId) async {
    await _dbHelper.removeSongFromPlaylist(playlistId, videoId);
    await _loadPlaylists();
  }

  // ─── Local Music ───

  /// เพิ่มโฟลเดอร์เพลงจากเครื่อง / USB Drive
  Future<void> addLocalFolder() async {
    _isScanning = true;
    notifyListeners();

    try {
      final songs = await _localMusicService.pickFolderAndScan();
      if (songs.isNotEmpty) {
        // ลบเพลงซ้ำ (เช็คจาก filePath)
        for (final song in songs) {
          final exists = _localSongs.any((s) => s.filePath == song.filePath);
          if (!exists) {
            _localSongs.add(song);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding local folder: $e');
      }
    }

    _isScanning = false;
    notifyListeners();
  }

  /// เพิ่มไฟล์เพลงจากเครื่อง
  Future<void> addLocalFiles() async {
    _isScanning = true;
    notifyListeners();

    try {
      final songs = await _localMusicService.pickFiles();
      if (songs.isNotEmpty) {
        for (final song in songs) {
          final exists = _localSongs.any((s) => s.filePath == song.filePath);
          if (!exists) {
            _localSongs.add(song);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding local files: $e');
      }
    }

    _isScanning = false;
    notifyListeners();
  }

  /// ลบเพลง local ออกจากรายการ
  void removeLocalSong(Song song) {
    _localSongs.removeWhere((s) => s.filePath == song.filePath);
    notifyListeners();
  }

  /// ลบเพลง local ทั้งหมด
  void clearLocalSongs() {
    _localSongs.clear();
    notifyListeners();
  }
}
