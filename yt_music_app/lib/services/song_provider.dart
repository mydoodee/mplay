import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'api_service.dart';
import '../database/db_helper.dart';
import '../main.dart'; // To access audioHandler

class SongProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DbHelper _dbHelper = DbHelper();
  
  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Song? _currentSong;
  Song? get currentSong => _currentSong;

  List<Song> _favorites = [];
  List<Song> get favorites => _favorites;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  SongProvider() {
    // Initialize lazily or after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
      _loadPlaylists();
      _initAudioListener();
    });
  }

  void _initAudioListener() {
    // Sync current song with audio handler
    audioHandler?.mediaItem.listen((item) {
      if (item != null && item.id.isNotEmpty) {
        Future.microtask(() {
          _currentSong = Song(
            id: item.id,
            title: item.title,
            artist: item.artist ?? '',
            thumbnail: item.artUri?.toString() ?? '',
            duration: item.duration?.inSeconds ?? 0,
          );
          notifyListeners();
        });
      }
    });
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _isLoading = true;
    _searchResults = [];
    notifyListeners();
    
    _searchResults = await _apiService.searchSongs(query);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? queue, int index = 0}) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (queue != null && queue.isNotEmpty) {
        await audioHandler?.setQueue(queue, initialIndex: index);
      } else {
        await audioHandler?.playSong(song);
      }
      await _dbHelper.addToHistory(song);
    } catch (e) {
      print('DB/Audio Error in playSong: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> playAll(List<Song> songs, {int initialIndex = 0}) async {
    await audioHandler?.setQueue(songs, initialIndex: initialIndex);
    for (var song in songs) {
       await _dbHelper.addToHistory(song);
    }
  }

  Future<void> shuffleAll(List<Song> songs) async {
    final shuffled = List<Song>.from(songs)..shuffle();
    await playAll(shuffled);
    await audioHandler?.setShuffleMode(AudioServiceShuffleMode.all);
  }

  Future<void> playNext() async => audioHandler?.skipToNext();
  Future<void> playPrevious() async => audioHandler?.skipToPrevious();

  Future<void> _loadFavorites() async {
    _favorites = await _dbHelper.getFavorites();
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
      playlist.songs = await _dbHelper.getSongsForPlaylist(playlist.id);
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
}
