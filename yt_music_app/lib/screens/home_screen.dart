import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'playlist_screen.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/app_logo.dart';
import '../widgets/glowing_ring.dart';
import '../services/song_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/playlist_utils.dart';
import '../utils/responsive.dart';
import 'equalizer_screen.dart';
import 'admin_login_dialog.dart';
import '../widgets/voice_search_button.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../l10n/app_localizations.dart';
import '../widgets/mini_equalizer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _selectedIndex = 0;
  String _appVersion = '';
  String _listeningText = ''; // real-time text จาก voice search

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersion();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final updateInfo = await UpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(updateInfo: updateInfo),
      );
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${info.version} ${info.buildNumber}';
    });
  }

  Future<void> _showChangelog() async {
    try {
      final content = await rootBundle.loadString('assets/changelog.txt');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              l10n.changelog,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 13,
                    height: 1.7,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.close,
                  style: const TextStyle(color: Color(0xFFF15A24)),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cannotLoadChangelog)));
    }
  }

  void _onScroll() {
    // โหลดข้อมูลเพิ่มเฉพาะในหน้าค้นหา (index 0)
    if (_selectedIndex == 0) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final songProvider = Provider.of<SongProvider>(context, listen: false);
        if (songProvider.searchResults.isNotEmpty) {
          songProvider.searchMore();
        }
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// ค้นหาเมื่อกดปุ่มค้นหาหรือกด Enter
  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      FocusScope.of(context).unfocus(); // ปิด keyboard
      Provider.of<SongProvider>(context, listen: false).search(query);
    }
  }

  /// เรียกจาก voice search — ค้นหาทันที
  void _onVoiceSearchResult(String query) {
    if (query.isNotEmpty) {
      Provider.of<SongProvider>(context, listen: false).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    return _buildPhoneLayout(songProvider);
  }

  // ──────────────────────────────────────────────
  //  PHONE LAYOUT (original)
  // ──────────────────────────────────────────────
  Widget _buildPhoneLayout(SongProvider songProvider) {
    final results = songProvider.searchResults;
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          _buildSliverContent(songProvider, results),
          ..._buildSliverList(songProvider, results),
          if (_selectedIndex == 0 && songProvider.isFetchingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFF15A24),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const MiniPlayer(), _buildBottomNav()],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: const AppLogo(size: 26, showText: true),
            onSelected: (value) {
              if (value == 'admin') {
                showDialog(
                  context: context,
                  builder: (context) => const AdminLoginDialog(),
                );
              } else if (value == 'changelog') {
                _showChangelog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'admin',
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFF15A24),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.adminLogin,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'changelog',
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_edu_rounded,
                      color: Color(0xFFF15A24),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.changelog,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                enabled: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _appVersion.isNotEmpty ? ' $_appVersion' : 'Version ...',
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.tune_rounded,
            color: Color(0xFF777777),
            size: 22,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EqualizerScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final isTablet = Responsive.isTablet(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: isTablet ? 54 : 48,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
            border: Border.all(color: const Color(0xFF222222), width: 1),
            boxShadow: isTablet
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _performSearch(),
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 15 : 14,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                isDense: true,
                hintStyle: TextStyle(
                  color: const Color(0xFF555555),
                  fontSize: isTablet ? 15 : 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(
                    Icons.search_rounded,
                    color: const Color(0xFF555555),
                    size: isTablet ? 26 : 22,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                // suffix: clear button + mic button
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ปุ่ม Clear
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Color(0xFF777777),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _listeningText = '');
                                  Provider.of<SongProvider>(context, listen: false).clearSearch();
                                },
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    // ปุ่มค้นหา
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return value.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _performSearch,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF15A24),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.search_rounded,
                                    color: Colors.white,
                                    size: isTablet ? 22 : 18,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink();
                      },
                    ),
                    // ปุ่มค้นหาด้วยเสียง (ใช้แบบเดิม)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: VoiceSearchButton(
                        onListenStart: () {
                          setState(() => _listeningText = '');
                        },
                        onResult: (text) {
                          setState(() {
                            _listeningText = '';
                            _searchController.text = text;
                          });
                          _onVoiceSearchResult(text);
                        },
                      ),
                    ),
                  ],
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                  borderSide: const BorderSide(
                    color: Color(0xFFF15A24),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Real-time voice text hint
        if (_listeningText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0D00),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF15A24).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFFF15A24),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _listeningText,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSliverContent(SongProvider songProvider, List<Song> results) {
    final hPad = Responsive.hPadding(context);
    final l10n = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.contentMaxWidth(context),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedIndex == 0) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                ],
                if (_selectedIndex == 1) ...[_buildExploreTab(songProvider)],
                if (_selectedIndex == 2) ...[_buildLocalMusicTab(songProvider)],
                if (_selectedIndex == 3) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.yourLibrary,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Color(0xFFF15A24),
                        ),
                        onPressed: () => PlaylistUtils.showCreatePlaylistDialog(
                          context,
                          songProvider,
                        ),
                      ),
                    ],
                  ),
                  // Library tab: show playlist grid
                  _buildPlaylistGrid(songProvider, results),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSliverList(SongProvider songProvider, List<Song> results) {
    final l10n = AppLocalizations.of(context)!;
    final hPad = Responsive.hPadding(context);
    final maxW = Responsive.contentMaxWidth(context);
    final currentSong = songProvider.currentSong;
    List<Widget> slivers = [];

    // Loading State
    if (_selectedIndex == 0 && songProvider.isLoading) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFFF15A24),
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  l10n.searching,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Empty Welcome State
    if (_selectedIndex == 0 &&
        results.isEmpty &&
        songProvider.history.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlowingRing(
                  color: const Color(0xFFF15A24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D0D0D),
                      shape: BoxShape.circle,
                    ),
                    child: const AppLogo(size: 60, showText: false),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.findSongsYouLike,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.searchSongsArtistsOrLink,
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // 1. HYBRID RECENTLY PLAYED SECTION
    if (_selectedIndex == 0 && songProvider.history.isNotEmpty) {
      // Filter out current song only when the "Now Playing" card is visible (Index 0 or 1)
      // to avoid duplication. For other tabs, we don't need to filter.
      final bool shouldFilter = _selectedIndex == 0 || _selectedIndex == 1;

      final filteredFullHistory = songProvider.history.toList();

      final topHistory = filteredFullHistory.take(5).toList();
      final remainingHistory = filteredFullHistory.skip(5).toList();

      // A. Horizontal Top 5 Shelf (Filtered)
      if (topHistory.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: const Color(0xFFF15A24),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.recentlyPlayed,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => songProvider.clearHistory(),
                            child: Text(
                              l10n.clear,
                              style: const TextStyle(
                                color: Color(0xFF777777),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: hPad),
                        itemCount: topHistory.length,
                        itemBuilder: (context, index) {
                          final song = topHistory[index];
                          return GestureDetector(
                            onTap: () => songProvider.playSong(
                              song,
                              queue: songProvider.history,
                              index: songProvider.history.indexWhere(
                                (s) => s.id == song.id,
                              ),
                            ),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: song.thumbnailUrl,
                                        width: 150,
                                        height: 110,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // B. Vertical Remaining History (Only if not searching)
      if (results.isEmpty && remainingHistory.isNotEmpty) {
        slivers.add(
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = remainingHistory[index];
              final isFavorite = songProvider.favorites.any(
                (s) => s.id == song.id,
              );

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: SongTile(
                      song: song,
                      isPlaying: song.id == currentSong?.id,
                      isFavorite: isFavorite,
                      onFavoritePressed: () =>
                          songProvider.toggleFavorite(song),
                      onTap: () => songProvider.playSong(
                        song,
                        queue: songProvider.history,
                        index: songProvider.history.indexOf(song),
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: remainingHistory.length),
          ),
        );
      }
    }

    // 2. SEARCH RESULTS SECTION (Vertical List below)
    if (_selectedIndex == 0 && results.isNotEmpty) {
      // Filter out current song from results
      final filteredResults = results.toList();

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = filteredResults[index];
            final isFavorite = songProvider.favorites.any(
              (s) => s.id == song.id,
            );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: SongTile(
                    song: song,
                    isPlaying: song.id == currentSong?.id,
                    isFavorite: isFavorite,
                    onFavoritePressed: () => songProvider.toggleFavorite(song),
                    onTap: () => songProvider.playSong(song),
                  ),
                ),
              ),
            );
          }, childCount: filteredResults.length),
        ),
      );
    }

    return slivers;
  }

  Widget _buildNowPlayingSection(
    SongProvider songProvider,
    List<Song> results,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currentSong = songProvider.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFFF15A24),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.nowPlaying,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        _buildActivePlayingCard(
          songProvider,
          currentSong,
          queue: songProvider.history.isNotEmpty
              ? songProvider.history
              : (results.isNotEmpty ? results : [currentSong]),
          index: 0,
        ),
      ],
    );
  }

  Widget _buildActivePlayingCard(
    SongProvider songProvider,
    Song song, {
    required List<Song> queue,
    required int index,
  }) {
    final hPad = Responsive.hPadding(context);
    final maxW = Responsive.contentMaxWidth(context);
    final isFavorite = songProvider.favorites.any((s) => s.id == song.id);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A0D00),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF15A24).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: SongTile(
              song: song,
              isPlaying: true,
              isFavorite: isFavorite,
              onFavoritePressed: () => songProvider.toggleFavorite(song),
              onTap: () =>
                  songProvider.playSong(song, queue: queue, index: index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFFF15A24),
        unselectedItemColor: const Color(0xFF555555),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home_filled, size: 22),
            ),
            label: l10n.tabMusic,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.explore_outlined, size: 22),
            ),
            label: l10n.tabExplore,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.folder_rounded, size: 22),
            ),
            label: l10n.tabLocalFiles,
          ),
          BottomNavigationBarItem(
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.library_music_outlined, size: 22),
            ),
            label: l10n.tabLibrary,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(SongProvider provider, List<Song> results) {
    final l10n = AppLocalizations.of(context)!;
    final currentSong = provider.currentSong;
    final items = [
      Playlist(
        id: -1,
        name: l10n.favorites,
        createdAt: DateTime.now().toIso8601String(),
        songs: provider.favorites,
      ),
      ...provider.playlists,
    ];

    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = Responsive.gridCrossAxisCount(
      context,
      phone: 2,
      tablet: 3,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: 16 / 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final playlist = items[index];
        final isFavorite = playlist.id == -1;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF1A1A1A)),
              if (playlist.songs.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: playlist.songs[0].maxResThumbnailUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => CachedNetworkImage(
                    imageUrl: playlist.songs[0].hqThumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, err) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: AppLogo(size: 40, showText: false),
                      ),
                    ),
                  ),
                ),
              if (playlist.songs.isEmpty)
                Center(
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.queue_music_rounded,
                    color: isFavorite
                        ? const Color(0xFFFF4466).withValues(alpha: 0.4)
                        : const Color(0xFF444444),
                    size: 36,
                  ),
                ),
              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.3, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              // Favorite badge
              if (isFavorite)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4466).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              // Song count badge
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    if (playlist.songs.any((s) => s.id == currentSong?.id))
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF15A24).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            MiniEqualizer(color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'Playing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${playlist.songs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Title + subtitle on gradient
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playlist.songs.length} เพลง',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Ripple overlay
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withValues(alpha: 0.08),
                    highlightColor: Colors.white.withValues(alpha: 0.04),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PlaylistScreen(playlist: playlist),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalMusicTab(SongProvider songProvider) {
    final l10n = AppLocalizations.of(context)!;
    final localSongs = songProvider.localSongs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.localMusicTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.localMusicSubtitle,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        const SizedBox(height: 20),

        // ปุ่มเพิ่มโฟลเดอร์ / เพิ่มไฟล์
        Row(
          children: [
            Expanded(
              child: _buildLocalActionButton(
                icon: Icons.create_new_folder_rounded,
                label: l10n.addFolder,
                onTap: () => songProvider.addLocalFolder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLocalActionButton(
                icon: Icons.audio_file_rounded,
                label: l10n.addFiles,
                onTap: () => songProvider.addLocalFiles(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // สถานะกำลังสแกน
        if (songProvider.isScanning) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFF15A24),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.scanningFiles,
                    style: const TextStyle(
                      color: Color(0xFF777777),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // แสดงจำนวนเพลงที่เจอ + ปุ่มเล่นทั้งหมด/สุ่มเล่น
        if (localSongs.isNotEmpty && !songProvider.isScanning) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFFF15A24),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${localSongs.length} เพลง',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // ปุ่มเล่นทั้งหมด
                GestureDetector(
                  onTap: () => songProvider.playAll(localSongs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF15A24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.playAll,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ปุ่มสุ่มเล่น
                GestureDetector(
                  onTap: () => songProvider.shuffleAll(localSongs),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: const Icon(
                      Icons.shuffle_rounded,
                      color: Color(0xFFBBBBBB),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // รายการเพลง
        if (localSongs.isNotEmpty && !songProvider.isScanning)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: localSongs.length,
            itemBuilder: (context, index) {
              final song = localSongs[index];
              final currentSong = songProvider.currentSong;
              final isFavorite = songProvider.favorites.any(
                (s) => s.id == song.id,
              );
              final isCurrent = currentSong?.id == song.id;

              return Dismissible(
                key: Key(song.filePath ?? song.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: const Color(0xFFFF4466).withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFFF4466),
                  ),
                ),
                onDismissed: (_) => songProvider.removeLocalSong(song),
                child: SongTile(
                  song: song,
                  isPlaying: isCurrent,
                  isFavorite: isFavorite,
                  onFavoritePressed: () => songProvider.toggleFavorite(song),
                  onTap: () => songProvider.playSong(
                    song,
                    queue: localSongs,
                    index: index,
                  ),
                ),
              );
            },
          ),

        // Empty state
        if (localSongs.isEmpty && !songProvider.isScanning)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF222222),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFF555555),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.noLocalSongsMessage,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tapToAddLocalSongsMessage,
                    style: const TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFF15A24), size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTab(SongProvider songProvider) {
    final l10n = AppLocalizations.of(context)!;
    final currentYear = DateTime.now().year;
    // List of categories
    final categories = [
      {
        'title': l10n.exploreHot,
        'subtitle': l10n.exploreHotSub(currentYear),
        'query': l10n.exploreHotQuery(currentYear),
        'icon': Icons.local_fire_department_rounded,
        'colors': [const Color(0xFFFF5722), const Color(0xFFFF9800)],
        'image': 'https://porawat.github.io/app-ads/images/photo-1.jpeg',
      },
      {
        'title': l10n.exploreRelax,
        'subtitle': l10n.exploreRelaxSub,
        'query': l10n.exploreRelaxQuery(currentYear),
        'icon': Icons.coffee_rounded,
        'colors': [const Color(0xFF795548), const Color(0xFFA1887F)],
        'image': 'https://porawat.github.io/app-ads/images/photo-2.jpeg',
      },
      {
        'title': l10n.exploreIndie,
        'subtitle': l10n.exploreIndieSub,
        'query': l10n.exploreIndieQuery,
        'icon': Icons.mic_external_on_rounded,
        'colors': [const Color(0xFFE91E63), const Color(0xFFF06292)],
        'image': 'https://porawat.github.io/app-ads/images/photo-3.jpeg',
      },
      {
        'title': l10n.explorePop,
        'subtitle': l10n.explorePopSub,
        'query': l10n.explorePopQuery(currentYear),
        'icon': Icons.public_rounded,
        'colors': [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
        'image': 'https://porawat.github.io/app-ads/images/photo-4.jpeg',
      },
      {
        'title': l10n.exploreRock,
        'subtitle': l10n.exploreRockSub,
        'query': l10n.exploreRockQuery,
        'icon': Icons.electric_bolt_rounded,
        'colors': [const Color(0xFFF44336), const Color(0xFFEF5350)],
        'image': 'https://porawat.github.io/app-ads/images/photo-5.jpeg',
      },
      {
        'title': l10n.exploreSad,
        'subtitle': l10n.exploreSadSub,
        'query': l10n.exploreSadQuery(currentYear),
        'icon': Icons.water_drop_rounded,
        'colors': [const Color(0xFF3F51B5), const Color(0xFF7986CB)],
        'image': 'https://porawat.github.io/app-ads/images/photo-6.jpg',
      },
      {
        'title': l10n.exploreDance,
        'subtitle': l10n.exploreDanceSub,
        'query': l10n.exploreDanceQuery(currentYear),
        'icon': Icons.speaker_group_rounded,
        'colors': [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
        'image': 'https://porawat.github.io/app-ads/images/photo-7.jpg',
      },
      {
        'title': l10n.exploreConcert,
        'subtitle': l10n.exploreConcertSub,
        'query': l10n.exploreConcertQuery,
        'icon': Icons.stadium_rounded,
        'colors': [const Color(0xFF009688), const Color(0xFF4DB6AC)],
        'image': 'https://porawat.github.io/app-ads/images/photo-8.jpeg',
      },
    ];

    final isTablet = Responsive.isTablet(context);
    final crossAxisCount = Responsive.gridCrossAxisCount(
      context,
      phone: 2,
      tablet: 4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exploreTitle,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.exploreSubtitle,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: isTablet ? 24 : 16,
            mainAxisSpacing: isTablet ? 24 : 16,
            childAspectRatio: isTablet ? 1.3 : 1.1,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final colors = cat['colors'] as List<Color>;
            return GestureDetector(
              onTap: () {
                _searchController.text = cat['query'] as String;
                _onItemTapped(0); // Switch to search tab
                songProvider.search(_searchController.text);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Background Image with Fallback Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors[0].withValues(alpha: 0.8),
                              colors[1].withValues(alpha: 0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: cat['image'] as String,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // Dark Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.6),
                              Colors.black.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                color: Colors.white,
                                size: 28,
                              ),
                              if (_searchController.text == cat['query'])
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF15A24)
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      MiniEqualizer(
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Playing',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat['title'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat['subtitle'] as String,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
