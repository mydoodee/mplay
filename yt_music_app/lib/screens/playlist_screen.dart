import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/playlist.dart';
import '../services/song_provider.dart';
import '../widgets/tablet_song_card.dart';
import '../widgets/app_logo.dart';
import '../widgets/mini_player.dart';
import '../widgets/mini_equalizer.dart';
import '../utils/responsive.dart';
import '../l10n/app_localizations.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Consumer<SongProvider>(
            builder: (context, provider, child) {
              final currentPlaylist = provider.playlists.firstWhere(
                (p) => p.id == widget.playlist.id,
                orElse: () => widget.playlist,
              );
              final songs = currentPlaylist.songs;
              final isTablet = Responsive.isTablet(context);
              final hPad = Responsive.hPadding(context);
              final maxW = Responsive.contentMaxWidth(context);

              // Determine the thumbnail URL for the hero background
              String? heroImageUrl;
              if (songs.isNotEmpty && !songs[0].isLocal) {
                heroImageUrl = songs[0].maxResThumbnailUrl;
              }

              return CustomScrollView(
                slivers: [
                  // ──────────────────────────────────────────────
                  //  HERO HEADER with blurred background
                  // ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        // Background image with gradient overlay
                        // ใช้ foregroundDecoration แทน BackdropFilter
                        // เพื่อป้องกัน GPU pixel corruption บน Android head unit
                        if (heroImageUrl != null)
                          SizedBox(
                            height: isTablet ? 340 : 280,
                            width: double.infinity,
                            child: Container(
                              foregroundDecoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.0, 0.3, 0.7, 1.0],
                                  colors: [
                                    Colors.black.withValues(alpha: 0.5),
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.black,
                                  ],
                                ),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: heroImageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (ctx, url, err) =>
                                    CachedNetworkImage(
                                  imageUrl: songs[0].hqThumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (ctx, url, err) =>
                                      Container(color: const Color(0xFF0D0D0D)),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: isTablet ? 340 : 280,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF1A1008),
                                  Colors.black,
                                ],
                              ),
                            ),
                          ),

                        // Content overlay on the hero
                        SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              // App bar row
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: hPad - 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFF777777),
                                          size: 20,
                                        ),
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
                              ),

                              // Playlist info card
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints:
                                          BoxConstraints(maxWidth: maxW),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: hPad,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Album art with shadow
                                            Hero(
                                              tag:
                                                  'playlist_art_${currentPlaylist.id}',
                                              child: Container(
                                                width: isTablet ? 160 : 110,
                                                height: isTablet ? 160 : 110,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          isTablet ? 20 : 16),
                                                  color:
                                                      const Color(0xFF1A1A1A),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.1),
                                                    width: 1,
                                                  ),
                                                  image: songs.isNotEmpty
                                                      ? (songs[0].isLocal
                                                          ? (songs[0].coverArtBytes !=
                                                                  null
                                                              ? DecorationImage(
                                                                  image:
                                                                      MemoryImage(
                                                                    songs[0]
                                                                        .coverArtBytes!,
                                                                  ),
                                                                  fit: BoxFit
                                                                      .cover,
                                                                )
                                                              : null)
                                                          : DecorationImage(
                                                              image:
                                                                  CachedNetworkImageProvider(
                                                                songs[0]
                                                                    .thumbnailUrl,
                                                              ),
                                                              fit:
                                                                  BoxFit.cover,
                                                            ))
                                                      : null,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(
                                                              0xFFF15A24)
                                                          .withValues(
                                                              alpha: 0.15),
                                                      blurRadius: 30,
                                                      spreadRadius: 2,
                                                      offset:
                                                          const Offset(0, 8),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.5),
                                                      blurRadius: 20,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                                child: (songs.isEmpty ||
                                                        (songs[0].isLocal &&
                                                            songs[0]
                                                                    .coverArtBytes ==
                                                                null))
                                                    ? Center(
                                                        child: AppLogo(
                                                          size: isTablet
                                                              ? 56
                                                              : 40,
                                                          showText: false,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            SizedBox(
                                                width: isTablet ? 28 : 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    currentPlaylist.name,
                                                    style: TextStyle(
                                                      fontSize: isTablet
                                                          ? 34
                                                          : 26,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: -0.5,
                                                      height: 1.1,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      20),
                                                          border: Border.all(
                                                            color: Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.06),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .music_note_rounded,
                                                              color: const Color(
                                                                  0xFFF15A24),
                                                              size: 12,
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Text(
                                                              '${songs.length} เพลง',
                                                              style:
                                                                  TextStyle(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.7),
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          width: 8),
                                                      // Now playing indicator
                                                      if (songs.any((s) =>
                                                          s.id ==
                                                          provider.currentSong
                                                              ?.id))
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                    0xFFF15A24)
                                                                .withValues(
                                                                    alpha:
                                                                        0.15),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20),
                                                            border:
                                                                Border.all(
                                                              color: const Color(
                                                                      0xFFF15A24)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.3),
                                                            ),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              MiniEqualizer(
                                                                color: Color(
                                                                    0xFFF15A24),
                                                                size: 10,
                                                              ),
                                                              SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                'Playing',
                                                                style:
                                                                    TextStyle(
                                                                  color: Color(
                                                                      0xFFF15A24),
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'สร้างเพื่อคุณ',
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.35),
                                                      fontSize: isTablet
                                                          ? 13
                                                          : 11,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ──────────────────────────────────────────────
                  //  ACTION BUTTONS (Play All / Shuffle)
                  // ──────────────────────────────────────────────
                  if (songs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxW),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  hPad, 0, hPad, 20),
                              child: Row(
                                children: [
                                  // Play All button with gradient
                                  Expanded(
                                    child: Container(
                                      height: isTablet ? 54 : 48,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(16),
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
                                            color: const Color(0xFFF15A24)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            provider.playAll(songs),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        label: Text(
                                          l10n.playAll,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Shuffle button with glass effect
                                  Expanded(
                                    child: Container(
                                      height: isTablet ? 54 : 48,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            provider.shuffleAll(songs),
                                        icon: const Icon(
                                          Icons.shuffle_rounded,
                                          color: Color(0xFFCCCCCC),
                                          size: 22,
                                        ),
                                        label: Text(
                                          l10n.shufflePlay,
                                          style: const TextStyle(
                                            color: Color(0xFFCCCCCC),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ──────────────────────────────────────────────
                  //  SECTION HEADER — "All Songs"
                  // ──────────────────────────────────────────────
                  if (songs.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                hPad, 0, hPad, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF15A24),
                                        Color(0xFFFF9800),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.allSongs,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFCCCCCC),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${songs.length} เพลง',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ──────────────────────────────────────────────
                  //  EMPTY STATE
                  // ──────────────────────────────────────────────
                  if (songs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    Colors.white.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.06),
                                ),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: Colors.white
                                    .withValues(alpha: 0.15),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'ยังไม่มีเพลงในรายการ',
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.4),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'เพิ่มเพลงจากหน้าค้นหา',
                              style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ──────────────────────────────────────────────
                  //  SONG CARDS GRID
                  // ──────────────────────────────────────────────
                  if (songs.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet
                              ? Responsive.songListColumnCount(context)
                              : 2,
                          crossAxisSpacing: isTablet ? 16 : 12,
                          mainAxisSpacing: isTablet ? 16 : 12,
                          childAspectRatio: isTablet ? 1.22 : 0.75,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final song = songs[index];
                          final isFavorite = provider.favorites.any(
                            (s) => s.id == song.id,
                          );
                          final isCurrent =
                              provider.currentSong?.id == song.id;
                          final isCustomPlaylist =
                              currentPlaylist.id != -1;

                          return TabletSongCard(
                            song: song,
                            isPlaying: isCurrent,
                            isFavorite: isFavorite,
                            onFavoritePressed: () =>
                                provider.toggleFavorite(song),
                            onTap: () => provider.playSong(
                              song,
                              queue: songs,
                              index: index,
                            ),
                            onRemoveFromPlaylist: isCustomPlaylist
                                ? () => provider.removeSongFromPlaylist(
                                      currentPlaylist.id,
                                      song.id,
                                    )
                                : null,
                          );
                        }, childCount: songs.length),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              );
            },
          ),
          // Persistent MiniPlayer at the bottom
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    SongProvider provider,
    int playlistId,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4466).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF4466),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.deletePlaylist,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.deletePlaylistMessage,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Color(0xFF777777)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Close playlist screen
              provider.deletePlaylist(playlistId);
            },
            style: TextButton.styleFrom(
              backgroundColor:
                  const Color(0xFFFF4466).withValues(alpha: 0.15),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              l10n.delete,
              style: const TextStyle(
                color: Color(0xFFFF4466),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
