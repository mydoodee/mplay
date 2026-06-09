import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../widgets/app_logo.dart';
import '../utils/playlist_utils.dart';
import '../widgets/mini_equalizer.dart';
import '../l10n/app_localizations.dart';

class TabletSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback? onRemoveFromPlaylist;
  final bool isPlaying;
  final VoidCallback? onDownload;
  final bool isDownloaded;
  final bool isDownloading;

  const TabletSongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.isFavorite = false,
    required this.onFavoritePressed,
    this.onRemoveFromPlaylist,
    this.isPlaying = false,
    this.onDownload,
    this.isDownloaded = false,
    this.isDownloading = false,
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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return Container(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF2A2A2A), height: 1),

              // Menu items
              _menuItem(ctx, Icons.play_arrow_rounded, l10n.playSong, () {
                Navigator.pop(ctx);
                onTap();
              }),
              _menuItem(
                ctx,
                Icons.playlist_add_rounded,
                l10n.addToPlaylist,
                () {
                  Navigator.pop(ctx);
                  PlaylistUtils.showAddToPlaylistSheet(context, song);
                },
              ),
              _menuItem(
                ctx,
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                isFavorite ? l10n.removeFavorite : l10n.addFavorite,
                () {
                  Navigator.pop(ctx);
                  onFavoritePressed();
                },
                iconColor: isFavorite ? const Color(0xFFF15A24) : Colors.white,
              ),
              if (onRemoveFromPlaylist != null)
                _menuItem(
                  ctx,
                  Icons.playlist_remove_rounded,
                  l10n.removeFromPlaylist,
                  () {
                    Navigator.pop(ctx);
                    onRemoveFromPlaylist!();
                  },
                  iconColor: const Color(0xFFFF4466),
                ),
              // 📥 Download button — only for non-local songs
              if (!song.isLocal && onDownload != null)
                _menuItem(
                  ctx,
                  isDownloaded
                      ? Icons.download_done_rounded
                      : (isDownloading
                          ? Icons.downloading_rounded
                          : Icons.download_rounded),
                  isDownloaded
                      ? l10n.alreadyDownloaded
                      : (isDownloading
                          ? l10n.downloadingSong
                          : l10n.downloadSong),
                  isDownloaded || isDownloading
                      ? () => Navigator.pop(ctx)
                      : () {
                          Navigator.pop(ctx);
                          onDownload!();
                        },
                  iconColor: isDownloaded
                      ? const Color(0xFF4CAF50)
                      : (isDownloading
                          ? const Color(0xFFFFA726)
                          : Colors.white),
                ),
              _menuItem(ctx, Icons.share_rounded, l10n.share, () {
                Navigator.pop(ctx);
              }),
              _menuItem(ctx, Icons.info_outline_rounded, l10n.songInfo, () {
                Navigator.pop(ctx);
                _showSongInfo(context);
              }),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? const Color(0xFFBBBBBB),
        size: 22,
      ),
      title: Text(
        label,
        style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  void _showSongInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.songInfo,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow(l10n.songTitle, song.title),
            const SizedBox(height: 12),
            _infoRow(l10n.artist, song.artist),
            const SizedBox(height: 12),
            _infoRow(l10n.duration, _formatDuration(song.duration)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.close,
              style: const TextStyle(color: Color(0xFFF15A24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF777777), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(song.duration);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🖼 Widescreen (16:9) Thumbnail with duration and favorite badge
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        border: Border.all(
                          color: isPlaying
                              ? const Color(0xFFF15A24).withValues(alpha: 0.8)
                              : const Color(0xFF222222),
                          width: isPlaying ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: song.isLocal
                            ? (song.coverArtBytes != null
                                ? Image.memory(
                                    song.coverArtBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: const Color(0xFF1E1E1E),
                                    child: const Center(
                                      child: AppLogo(
                                        size: 28,
                                        showText: false,
                                      ),
                                    ),
                                  ))
                            : CachedNetworkImage(
                                imageUrl: song.thumbnailUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                memCacheHeight: 225,
                                placeholder: (_, _) => Container(
                                  color: const Color(0xFF1E1E1E),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF15A24),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: const Color(0xFF1E1E1E),
                                  child: const Center(
                                    child: AppLogo(size: 28, showText: false),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                // ⏱ Duration badge (bottom-right)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
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
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: Color(0xFFFF4466),
                      ),
                    ),
                  ),
                // playing visualization overlay
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: const Center(
                        child: MiniEqualizer(
                          color: Color(0xFFF15A24),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Title & Meta Info below Thumbnail
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying ? const Color(0xFFF15A24) : Colors.white,
                          fontSize: 14,
                          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        song.isLive ? 'Live Stream' : 'YouTube Music',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSongMenu(context),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
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
    );
  }
}
