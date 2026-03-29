import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/song_provider.dart';
import '../widgets/app_logo.dart';
import '../utils/playlist_utils.dart';


class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback? onRemoveFromPlaylist;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isFavorite = false,
    required this.onFavoritePressed,
    this.onRemoveFromPlaylist,
  });

  String _formatDuration(int seconds) {
    if (seconds == 0) return "--:--";
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  void _showSongMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Song info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                        imageUrl: song.thumbnailUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            
            // Menu items
            _menuItem(ctx, Icons.play_arrow_rounded, 'เล่นเพลงนี้', () {
              Navigator.pop(ctx);
              onTap();
            }),
            _menuItem(ctx, Icons.playlist_add_rounded, 'เพิ่มลงในเพลย์ลิสต์', () {
              Navigator.pop(ctx);
              PlaylistUtils.showAddToPlaylistSheet(context, song);
            }),

            _menuItem(
              ctx,
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              isFavorite ? 'ลบออกจากเพลงที่ชอบ' : 'เพิ่มในเพลงที่ชอบ',
              () {
                Navigator.pop(ctx);
                onFavoritePressed();
              },
              iconColor: isFavorite ? const Color(0xFFFF4466) : null,
            ),
            if (onRemoveFromPlaylist != null)
              _menuItem(
                ctx, 
                Icons.delete_outline_rounded, 
                'ลบออกจากเพลย์ลิสต์', 
                () {
                  Navigator.pop(ctx);
                  onRemoveFromPlaylist!();
                },
                iconColor: const Color(0xFFFF4466),
              ),
            _menuItem(ctx, Icons.share_rounded, 'แชร์', () {
              Navigator.pop(ctx);
              // TODO: Share song
            }),
            _menuItem(ctx, Icons.info_outline_rounded, 'ข้อมูลเพลง', () {
              Navigator.pop(ctx);
              _showSongInfo(context);
            }),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {Color? iconColor}) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFFBBBBBB), size: 22),
      title: Text(label, style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }


  void _showSongInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ข้อมูลเพลง', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('ชื่อเพลง', song.title),
            const SizedBox(height: 8),
            _infoRow('ศิลปิน', song.artist),
            const SizedBox(height: 8),
            _infoRow('ความยาว', _formatDuration(song.duration)),
            const SizedBox(height: 8),
            _infoRow('Video ID', song.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด', style: TextStyle(color: Color(0xFFF15A24))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF777777), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(song.duration);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFFF15A24).withValues(alpha: 0.06),
        highlightColor: const Color(0xFFF15A24).withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼 YouTube-style 16:9 Thumbnail with duration overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      width: 120,
                      height: 68, // 16:9 ratio
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 120,
                        height: 68,
                        color: const Color(0xFF1E1E1E),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFFF15A24),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: 68,
                        color: const Color(0xFF1E1E1E),
                        child: const Center(
                          child: AppLogo(size: 22, showText: false),
                        ),
                      ),
                    ),
                  ),
                  // ⏱ Duration badge (bottom-right)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        durationText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  // ❤️ Favorite indicator (top-left badge)
                  if (isFavorite)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 10,
                          color: Color(0xFFFF4466),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 10),

              // 📝 Title, Artist & 3-dot menu
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ⋮ 3-dot menu button
                    GestureDetector(
                      onTap: () => _showSongMenu(context),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4, top: 0),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFF888888),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
