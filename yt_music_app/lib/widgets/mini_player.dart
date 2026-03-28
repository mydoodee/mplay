import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../services/song_provider.dart';
import '../screens/player_screen.dart';
import '../widgets/app_logo.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final currentSong = songProvider.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final playing = playbackState?.playing ?? false;
        final position = playbackState?.position ?? Duration.zero;
        final duration = audioHandler?.mediaItem.value?.duration ?? Duration.zero;
        final processingState = playbackState?.processingState ?? AudioProcessingState.idle;

        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
          progress = position.inMilliseconds / duration.inMilliseconds;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          child: Container(
            height: 68,
            margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // 🎵 Premium dark glass background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: const Color(0xFF2A2A2A),
                          width: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album_art_${currentSong.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: currentSong.thumbnail.isNotEmpty && currentSong.thumbnail != "NA"
                                ? CachedNetworkImage(
                                    imageUrl: currentSong.thumbnail,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFF252525),
                                    child: const Center(
                                      child: AppLogo(size: 20, showText: false),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSong.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentSong.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),  // ✅ ชัดขึ้น
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Controls
                        if (processingState == AudioProcessingState.loading ||
                            processingState == AudioProcessingState.buffering)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF15A24)),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              if (playing) {
                                audioHandler?.pause();
                              } else {
                                audioHandler?.play();
                              }
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Color(0xFFBBBBBB), size: 22),
                          onPressed: () => audioHandler?.skipToNext(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  
                  // 🎵 Progress Bar — เส้นบาง premium
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2.5,
                      color: const Color(0xFF222222),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
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
