import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class PlaybackStateService {
  static const String _keyLastSong = 'last_played_song';
  static const String _keyLastPosition = 'last_played_position';
  static const String _keyLastQueue = 'last_played_queue';
  static const String _keyLastQueueIndex = 'last_played_queue_index';

  static Future<void> savePlaybackState({
    required Song song,
    required int position,
    required List<Song> queue,
    required int queueIndex,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSong, jsonEncode(song.toMap()));
      await prefs.setInt(_keyLastPosition, position);
      
      final queueMaps = queue.map((s) => s.toMap()).toList();
      await prefs.setString(_keyLastQueue, jsonEncode(queueMaps));
      await prefs.setInt(_keyLastQueueIndex, queueIndex);
      if (kDebugMode) {
        print('💾 PlaybackStateService: Saved playback state - song: ${song.title}, position: $position, queueIndex: $queueIndex');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaybackStateService: Error saving state: $e');
      }
    }
  }

  static Future<Map<String, dynamic>?> loadPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final songJson = prefs.getString(_keyLastSong);
      if (songJson == null) return null;

      final songMap = jsonDecode(songJson) as Map<String, dynamic>;
      final song = Song.fromMap(songMap);

      final position = prefs.getInt(_keyLastPosition) ?? 0;
      final queueIndex = prefs.getInt(_keyLastQueueIndex) ?? 0;
      
      final queueJson = prefs.getString(_keyLastQueue);
      List<Song> queue = [];
      if (queueJson != null) {
        final queueList = jsonDecode(queueJson) as List<dynamic>;
        queue = queueList
            .map((item) => Song.fromMap(item as Map<String, dynamic>))
            .toList();
      }

      return {
        'song': song,
        'position': position,
        'queue': queue,
        'queueIndex': queueIndex,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaybackStateService: Error loading state: $e');
      }
      return null;
    }
  }

  static Future<void> clearPlaybackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastSong);
      await prefs.remove(_keyLastPosition);
      await prefs.remove(_keyLastQueue);
      await prefs.remove(_keyLastQueueIndex);
      if (kDebugMode) {
        print('🧹 PlaybackStateService: Cleared playback state');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PlaybackStateService: Error clearing state: $e');
      }
    }
  }
}
