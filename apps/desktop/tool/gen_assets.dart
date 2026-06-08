// 从品牌图标源图生成：透明 logo.png + 多尺寸 .ico（托盘 / 应用图标）。
// 运行：dart run tool/gen_assets.dart
import 'dart:typed_data';
import 'dart:io';

import 'package:image/image.dart' as img;

const String _src = r'F:\CodingProjects\snapmind\brand\logo_icon_source.png';
const String _logoOut = r'F:\CodingProjects\snapmind\apps\desktop\assets\logo.png';
const String _trayOut = r'F:\CodingProjects\snapmind\apps\desktop\assets\tray_icon.ico';
const String _appIconOut =
    r'F:\CodingProjects\snapmind\apps\desktop\windows\runner\resources\app_icon.ico';

/// 近白判定（三通道都很亮 = 背景），阈值略低以吃掉抗锯齿边缘的浅灰halo。
bool _isBg(img.Pixel p) => p.r > 224 && p.g > 224 && p.b > 224;

/// 从四边种子做边界 flood-fill，把与边缘相连的近白像素设为透明。
void _removeBorderBackground(img.Image im) {
  final w = im.width, h = im.height;
  final visited = Uint8List(w * h);
  final stack = <int>[];
  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final idx = y * w + x;
    if (visited[idx] == 1) return;
    visited[idx] = 1;
    stack.add(idx);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (stack.isNotEmpty) {
    final idx = stack.removeLast();
    final x = idx % w, y = idx ~/ w;
    if (!_isBg(im.getPixel(x, y))) continue; // 触到图标边界，停止扩散
    im.setPixelRgba(x, y, 0, 0, 0, 0);
    push(x + 1, y);
    push(x - 1, y);
    push(x, y + 1);
    push(x, y - 1);
  }
}

void main() {
  var im = img.decodePng(File(_src).readAsBytesSync())!;
  if (im.numChannels != 4) im = im.convert(numChannels: 4);

  _removeBorderBackground(im);

  // 裁掉完全透明的外边，补成正方形并留少量边距。
  final trimmed = img.trim(im, mode: img.TrimMode.transparent);
  final side = trimmed.width > trimmed.height ? trimmed.width : trimmed.height;
  final canvasSide = (side * 1.08).round();
  final canvas = img.Image(width: canvasSide, height: canvasSide, numChannels: 4);
  img.compositeImage(
    canvas,
    trimmed,
    dstX: ((canvasSide - trimmed.width) / 2).round(),
    dstY: ((canvasSide - trimmed.height) / 2).round(),
  );

  File(_logoOut).writeAsBytesSync(img.encodePng(
      img.copyResize(canvas, width: 512, height: 512, interpolation: img.Interpolation.cubic)));

  const sizes = [16, 24, 32, 48, 64, 128, 256];
  final icoImages = [
    for (final s in sizes)
      img.copyResize(canvas, width: s, height: s, interpolation: img.Interpolation.cubic)
  ];
  final icoBytes = img.IcoEncoder().encodeImages(icoImages);
  File(_trayOut).writeAsBytesSync(icoBytes);
  File(_appIconOut).writeAsBytesSync(icoBytes);

  stdout.writeln('OK  trimmed=${trimmed.width}x${trimmed.height}  canvas=$canvasSide');
}
