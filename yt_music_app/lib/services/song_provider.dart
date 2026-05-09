import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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
  List<String> _suggestions = [];
  List<String> get suggestions => _suggestions;

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

  // Download State
  final Map<String, double> _downloadProgress = {}; // videoId → 0.0-1.0
  Map<String, double> get downloadProgress => Map.unmodifiable(_downloadProgress);
  final Set<String> _downloadingIds = {};

  SongProvider() {
    // Initialize lazily or after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
      _loadPlaylists();
      _loadHistory();
      _loadLocalSongs();
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
    _suggestions = []; // Clear suggestions when searching
    notifyListeners();
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

  /// ล้างผลการค้นหา
  void clearSearch() {
    _searchResults = [];
    _currentSearchQuery = '';
    _hasMoreResults = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> searchMore() async {
    if (_isFetchingMore || !_hasMoreResults || _currentSearchQuery.isEmpty) {
      return;
    }

    _isFetchingMore = true;
    notifyListeners();

    try {
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
    } catch (e) {
      if (kDebugMode) {
        print('Error in searchMore: $e');
      }
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }
    final suggestions = await _apiService.getSearchSuggestions(query);
    _suggestions = suggestions;
    notifyListeners();
  }

  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0}) async {
    try {
      if (queue != null && queue.isNotEmpty) {
        // หา index จาก song.id เพื่อป้องกันกรณีที่ index ผิดหรือ indexOf คืน -1
        final resolvedIndex = index >= 0 && index < queue.length
            ? index
            : queue.indexWhere((s) => s.id == song.id);
        final safeIndex = resolvedIndex >= 0 ? resolvedIndex : 0;
        await audioHandler?.setQueue(queue, initialIndex: safeIndex);
      } else {
        await audioHandler?.playSong(song);
      }

      // 🚀 อัปเดต history ใน DB แบบ background
      // แต่ถ้าเพลงนี้มีอยู่ใน list แล้ว ให้คงลำดับเดิมไว้ ไม่ reload ใหม่
      // เพื่อไม่ให้เพลงที่เล่นเด้งขึ้นบนสุด
      _dbHelper.addToHistory(song).then((_) {
        final alreadyInHistory = _history.any((s) => s.id == song.id);
        if (!alreadyInHistory) {
          // เพลงใหม่ที่ไม่เคยเล่นมาก่อน → reload เพื่อเพิ่มขึ้นบนสุด
          _loadHistory();
        }
        // เพลงที่มีอยู่แล้ว → ไม่ต้อง reload เพราะ isPlaying จะอัปเดตผ่าน audioHandler listener อยู่แล้ว
      });
    } catch (e) {
      if (kDebugMode) {
        print('DB/Audio Error in playSong: $e');
      }
    }
  }

  Future<void> playAll(List<Song> songs, {int initialIndex = 0}) async {
    await audioHandler?.setQueue(songs, initialIndex: initialIndex);

    // 🚀 บันทึกประวัติเฉพาะเพลงที่เล่นจริง (ไม่บันทึกทั้ง queue เพื่อประหยัด DB I/O)
    Future.microtask(() async {
      if (songs.isNotEmpty && initialIndex < songs.length) {
        await _dbHelper.addToHistory(songs[initialIndex]);
        final alreadyInHistory = _history.any((s) => s.id == songs[initialIndex].id);
        if (!alreadyInHistory) {
          await _loadHistory();
        }
      }
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
    try {
      final rawFavorites = await _dbHelper.getFavorites();
      final validFavorites = <Song>[];
      for (final song in rawFavorites) {
        if (song.id.startsWith('local_') &&
            (song.filePath == null || song.filePath!.isEmpty)) {
          await _dbHelper.removeFavorite(song.id);
        } else {
          // โหลด cover art สำหรับเพลง local ใน favorites
          validFavorites.add(await _withCoverArt(song));
        }
      }
      _favorites = validFavorites;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading favorites: $e');
    }
  }

  Future<void> _loadHistory() async {
    try {
      final rawHistory = await _dbHelper.getHistory();
      final validHistory = <Song>[];
      for (final song in rawHistory) {
        if (song.id.startsWith('local_') &&
            (song.filePath == null || song.filePath!.isEmpty)) {
          await _dbHelper.removeFromHistory(song.id);
        } else {
          validHistory.add(await _withCoverArt(song));
        }
      }
      _history = validHistory;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading history: $e');
    }
  }

  /// โหลด coverArtBytes จากไฟล์ถ้าเป็นเพลง local
  Future<Song> _withCoverArt(Song song) async {
    if (!song.isLocal || song.filePath == null || song.coverArtBytes != null) {
      return song;
    }
    try {
      final bytes = await _localMusicService.extractCoverArt(song.filePath!);
      if (bytes != null && bytes.isNotEmpty) {
        return Song(
          id: song.id,
          title: song.title,
          artist: song.artist,
          thumbnail: song.thumbnail,
          duration: song.duration,
          isLocal: song.isLocal,
          filePath: song.filePath,
          coverArtBytes: bytes,
        );
      }
    } catch (_) {}
    return song;
  }

  Future<void> toggleFavorite(Song song) async {
    try {
      final isFav = await _dbHelper.isFavorite(song.id);
      if (isFav) {
        await _dbHelper.removeFavorite(song.id);
      } else {
        await _dbHelper.addFavorite(song);
      }
      await _loadFavorites();
    } catch (e) {
      if (kDebugMode) print('Error toggling favorite: $e');
    }
  }

  Future<bool> isFavorite(String videoId) async {
    return await _dbHelper.isFavorite(videoId);
  }

  // ─── Playlists ───

  Future<void> _loadPlaylists() async {
    try {
      final maps = await _dbHelper.getPlaylists();
      _playlists = maps.map((m) => Playlist.fromMap(m)).toList();
      for (var playlist in _playlists) {
        final rawSongs = await _dbHelper.getSongsForPlaylist(playlist.id);
        final validSongs = <Song>[];
        for (final song in rawSongs) {
          if (song.id.startsWith('local_') &&
              (song.filePath == null || song.filePath!.isEmpty)) {
            await _dbHelper.removeSongFromPlaylist(playlist.id, song.id);
          } else {
            // โหลด cover art สำหรับเพลง local ใน playlists
            validSongs.add(await _withCoverArt(song));
          }
        }
        playlist.songs = validSongs;
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading playlists: $e');
    }
  }

  Future<void> createNewPlaylist(String name) async {
    try {
      if (name.trim().isEmpty) return;
      await _dbHelper.createPlaylist(name.trim());
      await _loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error creating playlist: $e');
    }
  }

  Future<void> deletePlaylist(int id) async {
    try {
      await _dbHelper.deletePlaylist(id);
      await _loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error deleting playlist: $e');
    }
  }

  Future<void> addSongToPlaylist(int playlistId, Song song) async {
    try {
      await _dbHelper.addSongToPlaylist(playlistId, song);
      await _loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error adding song to playlist: $e');
    }
  }

  Future<void> removeSongFromPlaylist(int playlistId, String videoId) async {
    try {
      await _dbHelper.removeSongFromPlaylist(playlistId, videoId);
      await _loadPlaylists();
    } catch (e) {
      if (kDebugMode) print('Error removing song from playlist: $e');
    }
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
            await _dbHelper.addLocalSong(song);
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
            await _dbHelper.addLocalSong(song);
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
    _dbHelper.removeLocalSong(song.id);
    notifyListeners();
  }

  /// ลบเพลง local ทั้งหมด
  void clearLocalSongs() {
    _localSongs.clear();
    _dbHelper.clearLocalSongs();
    notifyListeners();
  }

  /// โหลดเพลง local จาก DB พร้อม cover art
  Future<void> _loadLocalSongs() async {
    final songs = await _dbHelper.getLocalSongs();
    _localSongs.clear();
    for (final song in songs) {
      _localSongs.add(await _withCoverArt(song));
    }
    notifyListeners();
  }

  /// ลบประวัติการเล่นเพลงทั้งหมด
  Future<void> clearHistory() async {
    await _dbHelper.clearHistory();
    _history.clear();
    notifyListeners();
  }

  /// ลบเพลงออกจากประวัติ
  Future<void> removeFromHistory(Song song) async {
    await _dbHelper.removeFromHistory(song.id);
    _history.removeWhere((s) => s.id == song.id);
    notifyListeners();
  }

  // ─── Download ───

  /// ตรวจสอบว่าเพลงนี้ download แล้วหรือยัง
  bool isDownloaded(String videoId) {
    return _localSongs.any((s) =>
        s.filePath != null && s.filePath!.contains(videoId));
  }

  /// ตรวจสอบว่ากำลัง download อยู่หรือไม่
  bool isDownloading(String videoId) {
    return _downloadingIds.contains(videoId);
  }

  /// ดาวน์โหลดเพลงจาก YouTube แล้วบันทึกเป็นไฟล์ local
  Future<bool> downloadSong(Song song) async {
    if (song.isLocal) return false;
    if (isDownloaded(song.id)) return false;
    if (_downloadingIds.contains(song.id)) return false;

    _downloadingIds.add(song.id);
    _downloadProgress[song.id] = 0.0;
    notifyListeners();

    try {
      // 1. ดึง direct audio URL จาก Server
      final audioUrl = await _apiService.getAudioUrl(song.id);
      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('ไม่สามารถดึง URL เพลงได้');
      }

      // 2. เตรียม path สำหรับบันทึกไฟล์ → Download/Mplay
      Directory downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download/Mplay');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${dir.path}/Mplay');
      }
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // ใช้ชื่อไฟล์จาก title (ลบอักขระพิเศษออก) + .m4a
      final safeTitle = song.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '${downloadDir.path}/$safeTitle.m4a';

      // 3. ดาวน์โหลดไฟล์ด้วย Dio (throttle progress เพื่อไม่ให้ UI กระตุก)
      final dio = Dio();
      DateTime lastNotify = DateTime.now();
      await dio.download(
        audioUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress[song.id] = received / total;
            // อัปเดต UI ไม่เกิน 2 ครั้ง/วินาที เพื่อประหยัด CPU
            final now = DateTime.now();
            if (now.difference(lastNotify).inMilliseconds > 500 ||
                received == total) {
              lastNotify = now;
              notifyListeners();
            }
          }
        },
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0'},
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // 4. ตรวจสอบว่าไฟล์ถูกบันทึกสำเร็จ
      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('ไฟล์ download ไม่สมบูรณ์');
      }

      // 5. สร้าง Song object สำหรับ local file
      final localSong = Song.fromLocalFile(
        filePath: filePath,
        title: song.title,
        artist: song.artist,
        duration: song.duration,
      );

      // 6. บันทึกเข้า local_songs DB + RAM list
      final exists = _localSongs.any((s) => s.filePath == filePath);
      if (!exists) {
        _localSongs.insert(0, await _withCoverArt(localSong));
        await _dbHelper.addLocalSong(localSong);
      }

      _downloadProgress[song.id] = 1.0;
      _downloadingIds.remove(song.id);
      notifyListeners();

      if (kDebugMode) print('✅ Downloaded: ${song.title} → $filePath');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Download failed for ${song.title}: $e');
      _downloadProgress.remove(song.id);
      _downloadingIds.remove(song.id);
      notifyListeners();
      return false;
    }
  }
}
