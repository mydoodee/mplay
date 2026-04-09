import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../config/api_config.dart';

class ApiService {
  // 🎵 Singleton pattern — ใช้ client เดียวกันตลอดเพื่อ connection pooling
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  
  // ⏱️ Timeout settings
  static const Duration _searchTimeout = Duration(seconds: 20);
  static const Duration _urlTimeout = Duration(seconds: 15);
  static const Duration _infoTimeout = Duration(seconds: 15);

  Future<List<Song>> searchSongs(String query, {int limit = 20, int offset = 0}) async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.searchUrl(query, limit: limit, offset: offset)))
          .timeout(_searchTimeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
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

  /// 🎵 Get direct audio URL with retry
  /// ลอง 2 ครั้ง เพื่อให้ได้ URL แน่ๆ
  Future<String?> getAudioUrl(String videoId) async {
    // Attempt 1
    String? url = await _fetchAudioUrl(videoId);
    if (url != null) return url;
    
    // Attempt 2 — retry once
    print('🔄 Retrying audio URL for: $videoId');
    await Future.delayed(const Duration(milliseconds: 500));
    url = await _fetchAudioUrl(videoId);
    return url;
  }

  Future<String?> _fetchAudioUrl(String videoId) async {
    try {
      final response = await _client
          .get(Uri.parse(ApiConfig.audioUrl(videoId)))
          .timeout(_urlTimeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return url;
        }
      }
      return null;
    } on TimeoutException {
      print('ApiService Error (URL): Timeout for $videoId');
      return null;
    } catch (e) {
      print('ApiService Error (URL): $e');
      return null;
    }
  }

  /// 📦 Batch pre-resolve URLs for queue
  Future<Map<String, String?>> batchResolveUrls(List<String> videoIds) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/audio-urls'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'videoIds': videoIds}),
          )
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> urls = data['urls'] ?? {};
        return urls.map((key, value) => MapEntry(key, value as String?));
      }
      return {};
    } catch (e) {
      print('ApiService Error (Batch): $e');
      return {};
    }
  }
}
