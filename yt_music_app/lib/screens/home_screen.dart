import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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
import 'equalizer_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        Provider.of<SongProvider>(context, listen: false).search(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final results = songProvider.searchResults;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // 🎵 Premium App Bar
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            pinned: true,
            backgroundColor: Colors.black,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const AppLogo(size: 26, showText: true), // Use AppLogo here
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF777777), size: 22),
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'equalizer') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EqualizerScreen()),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'equalizer',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text('ปรับ Equalizer', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedIndex == 0) ...[
                    // 🎵 Premium Search Bar
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF222222), width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาเพลง ศิลปิน หรือวางลิงก์...',
                          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFF15A24), size: 22),
                          filled: true,
                          fillColor: const Color(0xFF111111),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFF15A24), width: 1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedIndex == 1) ...[
                    _buildExploreTab(songProvider),
                  ],
                  if (_selectedIndex == 2) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'คลังเพลงของคุณ',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, color: Color(0xFFF15A24)),
                          onPressed: () => PlaylistUtils.showCreatePlaylistDialog(context, songProvider),
                        ),

                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPlaylistsGrid(songProvider),
                  ],

                ],
              ),
            ),
          ),
          if (_selectedIndex == 0 && songProvider.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFF15A24), strokeWidth: 2.5),
                    SizedBox(height: 16),
                    Text('กำลังค้นหา...', style: TextStyle(color: Color(0xFF777777), fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_selectedIndex == 0 && results.isEmpty && songProvider.history.isEmpty)
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
                        child: const AppLogo(size: 60, showText: false), // Show logo as an icon
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ค้นหาเพลงที่คุณชอบ',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'พิมพ์ชื่อเพลง ศิลปิน หรือวางลิงก์ YouTube',
                      style: TextStyle(color: Color(0xFF444444), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (_selectedIndex == 0 && results.isEmpty && songProvider.history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFFF15A24), size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'เล่นล่าสุด',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songProvider.history[index];
                  final isFavorite = songProvider.favorites.any((s) => s.id == song.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SongTile(
                      song: song,
                      isPlaying: songProvider.currentSong?.id == song.id,
                      isFavorite: isFavorite,
                      onFavoritePressed: () => songProvider.toggleFavorite(song),
                      onTap: () => songProvider.playSong(song, queue: songProvider.history, index: index),
                    ),
                  );
                },
                childCount: songProvider.history.length,
              ),
            ),
          ]
          else if (_selectedIndex == 0)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final list = results;
                  final song = list[index];
                  final isFavorite = songProvider.favorites.any((s) => s.id == song.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: SongTile(
                      song: song,
                      isPlaying: songProvider.currentSong?.id == song.id,
                      isFavorite: isFavorite,
                      onFavoritePressed: () => songProvider.toggleFavorite(song),
                      onTap: () => songProvider.playSong(song, queue: list, index: index),
                    ),
                  );
                },
                childCount: results.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      bottomSheet: const MiniPlayer(),
    );
  }

  Widget _buildPlaylistHeader(List<Song> results, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'playlist_art_$title',
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF1A1A1A),
                image: results[0].thumbnail != "NA" && results[0].thumbnail.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(results[0].thumbnail),
                      fit: BoxFit.cover,
                    )
                  : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: (results[0].thumbnail == "NA" || results[0].thumbnail.isEmpty)
                  ? const Center(child: AppLogo(size: 24, showText: false))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${results.length} เพลงในรายการ',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SongProvider provider, List<Song> songs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF15A24), Color(0xFFED1C24)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () => provider.playAll(songs),
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                label: const Text('เล่นทั้งหมด', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => provider.shuffleAll(songs),
              icon: const Icon(Icons.shuffle_rounded, color: Color(0xFFCCCCCC), size: 20),
              label: const Text('สุ่มเพลง', style: TextStyle(color: Color(0xFFCCCCCC), fontWeight: FontWeight.w600, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF333333)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_filled, size: 22)), label: 'หน้าแรก'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.explore_outlined, size: 22)), label: 'สำรวจ'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.library_music_outlined, size: 22)), label: 'คลังเพลง'),
        ],
      ),
    );
  }

  Widget _buildPlaylistsGrid(SongProvider provider) {
    // 1st item = Favorites, rest = Custom Playlists
    final items = [
      Playlist(id: -1, name: 'เพลงที่ชอบ', createdAt: '', songs: provider.favorites),
      ...provider.playlists,
    ];


    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: isFavorite ? const Color(0xFFFF4466).withValues(alpha: 0.1) : const Color(0xFF252525),
                      image: playlist.songs.isNotEmpty && playlist.songs[0].thumbnail != "NA" && playlist.songs[0].thumbnail.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(playlist.songs[0].thumbnail),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (playlist.songs.isEmpty || playlist.songs[0].thumbnail == "NA" || playlist.songs[0].thumbnail.isEmpty)
                        ? Center(
                            child: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.queue_music_rounded,
                              color: isFavorite ? const Color(0xFFFF4466) : const Color(0xFF777777),
                              size: 40,
                            ),
                          )
                        : null,
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
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.songs.length} เพลง',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
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
        'subtitle': 'อัปเดตเพลงฮิตที่สุด',
        'query': 'Thailand Top 50 Official Playlist',
        'icon': Icons.local_fire_department_rounded,
        'colors': [const Color(0xFFFF5722), const Color(0xFFFF9800)],
      },
      {
        'title': 'ชิลๆ ฟีลคาเฟ่',
        'subtitle': 'เพลงฟังสบายตอนทำงาน',
        'query': 'เพลงฟังสบาย คาเฟ่ playlist',
        'icon': Icons.coffee_rounded,
        'colors': [const Color(0xFF795548), const Color(0xFFA1887F)],
      },
      {
        'title': 'ลูกทุ่งอินดี้',
        'subtitle': 'เพลงลูกทุ่งยอดฮิต 100 ล้านวิว',
        'query': 'เพลงลูกทุ่งฮิต 100 ล้านวิว Playlist',
        'icon': Icons.mic_external_on_rounded,
        'colors': [const Color(0xFFE91E63), const Color(0xFFF06292)],
      },
      {
        'title': 'ป๊อปสากลคูลๆ',
        'subtitle': 'เพลงสากลฟังสบาย',
        'query': 'Top pop hits playlist',
        'icon': Icons.public_rounded,
        'colors': [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
      },
      {
        'title': 'ร็อกมันส์ๆ',
        'subtitle': 'จัดเต็มทุกจังหวะ',
        'query': 'Thai Rock hits playlist',
        'icon': Icons.electric_bolt_rounded,
        'colors': [const Color(0xFFF44336), const Color(0xFFEF5350)],
      },
      {
        'title': 'เศร้าซึม',
        'subtitle': 'เพลงช้ากินใจ',
        'query': 'เพลงเศร้า อกหัก Playlist',
        'icon': Icons.water_drop_rounded,
        'colors': [const Color(0xFF3F51B5), const Color(0xFF7986CB)],
      },
      {
        'title': 'เพลงเต้นตื๊ดๆ',
        'subtitle': 'ปลุกพลังความสนุก',
        'query': 'เพลงแดนซ์ สายย่อ Playlist EDM',
        'icon': Icons.speaker_group_rounded,
        'colors': [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
      },
      {
        'title': 'คอนเสิร์ตฮิต',
        'subtitle': 'การแสดงสดสุดมันส์',
        'query': 'Live Concert Full Show',
        'icon': Icons.stadium_rounded,
        'colors': [const Color(0xFF009688), const Color(0xFF4DB6AC)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สำรวจ',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colors[0].withValues(alpha: 0.8),
                      colors[1].withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: colors[0].withValues(alpha: 0.4), width: 1),
                  boxShadow: [
                    BoxShadow(color: colors[0].withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 0),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(cat['icon'] as IconData, color: Colors.white, size: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat['title'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat['subtitle'] as String,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
