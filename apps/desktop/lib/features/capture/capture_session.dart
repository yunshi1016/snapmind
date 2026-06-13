import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一次进行中的截图会话：已抓到的全屏图（物理像素）。
class CaptureSession {
  const CaptureSession({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
}

/// null = 空闲；非 null = 正在框选。
class CaptureSessionNotifier extends Notifier<CaptureSession?> {
  @override
  CaptureSession? build() => null;

  void start(CaptureSession session) => state = session;
  void end() => state = null;
}

final captureSessionProvider =
    NotifierProvider<CaptureSessionNotifier, CaptureSession?>(
      CaptureSessionNotifier.new,
    );
