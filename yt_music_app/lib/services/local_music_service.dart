import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/song.dart';

/// Service สำหรับจัดการเพลงจากไฟล์ในเครื่อง / USB Drive
class LocalMusicService {
  static final LocalMusicService _instance = LocalMusicService._internal();
  factory LocalMusicService() => _instance;
  LocalMusicService._internal();

  // นามสกุลไฟล์เพลงที่รองรับ
  static const Set<String> supportedExtensions = {
    '.mp3', '.m4a', '.flac', '.wav', '.ogg',
  };

  /// ขอ Permission เข้าถึง storage
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) return true;

      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;

      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus.isGranted;
    }
    return true;
  }

  /// ให้ User เลือกโฟลเดอร์ แล้วสแกนเพลงในโฟลเดอร์นั้น
  Future<List<Song>> pickFolderAndScan() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final selectedDirectory = await FilePicker.getDirectoryPath();
    if (selectedDirectory == null) return [];

    return await scanDirectory(selectedDirectory);
  }

  /// ให้ User เลือกไฟล์เพลง
  Future<List<Song>> pickFiles() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return [];

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'flac', 'wav', 'ogg'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return [];

    final songs = <Song>[];
    for (final file in result.files) {
      if (file.path != null) {
        final song = await _extractMetadata(file.path!);
        if (song != null) songs.add(song);
      }
    }
    return songs;
  }

  /// สแกนไฟล์เพลงในโฟลเดอร์ (recursive)
  Future<List<Song>> scanDirectory(String dirPath) async {
    final songs = <Song>[];
    final dir = Directory(dirPath);

    if (!await dir.exists()) return songs;

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.toLowerCase();
          final isAudioFile = supportedExtensions.any((e) => ext.endsWith(e));
          if (isAudioFile) {
            final song = await _extractMetadata(entity.path);
            if (song != null) songs.add(song);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('LocalMusicService: Error scanning $dirPath: $e');
      }
    }

    songs.sort((a, b) => a.title.compareTo(b.title));
    return songs;
  }

  /// อ่าน metadata จากไฟล์เพลง (ID3 tag) โดยใช้ audiotags
  Future<Song?> _extractMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // อ่าน metadata ผ่าน audiotags
      final tag = await AudioTags.read(filePath);

      // ดึงชื่อเพลง — ถ้าไม่มี ID3 tag ใช้ชื่อไฟล์แทน
      final fileName = file.uri.pathSegments.last;
      final nameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      final trackName = (tag?.title != null && tag!.title!.isNotEmpty)
          ? tag.title!
          : nameWithoutExt;

      // ดึงชื่อศิลปิน
      final artist = (tag?.trackArtist != null && tag!.trackArtist!.isNotEmpty)
          ? tag.trackArtist!
          : 'Unknown Artist';

      // ดึง album art (audiotags ใช้ list of Picture)
      Uint8List? coverArt;
      if (tag != null && tag.pictures.isNotEmpty) {
        coverArt = tag.pictures.first.bytes;
      }

      return Song.fromLocalFile(
        filePath: filePath,
        title: trackName,
        artist: artist,
        duration: 0, // audiotags 1.4.0 อาจไม่ได้คืน duration โดยตรงในบางไฟล์ ให้ player จัดการ
        coverArtBytes: coverArt,
      );
    } catch (e) {
      if (kDebugMode) {
        print('LocalMusicService: Error reading metadata for $filePath: $e');
      }
      try {
        final fileName = File(filePath).uri.pathSegments.last;
        final nameWithoutExt = fileName.contains('.')
            ? fileName.substring(0, fileName.lastIndexOf('.'))
            : fileName;
        return Song.fromLocalFile(
          filePath: filePath,
          title: nameWithoutExt,
        );
      } catch (_) {
        return null;
      }
    }
  }
}
