class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final int duration;

  // Always returns a valid YouTube thumbnail URL (16:9, for lists)
  String get thumbnailUrl {
    if (thumbnail.isNotEmpty && thumbnail != 'NA' && thumbnail.startsWith('http')) {
      return thumbnail;
    }
    return 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
  }

  // High-quality thumbnail for player screen (hqdefault = 480×360)
  String get hqThumbnailUrl {
    if (thumbnail.isNotEmpty && thumbnail != 'NA' && thumbnail.startsWith('http') && !thumbnail.contains('ytimg.com')) {
      return thumbnail;
    }
    return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  }

  // Standard-definition thumbnail (640×480)
  String get sdThumbnailUrl {
    return 'https://i.ytimg.com/vi/$id/sddefault.jpg';
  }

  // Maximum resolution thumbnail (1280×720)
  String get maxResThumbnailUrl {
    return 'https://i.ytimg.com/vi/$id/maxresdefault.jpg';
  }

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      thumbnail: json['thumbnail'] ?? '',
      duration: json['duration'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'thumbnail': thumbnail,
      'duration': duration,
    };
  }

  // Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'video_id': id,
      'title': title,
      'artist': artist,
      'thumbnail': thumbnail,
      'duration': duration,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['video_id'] ?? '',
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      thumbnail: map['thumbnail'] ?? '',
      duration: map['duration'] ?? 0,
    );
  }
}
