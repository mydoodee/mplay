import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/song_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/app_logo.dart';

class PlaylistScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<SongProvider>(
        builder: (context, provider, child) {
          final currentPlaylist = provider.playlists.firstWhere(
            (p) => p.id == playlist.id,
            orElse: () => playlist,
          );
          final songs = currentPlaylist.songs;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.black,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF777777), size: 24),
                    onPressed: () {
                      _showDeleteConfirmation(context, provider, currentPlaylist.id);
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Hero(
                            tag: 'playlist_art_${currentPlaylist.id}',
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF1A1A1A),
                                image: songs.isNotEmpty && songs[0].thumbnail != "NA" && songs[0].thumbnail.isNotEmpty
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(songs[0].thumbnail),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2),
                                ],
                              ),
                              child: (songs.isEmpty || songs[0].thumbnail == "NA" || songs[0].thumbnail.isEmpty)
                                  ? const Center(child: AppLogo(size: 32, showText: false))
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentPlaylist.name,
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${songs.length} เพลง',
                                  style: const TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      if (songs.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                                  ),
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => provider.playAll(songs),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                                  label: const Text('เล่นทั้งหมด', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => provider.shuffleAll(songs),
                                icon: const Icon(Icons.shuffle_rounded, color: Color(0xFFCCCCCC), size: 20),
                                label: const Text('สุ่มเพลง', style: TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w600, fontSize: 14)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF333333)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      if (songs.isNotEmpty)
                        Row(
                          children: [
                            Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFFF15A24), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            const Text('เพลงทั้งหมด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFCCCCCC))),
                          ],
                        ),
                      if (songs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('ยังไม่มีเพลงในเพลย์ลิสต์นี้', style: TextStyle(color: Color(0xFF777777), fontSize: 14)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (songs.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      final isFavorite = provider.favorites.any((s) => s.id == song.id);
                      final isCustomPlaylist = currentPlaylist.id != -1;

                      return Dismissible(
                        key: Key('playlist_${currentPlaylist.id}_song_${song.id}'),
                        direction: isCustomPlaylist ? DismissDirection.endToStart : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: const Color(0xFFFF4466),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          provider.removeSongFromPlaylist(currentPlaylist.id, song.id);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: SongTile(
                            song: song,
                            isPlaying: provider.currentSong?.id == song.id,
                            isFavorite: isFavorite,
                            onFavoritePressed: () => provider.toggleFavorite(song),
                            onTap: () => provider.playSong(song, queue: songs, index: index),
                            onRemoveFromPlaylist: isCustomPlaylist 
                              ? () => provider.removeSongFromPlaylist(currentPlaylist.id, song.id) 
                              : null,
                          ),
                        ),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      bottomSheet: const MiniPlayer(),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SongProvider provider, int playlistId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบเพลย์ลิสต์', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบเพลย์ลิสต์นี้? เพลงที่อยู่ในนี้จะถูกนำออกจากเพลย์ลิสต์ด้วย', 
          style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF777777))),
          ),
          TextButton(
            onPressed: () {
              provider.deletePlaylist(playlistId);
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back home
            },
            child: const Text('ลบ', style: TextStyle(color: Color(0xFFFF4466))),
          ),
        ],
      ),
    );
  }
}
