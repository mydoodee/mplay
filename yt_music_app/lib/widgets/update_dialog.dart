import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _startDownload() async {
    // ขอสิทธิ์ติดตั้ง APK
    final hasPermission = await UpdateService.requestStoragePermission();
    if (!hasPermission && mounted) {
      setState(() {
        _isDownloading = false;
        _statusMessage =
            'กรุณาอนุญาต "ติดตั้งแอปที่ไม่รู้จัก" ในการตั้งค่าเพื่อดำเนินการต่อ';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = 'กำลังดาวน์โหลด...';
    });

    final apkPath = await UpdateService.downloadApk(
      url: widget.updateInfo.downloadUrl,
      onReceiveProgress: (received, total) {
        if (total != -1 && mounted) {
          setState(() {
            _progress = received / total;
            _statusMessage =
                'ดาวน์โหลด ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
          });
        }
      },
    );

    if (apkPath == null) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'ดาวน์โหลดไม่สำเร็จ กรุณาลองใหม่';
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _statusMessage = 'กำลังเปิดหน้าติดตั้ง...');
    }

    final installed = await UpdateService.installApk(apkPath);
    if (mounted) {
      if (installed) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isDownloading = false;
          _statusMessage =
              'ไม่สามารถเปิดตัวติดตั้งได้ กรุณาตรวจสอบสิทธิ์การติดตั้งแอปจากแหล่งที่ไม่รู้จัก';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF15A24).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFFF15A24),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'มีอัปเดตใหม่!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เวอร์ชัน ${widget.updateInfo.latestVersion}',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายละเอียดการอัปเดต:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.updateInfo.releaseNotes.isEmpty 
                        ? '• ปรับปรุงประสิทธิภาพและแก้ไขข้อผิดพลาด'
                        : widget.updateInfo.releaseNotes,
                    style: const TextStyle(
                      color: Color(0xFFCCCCCC),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFF333333),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF15A24)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ),
            ] else ...[
              if (_statusMessage.isNotEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ไว้ทีหลัง',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF15A24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ดาวน์โหลด',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
