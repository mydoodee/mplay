class ApiConfig {
  // 🌐 YouTube Music Server
  static const String _productionUrl = 'https://spicc.ac.th/api';

  static String get baseUrl {
    return _productionUrl;
  }

  // ค้นหาเพลง
  static String searchUrl(String query) =>
      '$baseUrl/search?q=${Uri.encodeComponent(query)}';

  // ดึงข้อมูลเพลง
  static String infoUrl(String videoId) => '$baseUrl/info/$videoId';

  // ✅ Stream audio ผ่าน Server
  // Server ทำการ resolve URL จาก YouTube และส่งต่อไป
  static String streamUrl(String videoId) => '$baseUrl/stream/$videoId';
}
