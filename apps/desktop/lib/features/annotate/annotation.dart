import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一条待批注的捕获：已裁剪并存入备份目录，等待用户写下想法。
class PendingCapture {
  const PendingCapture({
    required this.croppedPng,
    required this.screenshotPath,
    required this.width,
    required this.height,
    required this.createdAt,
  });

  final Uint8List croppedPng; // 缩略图用
  final String screenshotPath; // 备份路径
  final int width;
  final int height;
  final DateTime createdAt;
}

/// null = 无待批注；非 null = 批注窗显示中。
class AnnotationNotifier extends Notifier<PendingCapture?> {
  @override
  PendingCapture? build() => null;

  void start(PendingCapture pending) => state = pending;
  void clear() => state = null;
}

final annotationProvider =
    NotifierProvider<AnnotationNotifier, PendingCapture?>(
  AnnotationNotifier.new,
);
