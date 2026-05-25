// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get tabMusic => 'เพลง';

  @override
  String get tabExplore => 'สำรวจ';

  @override
  String get tabLocalFiles => 'ไฟล์เพลง';

  @override
  String get tabLibrary => 'คลังเพลง';

  @override
  String get searchHint => 'ค้นหาเพลง ศิลปิน หรือวาง YouTube URL';

  @override
  String get searching => 'กำลังค้นหา...';

  @override
  String get searchSongsArtistsOrLink =>
      'พิมพ์ชื่อเพลง ศิลปิน หรือวางลิงก์ YouTube';

  @override
  String get findSongsYouLike => 'ค้นหาเพลงที่คุณชอบ';

  @override
  String get recentlyPlayed => 'ฟังล่าสุด';

  @override
  String get clearHistory => 'ล้าง';

  @override
  String get clearHistoryTitle => 'ลบประวัติการเล่น';

  @override
  String get clearHistoryMessage =>
      'ต้องการลบประวัติการเล่นเพลงทั้งหมดหรือไม่?';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get delete => 'ลบ';

  @override
  String get clear => 'ล้าง';

  @override
  String get close => 'ปิด';

  @override
  String get create => 'สร้าง';

  @override
  String get yourLibrary => 'คลังเพลงของคุณ';

  @override
  String get favorites => 'เพลงที่ชอบ';

  @override
  String get favoriteSongs => 'เพลงที่ชอบ';

  @override
  String get noFavorites => 'ยังไม่มีเพลงที่ชอบ';

  @override
  String songCount(int count) {
    return '$count เพลง';
  }

  @override
  String get playAll => 'เล่นทั้งหมด';

  @override
  String get shufflePlay => 'สุ่มเพลง';

  @override
  String get allSongs => 'เพลงทั้งหมด';

  @override
  String get noSongPlaying => 'ไม่มีเพลงที่กำลังเล่นอยู่';

  @override
  String get nowPlaying => 'กำลังเล่น';

  @override
  String get upNext => 'รายการถัดไป';

  @override
  String get currentQueue => 'รายการเพลงที่เล่นอยู่';

  @override
  String get noSongsInQueue => 'ไม่มีเพลงในรายการ';

  @override
  String get lyrics => 'เนื้อเพลง';

  @override
  String get lyricsComingSoon => 'ฟีเจอร์เนื้อเพลงเร็วๆ นี้';

  @override
  String get addToPlaylist => 'เพิ่มลงในเพลย์ลิสต์';

  @override
  String get createNewPlaylist => 'สร้างเพลย์ลิสต์ใหม่';

  @override
  String get playlistNameHint => 'ชื่อเพลย์ลิสต์';

  @override
  String get noPlaylists => 'ยังไม่มีเพลย์ลิสต์';

  @override
  String addedToPlaylist(String name) {
    return 'เพิ่มลงใน \"$name\" แล้ว';
  }

  @override
  String createdAndAdded(String name) {
    return 'สร้างและเพิ่มลงใน \"$name\" แล้ว';
  }

  @override
  String playlistSongCount(int count) {
    return '$count เพลงในรายการ • สร้างเพื่อคุณ';
  }

  @override
  String get noSongsInPlaylist => 'ยังไม่มีเพลงในเพลย์ลิสต์นี้';

  @override
  String get deletePlaylist => 'ลบเพลย์ลิสต์';

  @override
  String get deletePlaylistMessage =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบเพลย์ลิสต์นี้? เพลงที่อยู่ในนี้จะถูกนำออกจากเพลย์ลิสต์ด้วย';

  @override
  String get playSong => 'เล่นเพลงนี้';

  @override
  String get removeFavorite => 'ลบออกจากเพลงที่ชอบ';

  @override
  String get addFavorite => 'เพิ่มในเพลงที่ชอบ';

  @override
  String get removeFromPlaylist => 'ลบออกจากเพลย์ลิสต์';

  @override
  String get share => 'แชร์';

  @override
  String get shareSong => 'แชร์เพลงนี้';

  @override
  String get songInfo => 'ข้อมูลเพลง';

  @override
  String get songTitle => 'ชื่อเพลง';

  @override
  String get artist => 'ศิลปิน';

  @override
  String get duration => 'ความยาว';

  @override
  String get eqTitle => 'ปรับแต่งเสียง';

  @override
  String get eqBassBoost => 'เร่งเบส';

  @override
  String get eqPresetNormal => 'ปกติ';

  @override
  String get eqPresetPop => 'ป๊อป';

  @override
  String get eqPresetClassic => 'คลาสสิก';

  @override
  String get eqPresetJazz => 'แจ๊ส';

  @override
  String get eqPresetRock => 'ร็อก';

  @override
  String get eqPresetCustom => 'กำหนดเอง';

  @override
  String get eqBandSubBass => 'ซับเบส';

  @override
  String get eqBandBass => 'เบส';

  @override
  String get eqBandLowMid => 'กลาง-ต่ำ';

  @override
  String get eqBandMid => 'กลาง';

  @override
  String get eqBandHighMid => 'กลาง-สูง';

  @override
  String get eqBandTreble => 'แหลม';

  @override
  String get eqBandBrilliance => 'ความใส';

  @override
  String get updateAvailable => 'มีอัปเดตใหม่!';

  @override
  String version(String version) {
    return 'เวอร์ชัน $version';
  }

  @override
  String get updateDetails => 'รายละเอียดการอัปเดต:';

  @override
  String get defaultReleaseNotes => '• ปรับปรุงประสิทธิภาพและแก้ไขข้อผิดพลาด';

  @override
  String get later => 'ไว้ทีหลัง';

  @override
  String get download => 'ดาวน์โหลด';

  @override
  String get downloading => 'กำลังดาวน์โหลด...';

  @override
  String downloadProgress(String received, String total) {
    return 'ดาวน์โหลด $received MB / $total MB';
  }

  @override
  String get downloadFailed => 'ดาวน์โหลดไม่สำเร็จ กรุณาลองใหม่';

  @override
  String get openingInstaller => 'กำลังเปิดหน้าติดตั้ง...';

  @override
  String get installPermissionRequired =>
      'กรุณาอนุญาต \"ติดตั้งแอปที่ไม่รู้จัก\" ในการตั้งค่าเพื่อดำเนินการต่อ';

  @override
  String get installFailed =>
      'ไม่สามารถเปิดตัวติดตั้งได้ กรุณาตรวจสอบสิทธิ์การติดตั้งแอปจากแหล่งที่ไม่รู้จัก';

  @override
  String voiceNoSound(String error) {
    return 'ไม่ได้ยินเสียง: $error';
  }

  @override
  String get voiceMicUnavailable => 'ไมโครโฟนไม่พร้อมใช้งาน';

  @override
  String get voiceListening => 'กำลังฟัง...';

  @override
  String get voiceTapToStop => 'แตะเพื่อหยุด';

  @override
  String get adminSystemUsers => 'ผู้ใช้งานระบบ';

  @override
  String adminOnlineCount(int count) {
    return 'ออนไลน์: $count คน';
  }

  @override
  String get adminNoUsers => 'ไม่มีผู้ใช้งานในขณะนี้';

  @override
  String adminUsageTime(String time) {
    return 'เวลาใช้งาน';
  }

  @override
  String adminHoursMinutes(int hours, int minutes) {
    return '$hours ชม. $minutes นาที';
  }

  @override
  String adminMinutes(int minutes) {
    return '$minutes นาที';
  }

  @override
  String get adminLoginInvalid => 'รหัสผ่านหรือชื่อผู้ใช้ไม่ถูกต้อง';

  @override
  String get adminLogin => 'เข้าสู่ระบบ';

  @override
  String get splashTagline => 'เพลงทุกอารมณ์ ฟังได้ทุกที่';

  @override
  String get splashLoading => 'กำลังโหลด...';

  @override
  String get cannotLoadChangelog => 'ไม่สามารถโหลด Changelog ได้';

  @override
  String get localMusic => 'เพลงจากเครื่อง';

  @override
  String get addFolder => 'เพิ่มโฟลเดอร์';

  @override
  String get addFiles => 'เพิ่มไฟล์';

  @override
  String get scanningFiles => 'กำลังอ่านไฟล์เพลง...';

  @override
  String localSongsCount(int count) {
    return '$count songs from device';
  }

  @override
  String get noLocalSongs => 'No local songs added yet';

  @override
  String get tapToAddLocalSongs =>
      'Tap \'Add Folder\' or \'Add Files\' to add songs';

  @override
  String get removeSong => 'ลบเพลง';

  @override
  String get clearAll => 'ล้างทั้งหมด';

  @override
  String get changelog => 'Changelog';

  @override
  String appVersion(String version) {
    return 'v$version';
  }

  @override
  String get localMusicTitle => 'ไฟล์เพลง';

  @override
  String get localMusicSubtitle => 'เพิ่มเพลงจากเครื่องหรือ USB Drive ของคุณ';

  @override
  String get noLocalSongsMessage => 'ยังไม่มีเพลงในเครื่อง';

  @override
  String get tapToAddLocalSongsMessage =>
      'กดปุ่มด้านบนเพื่อเพิ่มโฟลเดอร์หรือไฟล์เพลง';

  @override
  String get exploreHot => 'เพลงฮิตมาแรง';

  @override
  String exploreHotSub(int year) {
    return 'อัปเดตเพลงฮิตที่สุด $year';
  }

  @override
  String exploreHotQuery(Object year) {
    return 'เพลงใหม่มาแรง $year';
  }

  @override
  String get exploreRelax => 'ชิลๆ ฟีลคาเฟ่';

  @override
  String get exploreRelaxSub => 'เพลงฟังสบายตอนทำงาน';

  @override
  String exploreRelaxQuery(Object year) {
    return 'เพลงฟังสบาย คาเฟ่ $year';
  }

  @override
  String get exploreIndie => 'ลูกทุ่งอินดี้';

  @override
  String get exploreIndieSub => 'เพลงลูกทุ่งยอดฮิต 100 ล้านวิว';

  @override
  String get exploreIndieQuery => 'เพลงลูกทุ่งฮิตใหม่ล่าสุด';

  @override
  String get explorePop => 'ป๊อปสากลคูลๆ';

  @override
  String get explorePopSub => 'เพลงสากลฟังสบาย';

  @override
  String explorePopQuery(Object year) {
    return 'เพลงสากลยอดฮิต $year';
  }

  @override
  String get exploreRock => 'ร็อกมันส์ๆ';

  @override
  String get exploreRockSub => 'จัดเต็มทุกจังหวะ';

  @override
  String get exploreRockQuery => 'เพลงร็อกไทยยุค 90-ปัจจุบัน';

  @override
  String get exploreSad => 'เศร้าซึม';

  @override
  String get exploreSadSub => 'เพลงช้ากินใจ';

  @override
  String exploreSadQuery(Object year) {
    return 'เพลงเศร้า อกหัก $year';
  }

  @override
  String get exploreDance => 'เพลงเต้นตื๊ดๆ';

  @override
  String get exploreDanceSub => 'ปลุกพลังความสนุก';

  @override
  String exploreDanceQuery(Object year) {
    return 'เพลงแดนซ์ $year สายย่อ';
  }

  @override
  String get exploreConcert => 'คอนเสิร์ตฮิต';

  @override
  String get exploreConcertSub => 'การแสดงสดสุดมันส์';

  @override
  String get exploreConcertQuery => 'บันทึกการแสดงสด คอนเสิร์ต';

  @override
  String get adminDashboardTitle => 'ผู้ใช้งานระบบ';

  @override
  String get adminUser => 'ผู้ใช้';

  @override
  String get adminLastSeen => 'ล่าสุดเมื่อ';

  @override
  String get adminLoadingUsers => 'กำลังโหลดข้อมูลผู้ใช้...';

  @override
  String adminErrorLoading(String error) {
    return 'เกิดข้อผิดพลาดในการโหลดผู้ใช้: $error';
  }

  @override
  String get adminLoginTitle => 'แอดมินระบบ mPlay';

  @override
  String get usernameLabel => 'ชื่อผู้ใช้';

  @override
  String get passwordLabel => 'รหัสผ่าน';

  @override
  String adminUsedTimePrefix(String time) {
    return 'ใช้งานแล้ว: $time';
  }

  @override
  String get exploreTitle => 'สำรวจ';

  @override
  String get exploreSubtitle => 'พบกับแนวเพลงที่เหมาะกับอารมณ์ของคุณ';

  @override
  String get downloadSong => 'ดาวน์โหลด';

  @override
  String get downloadingSong => 'กำลังดาวน์โหลด...';

  @override
  String get downloadComplete => 'ดาวน์โหลดเสร็จ! เพิ่มลงในไฟล์เพลงแล้ว';

  @override
  String get downloadError => 'ดาวน์โหลดไม่สำเร็จ กรุณาลองใหม่';

  @override
  String get alreadyDownloaded => 'ดาวน์โหลดแล้ว';
}
