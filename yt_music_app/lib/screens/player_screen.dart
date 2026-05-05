import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../widgets/app_logo.dart';
import '../services/song_provider.dart';
import '../utils/playlist_utils.dart';
import '../utils/responsive.dart';
import '../widgets/song_tile.dart';
import '../models/song.dart';
import '../l10n/app_localizations.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Force retry เมื่อ player ค้าง
  void _retryPlayback() {
    audioHandler?.seek(Duration.zero);
    audioHandler?.play();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final songProvider = Provider.of<SongProvider>(context);
    final currentSong = songProvider.currentSong;

    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            l10n.noSongPlaying,
            style: const TextStyle(color: Color(0xFF666666)),
          ),
        ),
      );
    }

    final useWide = Responsive.usePlayerLandscapeLayout(context);

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
      body: GestureDetector(
        // 🎯 Swipe left/right เพื่อเปลี่ยนเพลง
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -400) {
              audioHandler?.skipToNext();
            } else if (details.primaryVelocity! > 400) {
              audioHandler?.skipToPrevious();
            }
          }
        },
        child: Stack(
          children: [
            // 🎵 Dynamic Blurred Background
            Positioned.fill(
              child: currentSong.isLocal
                  ? (currentSong.coverArtBytes != null
                        ? Image.memory(
                            currentSong.coverArtBytes!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF0D0D0D),
                            child: const Center(
                              child: AppLogo(
                                size: 100,
                                showText: false,
                                color: Colors.white24,
                              ),
                            ),
                          ))
                  : CachedNetworkImage(
                      imageUrl: currentSong.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF0D0D0D),
                        child: const Center(
                          child: AppLogo(
                            size: 100,
                            showText: false,
                            color: Colors.white24,
                          ),
                        ),
                      ),
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
              left: false,
              right: false,
              child: useWide
                  ? _buildWideLayout(context, songProvider, currentSong)
                  : _buildNarrowLayout(context, songProvider, currentSong),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  NARROW LAYOUT  (Phone / Tablet Portrait)
  // ──────────────────────────────────────────────
  Widget _buildNarrowLayout(
    BuildContext context,
    SongProvider songProvider,
    Song currentSong,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(context);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Spacer(flex: isTablet ? 1 : 1),
                  _buildAlbumArt(context, currentSong),
                  Spacer(flex: isTablet ? 1 : 1),
                  _buildTrackInfo(context, songProvider, currentSong),
                  SizedBox(height: isTablet ? 32 : 24),
                  _buildSeekBar(context),
                  SizedBox(height: isTablet ? 20 : 12),
                  _buildControls(context, constraints.maxWidth),
                  Spacer(flex: isTablet ? 3 : 2),
                  _buildBottomRow(context, songProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  //  WIDE LAYOUT  (Tablet Landscape)
  // ──────────────────────────────────────────────
  Widget _buildWideLayout(
    BuildContext context,
    SongProvider songProvider,
    Song currentSong,
  ) {
    return Row(
      children: [
        // Left: Album Art
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: _buildAlbumArt(context, currentSong)),
          ),
        ),
        // Divider
        Container(width: 0.5, color: Colors.white.withValues(alpha: 0.08)),
        // Right: Controls
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildTrackInfo(context, songProvider, currentSong),
                const SizedBox(height: 32),
                _buildSeekBar(context),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) =>
                      _buildControls(context, constraints.maxWidth),
                ),
                const SizedBox(height: 32),
                _buildBottomRow(context, songProvider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  //  SHARED COMPONENTS
  // ──────────────────────────────────────────────

  Widget _buildAlbumArt(BuildContext context, Song currentSong) {
    final isTablet = Responsive.isTablet(context);
    final isLandscape = Responsive.usePlayerLandscapeLayout(context);

    // กำหนด padding รอบรูป
    final double hPad = isLandscape ? 0 : (isTablet ? 40 : 24);
    final double radius = isTablet ? 20.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Hero(
        tag: 'album_art_${currentSong.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 36,
                spreadRadius: 4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: currentSong.isLocal
                  ? (currentSong.coverArtBytes != null
                        ? Image.memory(
                            currentSong.coverArtBytes!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF1A1A1A),
                            child: const Center(
                              child: AppLogo(size: 60, showText: false),
                            ),
                          ))
                  : CachedNetworkImage(
                      imageUrl: currentSong.maxResThumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => CachedNetworkImage(
                        imageUrl: currentSong.sdThumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, secondError) =>
                            CachedNetworkImage(
                              imageUrl: currentSong.hqThumbnailUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, thirdError) =>
                                  Container(
                                    color: const Color(0xFF1A1A1A),
                                    child: const Center(
                                      child: AppLogo(size: 60, showText: false),
                                    ),
                                  ),
                            ),
                      ),
                      placeholder: (_, _) => Container(
                        color: const Color(0xFF1A1A1A),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFF15A24),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(
    BuildContext context,
    SongProvider songProvider,
    Song currentSong,
  ) {
    final isTablet = Responsive.isTablet(context);
    final hPad = isTablet ? 48.0 : 32.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: isTablet
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  currentSong.title,
                  textAlign: isTablet ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 22,
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
                  textAlign: isTablet ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 15,
                    color: const Color(0xFFBBBBBB),
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
              future: songProvider.isFavorite(currentSong.id),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
                return Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav
                      ? const Color(0xFFFF4466)
                      : const Color(0xFF666666),
                  size: isTablet ? 30 : 26,
                );
              },
            ),
            onPressed: () => songProvider.toggleFavorite(currentSong),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final position = playbackState?.position ?? Duration.zero;
        final duration =
            audioHandler?.mediaItem.value?.duration ?? Duration.zero;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFF15A24),
                  inactiveTrackColor: const Color(0xFF2A2A2A),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFFF15A24).withValues(alpha: 0.15),
                  trackHeight: isTablet ? 4 : 3,
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: isTablet ? 6 : 5,
                  ),
                  overlayShape: RoundSliderOverlayShape(
                    overlayRadius: isTablet ? 16 : 14,
                  ),
                ),
                child: Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    duration.inMilliseconds.toDouble(),
                  ),
                  max: duration.inMilliseconds.toDouble() > 0
                      ? duration.inMilliseconds.toDouble()
                      : 1.0,
                  onChanged: (value) {
                    audioHandler?.seek(Duration(milliseconds: value.round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: isTablet ? 13 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: isTablet ? 13 : 11,
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
    );
  }

  Widget _buildControls(BuildContext context, double maxWidth) {
    final isTablet = Responsive.isTablet(context);
    final useSmallIcons = maxWidth < 320;

    final playBtnSize = (isTablet && !useSmallIcons) ? 84.0 : 66.0;
    final playIconSize = (isTablet && !useSmallIcons) ? 46.0 : 36.0;
    final skipIconSize = (isTablet && !useSmallIcons) ? 44.0 : 36.0;
    final sideIconSize = (isTablet && !useSmallIcons) ? 26.0 : 20.0;

    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, snapshot) {
        final playbackState = snapshot.data;
        final playing = playbackState?.playing ?? false;
        final repeatMode =
            playbackState?.repeatMode ?? AudioServiceRepeatMode.none;
        final shuffleMode =
            playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
        final processingState =
            playbackState?.processingState ?? AudioProcessingState.idle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                Icons.shuffle_rounded,
                size: sideIconSize,
                color: shuffleMode == AudioServiceShuffleMode.all
                    ? const Color(0xFFF15A24)
                    : const Color(0xFF555555),
              ),
              onPressed: () {
                audioHandler?.setShuffleMode(
                  shuffleMode == AudioServiceShuffleMode.all
                      ? AudioServiceShuffleMode.none
                      : AudioServiceShuffleMode.all,
                );
              },
            ),
            IconButton(
              iconSize: skipIconSize,
              icon: const Icon(
                Icons.skip_previous_rounded,
                color: Colors.white,
              ),
              onPressed: () => audioHandler?.skipToPrevious(),
            ),

            // Play/Pause Button
            GestureDetector(
              onTap: () {
                if (playing) {
                  audioHandler?.pause();
                } else {
                  if (processingState == AudioProcessingState.completed) {
                    audioHandler?.seek(Duration.zero);
                  }
                  audioHandler?.play();
                }
              },
              child: Container(
                width: playBtnSize,
                height: playBtnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF15A24).withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child:
                      processingState == AudioProcessingState.loading ||
                          processingState == AudioProcessingState.buffering
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: playIconSize * 0.6,
                              height: playIconSize * 0.6,
                              child: const CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _retryPlayback,
                              child: Text(
                                'ลองอีกครั้ง',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: playIconSize,
                          color: Colors.black,
                        ),
                ),
              ),
            ),

            IconButton(
              iconSize: skipIconSize,
              icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              onPressed: () => audioHandler?.skipToNext(),
            ),

            IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: sideIconSize,
                color: repeatMode != AudioServiceRepeatMode.none
                    ? const Color(0xFFF15A24)
                    : const Color(0xFF555555),
              ),
              onPressed: () {
                AudioServiceRepeatMode nextMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  nextMode = AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
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
    );
  }

  Widget _buildBottomRow(BuildContext context, SongProvider songProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => _showQueueSheet(context, songProvider),
            icon: const Icon(
              Icons.playlist_play_rounded,
              color: Color(0xFFBBBBBB),
              size: 20,
            ),
            label: Text(
              l10n.upNext,
              style: const TextStyle(
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
                SnackBar(
                  content: Text(l10n.lyricsComingSoon),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(
              Icons.lyrics_outlined,
              color: Color(0xFF777777),
              size: 18,
            ),
            label: Text(
              l10n.lyrics,
              style: const TextStyle(color: Color(0xFF777777), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showPlayerMenu(BuildContext context, SongProvider provider, Song song) {
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(
                l10n.addToPlaylist,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                PlaylistUtils.showAddToPlaylistSheet(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.white),
              title: Text(
                l10n.shareSong,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
              ),
              title: Text(
                l10n.songInfo,
                style: const TextStyle(color: Colors.white),
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
    final isTablet = Responsive.isTablet(context);
    final l10n = AppLocalizations.of(context)!;
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
              height:
                  MediaQuery.of(context).size.height * (isTablet ? 0.85 : 0.75),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.playlist_play_rounded,
                          color: const Color(0xFFF15A24),
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Text(
                          l10n.currentQueue,
                          style: const TextStyle(
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
                        ? Center(
                            child: Text(
                              l10n.noSongsInQueue,
                              style: const TextStyle(color: Color(0xFF555555)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: queue.length,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 24 : 8,
                            ),
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
                                  isFavorite: false,
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
