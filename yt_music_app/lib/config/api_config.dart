class ApiConfig {
  // 🌐 Production Server
  static const String _productionUrl = 'https://spicc.ac.th/api';

  static String get baseUrl {
    return _productionUrl;
  }

  static String searchUrl(String query) => '$baseUrl/search?q=${Uri.encodeComponent(query)}';
  static String streamUrl(String videoId) => '$baseUrl/stream/$videoId';
  static String infoUrl(String videoId) => '$baseUrl/info/$videoId';
  static String audioUrl(String videoId) => '$baseUrl/audio-url/$videoId';
}
