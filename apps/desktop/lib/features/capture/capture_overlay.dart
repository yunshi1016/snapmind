import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 全屏 overlay：显示刚抓到的屏，拖拽框选。坐标在「逻辑像素」。
/// 性能：截图层放 RepaintBoundary 不重绘；选区层用 ValueNotifier 驱动 CustomPainter，
/// 拖拽时不触发 widget 重建。
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
  final ValueNotifier<Rect?> _selection = ValueNotifier<Rect?>(null);
  final FocusNode _focusNode = FocusNode();
  Offset? _start;
  Size _canvas = Size.zero;

  static const Color _brand = Color(0xFF8E7BFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _selection.dispose();
    super.dispose();
  }

  Offset _clamp(Offset o) =>
      Offset(o.dx.clamp(0.0, _canvas.width), o.dy.clamp(0.0, _canvas.height));

  void _onPanStart(DragStartDetails d) {
    _start = _clamp(d.localPosition);
    _selection.value = Rect.fromPoints(_start!, _start!);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_start == null) return;
    _selection.value = Rect.fromPoints(_start!, _clamp(d.localPosition));
  }

  void _onPanEnd(DragEndDetails d) {
    final r = _selection.value;
    if (r == null || r.width < 5 || r.height < 5) {
      widget.onCancel();
      return;
    }
    widget.onComplete(r, _canvas);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
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
          final scale =
              widget.imageWidth / (_canvas.width == 0 ? 1 : _canvas.width);
          return MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTap: widget.onCancel,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) {
                        // 截图加载失败：下一帧自动取消，避免卡在空 overlay。
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) widget.onCancel();
                        });
                        return const ColoredBox(color: Color(0xFF101014));
                      },
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SelectionPainter(_selection, scale, _brand),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: widget.onCancel,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xCC121216),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: const Text(
                          '取消 (Esc)',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.selection, this.scale, this.brand)
      : super(repaint: selection);

  final ValueListenable<Rect?> selection;
  final double scale;
  final Color brand;

  static final Paint _dim = Paint()..color = const Color(0x80000000);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = selection.value;
    if (rect == null) {
      canvas.drawRect(Offset.zero & size, _dim);
      _paintHint(canvas, size);
      return;
    }
    // 四块矩形遮罩（避免 saveLayer，省）
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), _dim);
    canvas.drawRect(
        Rect.fromLTRB(0, rect.bottom, size.width, size.height), _dim);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), _dim);
    canvas.drawRect(
        Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), _dim);
    // 边框
    canvas.drawRect(
      rect,
      Paint()
        ..color = brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _paintSizeLabel(canvas, rect);
  }

  void _paintSizeLabel(Canvas canvas, Rect rect) {
    final pw = (rect.width * scale).round();
    final ph = (rect.height * scale).round();
    final tp = TextPainter(
      text: TextSpan(
        text: '$pw × $ph',
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 6.0;
    final lx = rect.left;
    final ly = (rect.top - 24) < 0 ? rect.bottom + 6 : rect.top - 24;
    final bg = Rect.fromLTWH(lx, ly, tp.width + pad * 2, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(4)),
      Paint()..color = const Color(0xE6121216),
    );
    tp.paint(canvas, Offset(lx + pad, ly + 2));
  }

  void _paintHint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: const TextSpan(
        text: '拖拽框选要捕捉的区域    ·    Esc / 右键 取消',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padX = 16.0, padY = 10.0;
    final cx = size.width / 2;
    final cy = size.height * 0.2;
    final bg = Rect.fromCenter(
      center: Offset(cx, cy),
      width: tp.width + padX * 2,
      height: tp.height + padY * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(10)),
      Paint()..color = const Color(0xCC121216),
    );
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SelectionPainter old) =>
      old.scale != scale || old.brand != brand;
}
