import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 全屏透明 overlay：显示刚抓到的屏，拖拽框选一个矩形。
/// 坐标全部在「逻辑像素」，裁剪时由调用方用 图像像素/画布逻辑 的比例换算。
class CaptureOverlay extends StatefulWidget {
  const CaptureOverlay({
    super.key,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.onComplete,
    required this.onCancel,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final void Function(Rect logicalRect, Size canvasSize) onComplete;
  final VoidCallback onCancel;

  @override
  State<CaptureOverlay> createState() => _CaptureOverlayState();
}

class _CaptureOverlayState extends State<CaptureOverlay> {
  Offset? _start;
  Offset? _current;
  Size _canvas = Size.zero;

  static const Color _brand = Color(0xFF8E7BFF);

  Rect? get _rect {
    final s = _start, c = _current;
    if (s == null || c == null) return null;
    return Rect.fromPoints(s, c);
  }

  Offset _clamp(Offset o) =>
      Offset(o.dx.clamp(0.0, _canvas.width), o.dy.clamp(0.0, _canvas.height));

  void _finish() {
    final r = _rect;
    if (r == null || r.width < 5 || r.height < 5) {
      widget.onCancel();
      return;
    }
    widget.onComplete(r, _canvas);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _canvas = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTap: widget.onCancel,
              onPanStart: (d) => setState(() {
                _start = _clamp(d.localPosition);
                _current = _start;
              }),
              onPanUpdate: (d) =>
                  setState(() => _current = _clamp(d.localPosition)),
              onPanEnd: (_) => _finish(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                  CustomPaint(painter: _DimSelectionPainter(_rect, _brand)),
                  if (_rect != null) _sizeLabel(_rect!),
                  if (_start == null) const _Hint(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sizeLabel(Rect r) {
    final scaleX = widget.imageWidth / (_canvas.width == 0 ? 1 : _canvas.width);
    final scaleY = widget.imageHeight / (_canvas.height == 0 ? 1 : _canvas.height);
    final pw = (r.width * scaleX).round();
    final ph = (r.height * scaleY).round();
    final top = r.top - 30 < 0 ? r.bottom + 6 : r.top - 30;
    return Positioned(
      left: r.left.clamp(0.0, _canvas.width - 110),
      top: top.clamp(0.0, _canvas.height - 26),
      child: _Pill(text: '$pw × $ph px'),
    );
  }
}

class _DimSelectionPainter extends CustomPainter {
  _DimSelectionPainter(this.rect, this.brand);

  final Rect? rect;
  final Color brand;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final dim = Paint()..color = const Color(0x80000000);
    if (rect == null) {
      canvas.drawRect(full, dim);
      return;
    }
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, dim);
    canvas.drawRect(rect!, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRect(
      rect!,
      Paint()
        ..color = brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_DimSelectionPainter old) => old.rect != rect;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6121216),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC121216),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: const Text(
          '拖拽框选要捕捉的区域   ·   Esc / 右键 取消',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
