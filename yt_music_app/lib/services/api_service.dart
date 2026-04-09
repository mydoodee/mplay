import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../config/api_config.dart';

class ApiService {
  // 🎵 Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  // ⏱️ Timeout settings
  static const Duration _searchTimeout = Duration(seconds: 20);
  static const Duration _infoTimeout = Duration(seconds: 15);

  Future<List<Song>> searchSongs(String query, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.searchUrl(query, limit: limit, offset: offset)))
          .timeout(_searchTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final List<dynamic> results = data['results'] ?? [];
        return results.map((json) => Song.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load songs: ${response.statusCode}');
      }
    } on TimeoutException {
      print('ApiService Error (Search): Timeout');
      return [];
    } catch (e) {
      print('ApiService Error (Search): $e');
      return [];
    }
  }

  Future<Song?> getSongInfo(String videoId) async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.infoUrl(videoId)))
          .timeout(_infoTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        return Song.fromJson(data);
      } else {
        throw Exception('Failed to load song info: ${response.statusCode}');
      }
    } on TimeoutException {
      print('ApiService Error (Info): Timeout');
      return null;
    } catch (e) {
      print('ApiService Error (Info): $e');
      return null;
    }
  }
}
