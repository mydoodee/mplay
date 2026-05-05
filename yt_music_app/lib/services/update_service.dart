import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../config/api_config.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? '1.0.0',
      buildNumber: json['build_number'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
    );
  }
}

class DownloadResult {
  final String? path;
  final String? errorMessage;
  DownloadResult({this.path, this.errorMessage});
}

class UpdateService {
  static final Dio _dio = Dio();

  /// ตรวจสอบว่ามีอัปเดตใหม่หรือไม่
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(ApiConfig.updateUrl);
      if (response.statusCode == 200 &&
          response.data != null &&
          response.data.toString().isNotEmpty) {
        final Map<String, dynamic> data = response.data is String
            ? json.decode(response.data)
            : response.data;

        final updateInfo = AppUpdateInfo.fromJson(data);
        // Retrieve current build number
        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
        // Debug log for version comparison
        if (kDebugMode) {
          print(
            'Update check: fetched build ${updateInfo.buildNumber}, current build $currentBuild',
          );
        }
        if (updateInfo.buildNumber > currentBuild) {
          return updateInfo;
        } else {
          if (kDebugMode) {
            print(
              'No update needed. Current build $currentBuild >= fetched ${updateInfo.buildNumber}',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Update Check Error: $e');
    }
    return null;
  }

  /// ขอสิทธิ์ติดตั้ง APK — คืน false ถ้าผู้ใช้ปฏิเสธ
  static Future<bool> requestStoragePermission() async {
    // ไม่ต้องขอสิทธิ์ requestInstallPackages ล่วงหน้า เพราะอาจเกิดบั๊กเด้งกลับ (denied) ทันทีบน Android 14
    // ระบบ Android จะเด้งหน้าจอให้กดอนุญาตเองเมื่อเรียก OpenFilex
    return true;
  }

  /// ดาวน์โหลด APK
  static Future<DownloadResult> downloadApk({
    required String url,
    required Function(int received, int total) onReceiveProgress,
  }) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final savePath = '${dir.path}/app_update.apk';

      // ลบไฟล์เก่าก่อนดาวน์โหลด
      final file = File(savePath);
      if (await file.exists()) await file.delete();

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          responseType: ResponseType.bytes,
        ),
      );

      // ตรวจสอบว่าไฟล์ครบถ้วน
      final saved = File(savePath);
      if (!await saved.exists() || await saved.length() == 0) {
        if (kDebugMode) print('APK download failed or file empty');
        return DownloadResult(
          errorMessage: 'ดาวน์โหลดไฟล์ไม่สมบูรณ์ หรือไฟล์ว่างเปล่า',
        );
      }

      if (kDebugMode) {
        final mb = (await saved.length()) / 1024 / 1024;
        print('APK ready: $savePath (${mb.toStringAsFixed(2)} MB)');
      }

      return DownloadResult(path: savePath);
    } catch (e) {
      if (kDebugMode) print('Download APK Error: $e');
      return DownloadResult(errorMessage: 'เกิดข้อผิดพลาด: $e');
    }
  }

  /// เปิด Installer ด้วย MIME type ที่ถูกต้อง (ต้องมี FileProvider ใน AndroidManifest)
  static Future<bool> installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) print('APK not found at: $filePath');
        return false;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (kDebugMode) {
        print('OpenFilex → type:${result.type}  msg:${result.message}');
      }

      return result.type == ResultType.done;
    } catch (e) {
      if (kDebugMode) print('Install error: $e');
      return false;
    }
  }
}
