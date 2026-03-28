import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/song.dart';
import '../widgets/song_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/app_logo.dart';
import '../services/song_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF777777), size: 22),
                onPressed: () {},
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
                  if (_selectedIndex == 2) ...[
                    const Text(
                      'คลังเพลงของคุณ',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedIndex == 0 && results.isNotEmpty) _buildPlaylistHeader(results, 'ผลการค้นหา'),
                  if (_selectedIndex == 2 && songProvider.favorites.isNotEmpty) _buildPlaylistHeader(songProvider.favorites, 'เพลงที่ชอบ'),
                  
                  if ((_selectedIndex == 0 && results.isNotEmpty) || (_selectedIndex == 2 && songProvider.favorites.isNotEmpty))
                    _buildActionButtons(songProvider, _selectedIndex == 0 ? results : songProvider.favorites),
                  
                  if ((_selectedIndex == 0 && results.isNotEmpty) || (_selectedIndex == 2 && songProvider.favorites.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF15A24),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'เพลงทั้งหมด',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFCCCCCC)),
                          ),
                        ],
                      ),
                    ),
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
          else if (_selectedIndex == 0 && results.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1),
                      ),
                      child: const AppLogo(size: 60, showText: false), // Show logo as an icon
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
          else if (_selectedIndex == 2 && songProvider.favorites.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1),
                      ),
                      child: const AppLogo(size: 60, showText: false), // Show logo in Favorites as well
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ยังไม่มีเพลงที่ถูกใจ',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กดหัวใจเพื่อเพิ่มเพลงที่ชอบ',
                      style: TextStyle(color: Color(0xFF444444), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final list = _selectedIndex == 0 ? results : songProvider.favorites;
                  final song = list[index];
                  final isFavorite = songProvider.favorites.any((s) => s.id == song.id);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: SongTile(
                      song: song,
                      isFavorite: isFavorite,
                      onFavoritePressed: () => songProvider.toggleFavorite(song),
                      onTap: () => songProvider.playSong(song, queue: list, index: index),
                    ),
                  );
                },
                childCount: _selectedIndex == 0 ? results.length : songProvider.favorites.length,
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
}
