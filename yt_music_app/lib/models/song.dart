class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final int duration;

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
