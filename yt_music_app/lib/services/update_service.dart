import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
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

class UpdateService {
  static final Dio _dio = Dio();

  /// ตรวจสอบว่ามีอัปเดตใหม่หรือไม่
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(ApiConfig.updateUrl);
      if (response.statusCode == 200 && response.data != null && response.data.toString().isNotEmpty) {
        final Map<String, dynamic> data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
            
        final updateInfo = AppUpdateInfo.fromJson(data);
        
        // เช็คกับเวอร์ชันปัจจุบัน
        final packageInfo = await PackageInfo.fromPlatform();
        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

        // ถ้า build_number ในเซิร์ฟเวอร์ใหม่กว่า แสดงว่ามีอัปเดต
        if (updateInfo.buildNumber > currentBuild) {
          return updateInfo;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Update Check Error: $e');
      }
    }
    return null;
  }

  /// ขอสิทธิ์ Storage (จำเป็นสำหรับเซฟไฟล์)
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // ใน Android 13+ (API 33) การขอ Permission.storage จะถูกปฏิเสธเสมอ
      // แต่เราสามารถเขียนไฟล์ลงใน App Cache/External Cache ได้โดยไม่ต้องขอสิทธิ์
      // ดังนั้นเราจะขอแค่สิทธิ์ติดตั้ง (ถ้ายังไม่ได้ขอ) และคืนค่า true เพื่อให้ดาวน์โหลดต่อได้
      await Permission.requestInstallPackages.request();
      return true; 
    }
    return true;
  }

  /// ดาวน์โหลดไฟล์ APK 
  static Future<String?> downloadApk({
    required String url,
    required Function(int received, int total) onReceiveProgress,
  }) async {
    try {
      // ขอสิทธิ์ติดตั้งแพ็กเกจ (เผื่อไว้)
      if (Platform.isAndroid) {
        await Permission.requestInstallPackages.request();
      }

      // หาที่เซฟไฟล์ (ใช้ External Cache จะได้ไม่รกเครื่อง)
      Directory? dir;
      if (Platform.isAndroid) {
        dir = await getExternalCacheDirectories().then((dirs) => dirs?.first);
      } else {
        dir = await getTemporaryDirectory();
      }
      
      if (dir == null) return null;
      
      final savePath = '${dir.path}/app_update.apk';
      
      // ลบไฟล์เก่าทิ้งถ้ามี
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          responseType: ResponseType.bytes,
        ),
      );

      return savePath;
    } catch (e) {
      if (kDebugMode) {
        print('Download APK Error: $e');
      }
      return null;
    }
  }

  /// ติดตั้ง APK
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (kDebugMode) {
        print('Install result: ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Install execution error: $e');
      }
    }
  }
}
