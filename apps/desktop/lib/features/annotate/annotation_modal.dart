import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import 'annotation.dart';

/// 截图裁剪后的批注浮窗内容：铺满无边框小窗，缩略图 + 「我的想法」(撑满) + 保存/取消。
class AnnotationModal extends StatefulWidget {
  const AnnotationModal({
    super.key,
    required this.pending,
    required this.onSave,
    required this.onCancel,
    this.saving = false,
  });

  final PendingCapture pending;
  final void Function(String note) onSave;
  final VoidCallback onCancel;
  final bool saving;

  @override
  State<AnnotationModal> createState() => _AnnotationModalState();
}

class _AnnotationModalState extends State<AnnotationModal> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => widget.onSave(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final p = widget.pending;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Container(
        color: const Color(0xFF111116),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  FluentIcons.edit,
                  size: 18,
                  color: Color(0xFF9C8FFF),
                ),
                const SizedBox(width: 8),
                const Text(
                  '记下你的想法',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${p.width}×${p.height}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x88FFFFFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1AFFFFFF)),
                color: const Color(0x22000000),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                p.croppedPng,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '我的想法',
              style: TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: TextBox(
                controller: _controller,
                autofocus: true,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                placeholder: '看到这个，我想到…（Ctrl+Enter 保存）',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Button(
                  onPressed: widget.saving ? null : widget.onCancel,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.saving) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          const Text('保存中…'),
                        ] else
                          const Text('保存到 Obsidian'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
