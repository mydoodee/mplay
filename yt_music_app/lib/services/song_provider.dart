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
    _currentSearchQuery = query;
    _isLoading = true;
    _hasMoreResults = true;
    _searchResults = [];
    notifyListeners();
    
    final results = await _apiService.searchSongs(query, limit: _pageSize, offset: 0);
    _searchResults = results;
    
    if (results.length < _pageSize) {
      _hasMoreResults = false;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> searchMore() async {
    if (_isFetchingMore || !_hasMoreResults || _currentSearchQuery.isEmpty) return;
    
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
      await _dbHelper.addToHistory(song);
      await _loadHistory(); // Refresh history
    } catch (e) {
      print('DB/Audio Error in playSong: $e');
    }
  }

  Future<void> playAll(List<Song> songs, {int initialIndex = 0}) async {
    await audioHandler?.setQueue(songs, initialIndex: initialIndex);
    for (var song in songs) {
       await _dbHelper.addToHistory(song);
    }
    await _loadHistory();
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

  Future<void> _loadHistory() async {
    _history = await _dbHelper.getHistory();
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
