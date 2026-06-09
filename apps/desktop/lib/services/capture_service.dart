import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_capturer/screen_capturer.dart';

/// 一张全屏截图（物理像素）。
class FullScreenShot {
  const FullScreenShot({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final int width;
  final int height;
}

/// 屏幕抓取 + 备份目录管理。截图相关原生能力（v1 仅 Windows）。
class CaptureService {
  const CaptureService();

  /// 抓全屏到临时 PNG，返回路径与物理像素尺寸。失败返回 null。
  Future<FullScreenShot?> captureFullScreen() async {
    final tmp = await getTemporaryDirectory();
    final path = p.join(
      tmp.path,
      'snapmind_shot_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    final captured = await screenCapturer.capture(
      mode: CaptureMode.screen,
      imagePath: path,
      copyToClipboard: false,
      silent: true,
    );
    final outPath = captured?.imagePath ?? path;
    final file = File(outPath);
    if (!await file.exists()) return null;
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) return null;
    return FullScreenShot(path: outPath, width: decoded.width, height: decoded.height);
  }

  /// 解析有效备份目录：设置留空时用默认 %LOCALAPPDATA%\SnapMind\Screenshots，并确保存在。
  Future<Directory> resolveBackupDir(String configured) async {
    String base;
    if (configured.trim().isNotEmpty) {
      base = configured.trim();
    } else {
      final local = Platform.environment['LOCALAPPDATA'] ??
          (await getApplicationSupportDirectory()).path;
      base = p.join(local, 'SnapMind', 'Screenshots');
    }
    final dir = Directory(base);
    await dir.create(recursive: true);
    return dir;
  }

  /// 生成带时间戳的备份文件名。
  String backupFileName([DateTime? at]) {
    final now = at ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'SnapMind_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.png';
  }

  /// 把已有 PNG 文件复制到备份目录，返回最终路径。
  Future<String> copyToBackup(String sourcePath, String backupDirConfigured) async {
    final dir = await resolveBackupDir(backupDirConfigured);
    final dest = p.join(dir.path, backupFileName());
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// 把内存中的 PNG 字节写入备份目录，返回最终路径。
  Future<String> savePngBytesToBackup(
    List<int> pngBytes,
    String backupDirConfigured,
  ) async {
    final dir = await resolveBackupDir(backupDirConfigured);
    final dest = p.join(dir.path, backupFileName());
    await File(dest).writeAsBytes(pngBytes, flush: true);
    return dest;
  }

  /// 裁剪结果。
  Future<CropResult> cropAndSaveToBackup({
    required String sourcePath,
    required int x,
    required int y,
    required int width,
    required int height,
    required String backupDirConfigured,
  }) async {
    final src = img.decodeImage(await File(sourcePath).readAsBytes());
    if (src == null) throw StateError('无法解码截图');
    final cropped = img.copyCrop(src, x: x, y: y, width: width, height: height);
    final pngBytes = img.encodePng(cropped);
    final path = await savePngBytesToBackup(pngBytes, backupDirConfigured);
    return CropResult(path: path, width: width, height: height, pngBytes: pngBytes);
  }
}

class CropResult {
  const CropResult({
    required this.path,
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final String path;
  final int width;
  final int height;
  final List<int> pngBytes;
}
