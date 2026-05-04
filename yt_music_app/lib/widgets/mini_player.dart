import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../services/song_provider.dart';
import '../screens/player_screen.dart';
import '../widgets/app_logo.dart';
import '../utils/responsive.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final currentSong = songProvider.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final isTablet = Responsive.isTablet(context);
    final playerHeight = Responsive.miniPlayerHeight(context);
    final albumArtSize = Responsive.miniAlbumArtSize(context);
    final titleFontSize = Responsive.miniTitleFontSize(context);
    final artistFontSize = Responsive.miniArtistFontSize(context);
    final hPad = Responsive.hPadding(context);

    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final playing = playbackState?.playing ?? false;
        final position = playbackState?.position ?? Duration.zero;
        final duration =
            audioHandler?.mediaItem.value?.duration ?? Duration.zero;
        final processingState =
            playbackState?.processingState ?? AudioProcessingState.idle;

        final isBuffering = processingState == AudioProcessingState.loading ||
            processingState == AudioProcessingState.buffering;

        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
          progress = position.inMilliseconds / duration.inMilliseconds;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const PlayerScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
              ),
            );
          },
          // 🎯 Swipe left/right เพื่อเปลี่ยนเพลง
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -300) {
                audioHandler?.skipToNext();
              } else if (details.primaryVelocity! > 300) {
                audioHandler?.skipToPrevious();
              }
            }
          },
          child: Container(
            height: playerHeight,
            margin: EdgeInsets.only(
              left: isTablet ? 12 : 8,
              right: isTablet ? 12 : 8,
              bottom: isTablet ? 10 : 8,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
              child: Stack(
                children: [
                  // 🎵 Premium dark glass background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D00),
                        borderRadius: BorderRadius.circular(isTablet ? 20 : 14),
                        border: Border.all(
                          color: const Color(0xFFF15A24).withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF15A24).withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✨ Shimmer overlay ตอน buffering
                  if (isBuffering)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (_, _) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(isTablet ? 20 : 14),
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
                                end: Alignment(-0.5 + 2.0 * _shimmerController.value, 0),
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFF15A24).withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Content
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album_art_${currentSong.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isTablet ? 10 : 8,
                            ),
                            child:
                                currentSong.isLocal
                                    ? (currentSong.coverArtBytes != null
                                        ? Image.memory(
                                            currentSong.coverArtBytes!,
                                            width: albumArtSize,
                                            height: albumArtSize,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: albumArtSize,
                                            height: albumArtSize,
                                            color: const Color(0xFF252525),
                                            child: Center(
                                              child: Icon(
                                                Icons.music_note_rounded,
                                                color: const Color(0xFFF15A24),
                                                size: isTablet ? 26 : 20,
                                              ),
                                            ),
                                          ))
                                    : (currentSong.thumbnail.isNotEmpty &&
                                        currentSong.thumbnail != "NA"
                                    ? CachedNetworkImage(
                                        imageUrl: currentSong.thumbnail,
                                        width: albumArtSize,
                                        height: albumArtSize,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: albumArtSize,
                                        height: albumArtSize,
                                        color: const Color(0xFF252525),
                                        child: Center(
                                          child: AppLogo(
                                            size: isTablet ? 26 : 20,
                                            showText: false,
                                          ),
                                        ),
                                      )),
                          ),
                        ),
                        SizedBox(width: isTablet ? 16 : 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: titleFontSize,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (isBuffering) ...[
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: const Color(0xFFF15A24).withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      isBuffering ? 'กำลังโหลด...' : currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isBuffering
                                            ? const Color(0xFFF15A24).withValues(alpha: 0.7)
                                            : const Color(0xFFAAAAAA),
                                        fontSize: artistFontSize,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Controls
                        IconButton(
                          icon: isBuffering
                              ? SizedBox(
                                  width: isTablet ? 26 : 22,
                                  height: isTablet ? 26 : 22,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFF15A24),
                                  ),
                                )
                              : Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: isTablet ? 34 : 28,
                                ),
                          onPressed: () {
                            if (isBuffering) return;
                            if (playing) {
                              audioHandler?.pause();
                            } else {
                              if (processingState == AudioProcessingState.completed) {
                                audioHandler?.seek(Duration.zero);
                              }
                              audioHandler?.play();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: const Color(0xFFBBBBBB),
                            size: isTablet ? 28 : 22,
                          ),
                          onPressed: () => audioHandler?.skipToNext(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  // 🎵 Progress Bar — เส้นบาง premium
                  Positioned(
                    bottom: 0,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFF15A24),
                                    Color(0xFFED1C24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
