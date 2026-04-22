import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────
///  Responsive helper สำหรับ M-PLAY
///  Breakpoint: shortestSide >= 600  → Tablet
/// ─────────────────────────────────────────────
class Responsive {
  Responsive._();

  /// คืนค่า true เมื่อรันบน Tablet (shortestSide >= 600)
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600;

  /// ความกว้างสูงสุดของ content กลางหน้าจอ
  static double contentMaxWidth(BuildContext context) => double.infinity;

  /// Horizontal padding สำหรับ list / content
  static double hPadding(BuildContext context) =>
      isTablet(context) ? 24.0 : 16.0;

  /// จำนวน column ของ GridView
  static int gridCrossAxisCount(
    BuildContext context, {
    int phone = 2,
    int tablet = 4,
  }) =>
      isTablet(context) ? tablet : phone;

  /// ขนาด thumbnail ใน SongTile
  static double thumbnailWidth(BuildContext context) =>
      isTablet(context) ? 160.0 : 120.0;

  static double thumbnailHeight(BuildContext context) =>
      isTablet(context) ? 90.0 : 68.0;

  /// ขนาด font สำหรับชื่อเพลงใน SongTile
  static double songTitleFontSize(BuildContext context) =>
      isTablet(context) ? 15.0 : 13.0;

  static double songArtistFontSize(BuildContext context) =>
      isTablet(context) ? 13.0 : 11.5;

  /// height ของ MiniPlayer
  static double miniPlayerHeight(BuildContext context) =>
      isTablet(context) ? 80.0 : 68.0;

  /// ขนาด album art thumbnail ใน MiniPlayer
  static double miniAlbumArtSize(BuildContext context) =>
      isTablet(context) ? 56.0 : 44.0;

  /// ขนาด font ใน MiniPlayer
  static double miniTitleFontSize(BuildContext context) =>
      isTablet(context) ? 15.0 : 13.0;

  static double miniArtistFontSize(BuildContext context) =>
      isTablet(context) ? 13.0 : 11.0;

  /// ──── Player Screen ────

  /// คืนค่า true เมื่อควรใช้ landscape/two-panel layout ใน PlayerScreen
  static bool usePlayerLandscapeLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Tablet + landscape หรือ Tablet + portrait ที่กว้างพอ
    return size.shortestSide >= 600 && size.width > size.height;
  }

  /// ──── Navigation ────

  /// คืนค่า true เมื่อควรใช้ NavigationRail แทน BottomNavigationBar
  static bool useNavigationRail(BuildContext context) => isTablet(context);
}
