import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  int _selectedIndex = 0;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadVersion();
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
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ประวัติการอัปเดต',
            style: TextStyle(color: Colors.white, fontSize: 18),
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
              child: const Text(
                'ปิด',
                style: TextStyle(color: Color(0xFFF15A24)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลด Changelog ได้')),
      );
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
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // หน่วงเวลา 1 วินาทีหลังจากพิมพ์ตัวอักษรตัวสุดท้ายเสร็จ ถึงจะเริ่มค้นหา
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (query.isNotEmpty) {
        Provider.of<SongProvider>(context, listen: false).search(query);
      }
    });
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
                  children: const [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFF15A24),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Admin Login',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'changelog',
                child: Row(
                  children: const [
                    Icon(
                      Icons.history_edu_rounded,
                      color: Color(0xFFF15A24),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Change Log',
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
    return Container(
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
          onChanged: _onSearchChanged,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTablet ? 15 : 14,
            letterSpacing: 0.2,
          ),
          decoration: InputDecoration(
            hintText: 'ค้นหาเพลง ศิลปิน หรือวางลิงก์...',
            isDense: true,
            hintStyle: TextStyle(
              color: const Color(0xFF555555),
              fontSize: isTablet ? 15 : 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(
                Icons.search_rounded,
                color: const Color(0xFFF15A24),
                size: isTablet ? 26 : 22,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
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
                          _onSearchChanged('');
                        },
                      )
                    : const SizedBox.shrink();
              },
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
    );
  }

  Widget _buildSliverContent(SongProvider songProvider, List<Song> results) {
    final hPad = Responsive.hPadding(context);

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
                  // Always show inline search bar when index 0 (Home/Search)
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                ],
                if (_selectedIndex == 1) ...[_buildExploreTab(songProvider)],
                if (_selectedIndex == 2) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'คลังเพลงของคุณ',
                        style: TextStyle(
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
    final hPad = Responsive.hPadding(context);
    final maxW = Responsive.contentMaxWidth(context);
    final currentSong = songProvider.currentSong;
    List<Widget> slivers = [];

    // Loading State
    if (_selectedIndex == 0 && songProvider.isLoading) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFFF15A24),
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  'กำลังค้นหา...',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 13),
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
                const Text(
                  'ค้นหาเพลงที่คุณชอบ',
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'พิมพ์ชื่อเพลง ศิลปิน หรือวางลิงก์ YouTube',
                  style: TextStyle(color: Color(0xFF444444), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // 1. RECENTLY PLAYED SECTION (if no search results)
    if (_selectedIndex == 0 &&
        results.isEmpty &&
        songProvider.history.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
                child: Row(
                  children: const [
                    Icon(
                      Icons.history_rounded,
                      color: Color(0xFFF15A24),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'เล่นล่าสุด',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = songProvider.history[index];
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
                    isPlaying: currentSong?.id == song.id,
                    isFavorite: isFavorite,
                    onFavoritePressed: () => songProvider.toggleFavorite(song),
                    onTap: () => songProvider.playSong(
                      song,
                      queue: songProvider.history,
                      index: index,
                    ),
                  ),
                ),
              ),
            );
          }, childCount: songProvider.history.length),
        ),
      );
    }

    // 2. SEARCH RESULTS SECTION
    if (_selectedIndex == 0 && results.isNotEmpty) {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final song = results[index];
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
                    isPlaying: currentSong?.id == song.id,
                    isFavorite: isFavorite,
                    onFavoritePressed: () => songProvider.toggleFavorite(song),
                    onTap: () => songProvider.playSong(
                      song,
                      queue: results,
                      index: index,
                    ),
                  ),
                ),
              ),
            );
          }, childCount: results.length),
        ),
      );
    }

    return slivers;
  }

  Widget _buildBottomNav() {
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
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.home_filled, size: 22),
            ),
            label: 'หน้าแรก',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.explore_outlined, size: 22),
            ),
            label: 'สำรวจ',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Icon(Icons.library_music_outlined, size: 22),
            ),
            label: 'คลังเพลง',
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(SongProvider provider, List<Song> results) {
    final items = [
      Playlist(
        id: -1,
        name: 'เพลงที่ชอบ',
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
        crossAxisSpacing: isTablet ? 24 : 16,
        mainAxisSpacing: isTablet ? 24 : 16,
        childAspectRatio: isTablet ? 1.1 : 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final playlist = items[index];
        final isFavorite = playlist.id == -1;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistScreen(playlist: playlist),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF222222)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Container(
                      color: isFavorite
                          ? const Color(0xFFFF4466).withValues(alpha: 0.1)
                          : const Color(0xFF252525),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (playlist.songs.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: playlist.songs[0].maxResThumbnailUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  CachedNetworkImage(
                                    imageUrl: playlist.songs[0].hqThumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, err) =>
                                        Container(color: Colors.transparent),
                                  ),
                            ),
                          if (playlist.songs.isEmpty)
                            Center(
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.queue_music_rounded,
                                color: isFavorite
                                    ? const Color(0xFFFF4466)
                                    : const Color(0xFF777777),
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.songs.length} เพลง',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
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
    );
  }

  Widget _buildExploreTab(SongProvider songProvider) {
    // List of categories
    final categories = [
      {
        'title': 'เพลงฮิตมาแรง',
        'subtitle': 'อัปเดตเพลงฮิตที่สุด ${DateTime.now().year}',
        'query': 'เพลงใหม่มาแรง ${DateTime.now().year}',
        'icon': Icons.local_fire_department_rounded,
        'colors': [const Color(0xFFFF5722), const Color(0xFFFF9800)],
        'image': 'https://porawat.github.io/app-ads/images/photo-1.jpeg',
      },
      {
        'title': 'ชิลๆ ฟีลคาเฟ่',
        'subtitle': 'เพลงฟังสบายตอนทำงาน',
        'query': 'เพลงฟังสบาย คาเฟ่ ${DateTime.now().year}',
        'icon': Icons.coffee_rounded,
        'colors': [const Color(0xFF795548), const Color(0xFFA1887F)],
        'image': 'https://porawat.github.io/app-ads/images/photo-2.jpeg',
      },
      {
        'title': 'ลูกทุ่งอินดี้',
        'subtitle': 'เพลงลูกทุ่งยอดฮิต 100 ล้านวิว',
        'query': 'เพลงลูกทุ่งฮิตใหม่ล่าสุด',
        'icon': Icons.mic_external_on_rounded,
        'colors': [const Color(0xFFE91E63), const Color(0xFFF06292)],
        'image': 'https://porawat.github.io/app-ads/images/photo-3.jpeg',
      },
      {
        'title': 'ป๊อปสากลคูลๆ',
        'subtitle': 'เพลงสากลฟังสบาย',
        'query': 'เพลงสากลยอดฮิต ${DateTime.now().year}',
        'icon': Icons.public_rounded,
        'colors': [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
        'image': 'https://porawat.github.io/app-ads/images/photo-4.jpeg',
      },
      {
        'title': 'ร็อกมันส์ๆ',
        'subtitle': 'จัดเต็มทุกจังหวะ',
        'query': 'เพลงร็อกไทยยุค 90-ปัจจุบัน',
        'icon': Icons.electric_bolt_rounded,
        'colors': [const Color(0xFFF44336), const Color(0xFFEF5350)],
        'image': 'https://porawat.github.io/app-ads/images/photo-5.jpeg',
      },
      {
        'title': 'เศร้าซึม',
        'subtitle': 'เพลงช้ากินใจ',
        'query': 'เพลงเศร้า อกหัก ${DateTime.now().year}',
        'icon': Icons.water_drop_rounded,
        'colors': [const Color(0xFF3F51B5), const Color(0xFF7986CB)],
        'image': 'https://porawat.github.io/app-ads/images/photo-6.jpg',
      },
      {
        'title': 'เพลงเต้นตื๊ดๆ',
        'subtitle': 'ปลุกพลังความสนุก',
        'query': 'เพลงแดนซ์ ${DateTime.now().year} สายย่อ',
        'icon': Icons.speaker_group_rounded,
        'colors': [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
        'image': 'https://porawat.github.io/app-ads/images/photo-7.jpg',
      },
      {
        'title': 'คอนเสิร์ตฮิต',
        'subtitle': 'การแสดงสดสุดมันส์',
        'query': 'บันทึกการแสดงสด คอนเสิร์ต',
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
        const Text(
          'สำรวจ',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'พบกับแนวเพลงที่เหมาะกับอารมณ์ของคุณ',
          style: TextStyle(color: Color(0xFF888888), fontSize: 14),
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
                          Icon(
                            cat['icon'] as IconData,
                            color: Colors.white,
                            size: 28,
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
