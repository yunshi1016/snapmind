import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/capture_record.dart';
import '../../providers.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyListProvider);
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('历史'),
        commandBar: IconButton(
          icon: const Icon(FluentIcons.refresh),
          onPressed: () => ref.invalidate(historyListProvider),
        ),
      ),
      content: async.when(
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (list) => list.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: list.length,
                separatorBuilder: (_, i) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HistoryTile(record: list[i]),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.history,
            size: 40,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            '还没有捕获记录\n按 Ctrl+Shift+1 截一张试试',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.record});

  final CaptureRecord record;

  String _time(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _open(BuildContext context) async {
    final md = record.markdownPath;
    if (md.isEmpty || !File(md).existsSync()) {
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: const Text('笔记不存在'),
          content: Text(md.isEmpty ? '未记录路径' : '可能已被移动或删除：$md'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }
    // 优先用 Obsidian 协议打开（vault + vault 内相对路径，去 .md 后缀）。
    if (record.vaultPath.isNotEmpty) {
      var rel = p.relative(md, from: record.vaultPath).replaceAll(r'\', '/');
      if (rel.toLowerCase().endsWith('.md')) {
        rel = rel.substring(0, rel.length - 3);
      }
      final uri = Uri.parse(
        'obsidian://open?vault=${Uri.encodeComponent(p.basename(record.vaultPath))}'
        '&file=${Uri.encodeComponent(rel)}',
      );
      if (await launchUrl(uri)) return;
    }
    // 兜底：系统默认程序打开文件。
    await launchUrl(Uri.file(md));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('删除这条笔记？'),
        content: Text(
          '将从历史记录中移除，并删除 Obsidian 里对应的笔记文件：\n${p.basename(record.markdownPath)}\n\n此操作不可撤销。',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red.darker),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (record.markdownPath.isNotEmpty) {
      try {
        final f = File(record.markdownPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await ref.read(historyServiceProvider).delete(record.id);
    ref.invalidate(historyListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = [
      record.sourceApp,
      record.sourceWindowTitle,
    ].where((e) => e.trim().isNotEmpty).join(' · ');
    return HoverButton(
      onPressed: () => _open(context),
      builder: (context, states) {
        final hovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(hovered ? 0x14FFFFFF : 0x0AFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (record.status == CaptureStatus.aiFailed)
                          _chip('AI未生效', const Color(0xFFFBBF24)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_time(record.createdAt)}'
                      '${source.isEmpty ? '' : '   ·   $source'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    if (record.aiSummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        record.aiSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    if (record.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final t in record.tags)
                            _chip('#$t', const Color(0xFF9C8FFF)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  FluentIcons.delete,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.95)),
      ),
    );
  }
}
