import 'song.dart';

class Playlist {
  final int id;
  final String name;
  final String createdAt;
  List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.songs = const [],
  });

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] ?? 0,
      name: map['name'] ?? 'Unnamed',
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }
}
