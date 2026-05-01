import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/song_provider.dart';
import '../widgets/song_tile.dart';
import '../widgets/app_logo.dart';
import '../widgets/mini_player.dart';
import '../utils/responsive.dart';

class PlaylistScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Consumer<SongProvider>(
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
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFF777777),
                          size: 24,
                        ),
                        onPressed: () {
                          _showDeleteConfirmation(
                            context,
                            provider,
                            currentPlaylist.id,
                          );
                        },
                      ),
                    ],
                  ),
                  
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: Responsive.contentMaxWidth(context),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.hPadding(context),
                            vertical: 8.0,
                          ),
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
                                      width: Responsive.isTablet(context) ? 140 : 80,
                                      height: Responsive.isTablet(context) ? 140 : 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: const Color(0xFF1A1A1A),
                                        image: songs.isNotEmpty &&
                                                songs[0].thumbnail != "NA" &&
                                                songs[0].thumbnail.isNotEmpty
                                            ? DecorationImage(
                                                image: CachedNetworkImageProvider(songs[0].thumbnail),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: (songs.isEmpty ||
                                              songs[0].thumbnail == "NA" ||
                                              songs[0].thumbnail.isEmpty)
                                          ? Center(
                                              child: AppLogo(
                                                size: Responsive.isTablet(context) ? 56 : 32,
                                                showText: false,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentPlaylist.name,
                                          style: TextStyle(
                                            fontSize: Responsive.isTablet(context) ? 32 : 24,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${songs.length} เพลงในรายการ • สร้างเพื่อคุณ',
                                          style: TextStyle(
                                            color: const Color(0xFF888888),
                                            fontSize: Responsive.isTablet(context) ? 15 : 13,
                                            fontWeight: FontWeight.w400,
                                          ),
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
                                        height: Responsive.isTablet(context) ? 54 : 48,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () => provider.playAll(songs),
                                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                                          label: const Text('เล่นทั้งหมด', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SizedBox(
                                        height: Responsive.isTablet(context) ? 54 : 48,
                                        child: OutlinedButton.icon(
                                          onPressed: () => provider.shuffleAll(songs),
                                          icon: const Icon(Icons.shuffle_rounded, color: Color(0xFFCCCCCC), size: 22),
                                          label: const Text('สุ่มเพลง', style: TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w700)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF333333), width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              if (songs.isNotEmpty)
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF15A24),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'เพลงทั้งหมด',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFCCCCCC)),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  if (songs.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final song = songs[index];
                        final isFavorite = provider.favorites.any((s) => s.id == song.id);
                        final isCurrent = provider.currentSong?.id == song.id;
                        final isCustomPlaylist = currentPlaylist.id != -1;

                        return Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth(context)),
                            child: Dismissible(
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
                                padding: EdgeInsets.symmetric(horizontal: Responsive.hPadding(context)),
                                child: SongTile(
                                  song: song,
                                  isPlaying: isCurrent,
                                  isFavorite: isFavorite,
                                  onFavoritePressed: () => provider.toggleFavorite(song),
                                  onTap: () => provider.playSong(song, queue: songs, index: index),
                                  onRemoveFromPlaylist: isCustomPlaylist
                                      ? () => provider.removeSongFromPlaylist(currentPlaylist.id, song.id)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: songs.length),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              );
            },
          ),
          // Persistent MiniPlayer at the bottom
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SongProvider provider, int playlistId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบเพลย์ลิสต์', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบเพลย์ลิสต์นี้?', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(color: Color(0xFF777777)))),
          TextButton(
            onPressed: () {
              provider.deletePlaylist(playlistId);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('ลบ', style: TextStyle(color: Color(0xFFFF4466))),
          ),
        ],
      ),
    );
  }
}
