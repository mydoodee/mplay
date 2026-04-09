import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../widgets/app_logo.dart';
import '../services/song_provider.dart';
import '../utils/playlist_utils.dart';
import '../widgets/song_tile.dart';
import '../models/song.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final currentSong = songProvider.currentSong;

    if (currentSong == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "ไม่มีเพลงที่กำลังเล่นอยู่",
            style: TextStyle(color: Color(0xFF666666)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 30,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const AppLogo(size: 26, showText: true),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF888888),
              size: 22,
            ),
            onPressed: () =>
                _showPlayerMenu(context, songProvider, currentSong),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🎵 Dynamic Blurred Background
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: currentSong.thumbnailUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    // Ensure the content takes at least the full height of the viewport
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const Spacer(flex: 1),

                          // 🎵 Album Art
                          Hero(
                            tag: 'album_art_${currentSong.id}',
                            child: Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.88,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: CachedNetworkImage(
                                      imageUrl: currentSong.hqThumbnailUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: const Color(0xFF1A1A1A),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFF15A24),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: const Color(0xFF1A1A1A),
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          color: Color(0xFF333333),
                                          size: 60,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(flex: 1),

                          // 🎵 Track Info & Favorite — ฟอนต์ปรับให้เห็นชัด
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentSong.title,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        currentSong.artist,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(
                                            0xFFBBBBBB,
                                          ), // ✅ สว่างชัด มองเห็นง่าย
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: FutureBuilder<bool>(
                                    future:
                                        songProvider.isFavorite(currentSong.id),
                                    builder: (context, snapshot) {
                                      final isFav = snapshot.data ?? false;
                                      return Icon(
                                        isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isFav
                                            ? const Color(0xFFFF4466)
                                            : const Color(0xFF666666),
                                        size: 26,
                                      );
                                    },
                                  ),
                                  onPressed: () =>
                                      songProvider.toggleFavorite(currentSong),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 🎵 Seek Bar — premium slider
                          StreamBuilder<PlaybackState>(
                            stream: audioHandler?.playbackState,
                            builder: (context, snapshot) {
                              final playbackState = snapshot.data;
                              final position =
                                  playbackState?.position ?? Duration.zero;
                              final duration =
                                  audioHandler?.mediaItem.value?.duration ??
                                  Duration.zero;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor:
                                            const Color(0xFFF15A24),
                                        inactiveTrackColor:
                                            const Color(0xFF2A2A2A),
                                        thumbColor: Colors.white,
                                        overlayColor: const Color(
                                          0xFFF15A24,
                                        ).withValues(alpha: 0.15),
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 14,
                                            ),
                                      ),
                                      child: Slider(
                                        value: position.inMilliseconds
                                            .toDouble()
                                            .clamp(
                                              0,
                                              duration.inMilliseconds
                                                  .toDouble(),
                                            ),
                                        max: duration.inMilliseconds
                                                    .toDouble() >
                                                0
                                            ? duration.inMilliseconds.toDouble()
                                            : 1.0,
                                        onChanged: (value) {
                                          audioHandler?.seek(
                                            Duration(
                                              milliseconds: value.round(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(position),
                                            style: const TextStyle(
                                              color: Color(0xFF888888),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(duration),
                                            style: const TextStyle(
                                              color: Color(0xFF888888),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // 🎵 Playback Controls — premium
                          StreamBuilder<PlaybackState>(
                            stream: audioHandler?.playbackState,
                            builder: (context, snapshot) {
                              final playbackState = snapshot.data;
                              final playing = playbackState?.playing ?? false;
                              final repeatMode =
                                  playbackState?.repeatMode ??
                                  AudioServiceRepeatMode.none;
                              final shuffleMode =
                                  playbackState?.shuffleMode ??
                                  AudioServiceShuffleMode.none;
                              final processingState =
                                  playbackState?.processingState ??
                                  AudioProcessingState.idle;

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.shuffle_rounded,
                                      size: 22,
                                      color: shuffleMode ==
                                              AudioServiceShuffleMode.all
                                          ? const Color(0xFFF15A24)
                                          : const Color(0xFF555555),
                                    ),
                                    onPressed: () {
                                      audioHandler?.setShuffleMode(
                                        shuffleMode ==
                                                AudioServiceShuffleMode.all
                                            ? AudioServiceShuffleMode.none
                                            : AudioServiceShuffleMode.all,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    iconSize: 40,
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed:
                                        () => audioHandler?.skipToPrevious(),
                                  ),

                                  // Play/Pause Button — gradient background
                                  GestureDetector(
                                    onTap: () {
                                      if (playing) {
                                        audioHandler?.pause();
                                      } else {
                                        audioHandler?.play();
                                      }
                                    },
                                    child: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFF15A24),
                                            Color(0xFFED1C24),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFF15A24,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child:
                                            processingState ==
                                                        AudioProcessingState
                                                            .loading ||
                                                    processingState ==
                                                        AudioProcessingState
                                                            .buffering
                                                ? const SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.black,
                                                        strokeWidth: 2.5,
                                                      ),
                                                )
                                                : Icon(
                                                  playing
                                                      ? Icons.pause_rounded
                                                      : Icons.play_arrow_rounded,
                                                  size: 38,
                                                  color: Colors.black,
                                                ),
                                      ),
                                    ),
                                  ),

                                  IconButton(
                                    iconSize: 40,
                                    icon: const Icon(
                                      Icons.skip_next_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => audioHandler?.skipToNext(),
                                  ),

                                  IconButton(
                                    icon: Icon(
                                      repeatMode == AudioServiceRepeatMode.one
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                      size: 22,
                                      color:
                                          repeatMode !=
                                                  AudioServiceRepeatMode.none
                                              ? const Color(0xFFF15A24)
                                              : const Color(0xFF555555),
                                    ),
                                    onPressed: () {
                                      AudioServiceRepeatMode nextMode;
                                      if (repeatMode ==
                                          AudioServiceRepeatMode.none) {
                                        nextMode = AudioServiceRepeatMode.all;
                                      } else if (repeatMode ==
                                          AudioServiceRepeatMode.all) {
                                        nextMode = AudioServiceRepeatMode.one;
                                      } else {
                                        nextMode = AudioServiceRepeatMode.none;
                                      }
                                      audioHandler?.setRepeatMode(nextMode);
                                    },
                                  ),
                                ],
                              );
                            },
                          ),

                          const Spacer(flex: 2),

                          // Bottom Row
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed:
                                      () => _showQueueSheet(context, songProvider),
                                  icon: const Icon(
                                    Icons.playlist_play_rounded,
                                    color: Color(0xFFBBBBBB),
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'รายการถัดไป',
                                    style: TextStyle(
                                      color: Color(0xFFBBBBBB),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('ฟีเจอร์เนื้อเพลงเร็วๆ นี้'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.lyrics_outlined,
                                    color: Color(0xFF777777),
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'เนื้อเพลง',
                                    style: TextStyle(
                                      color: Color(0xFF777777),
                                      fontSize: 12,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerMenu(BuildContext context, SongProvider provider, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: Colors.white,
              ),
              title: const Text(
                'เพิ่มลงในเพลย์ลิสต์',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                PlaylistUtils.showAddToPlaylistSheet(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white),
              title: const Text(
                'แชร์เพลงนี้',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
              ),
              title: const Text(
                'ข้อมูลเพลง',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context, SongProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StreamBuilder<List<MediaItem>>(
          stream: audioHandler?.queue,
          builder: (context, snapshot) {
            final queue = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.playlist_play_rounded,
                          color: Color(0xFFF15A24),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'รายการเพลงที่เล่นอยู่',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF222222)),
                  Expanded(
                    child: queue.isEmpty
                        ? const Center(
                            child: Text(
                              'ไม่มีเพลงในรายการ',
                              style: TextStyle(color: Color(0xFF555555)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: queue.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemBuilder: (context, index) {
                              final item = queue[index];
                              final song = Song(
                                id: item.id,
                                title: item.title,
                                artist: item.artist ?? '',
                                thumbnail: item.artUri?.toString() ?? '',
                                duration: item.duration?.inSeconds ?? 0,
                              );

                              final isCurrent =
                                  provider.currentSong?.id == song.id;

                              return Opacity(
                                opacity: isCurrent ? 1.0 : 0.7,
                                child: SongTile(
                                  song: song,
                                  isPlaying: isCurrent,
                                  isFavorite: false, // Simplifying for queue
                                  onFavoritePressed: () =>
                                      provider.toggleFavorite(song),
                                  onTap: () {
                                    audioHandler?.skipToQueueItem(index);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
