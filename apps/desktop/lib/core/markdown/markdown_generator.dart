import '../models/capture_record.dart';

/// 把 CaptureRecord 渲染成 Obsidian Markdown（YAML frontmatter + 纯内容正文）。
/// v1 决策：笔记不嵌入截图。
class MarkdownGenerator {
  const MarkdownGenerator();

  String generate(CaptureRecord r) {
    final title = r.displayTitle;
    final created = r.createdAt;
    final tags = r.tags
        .map(_sanitizeTag)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    final fm = StringBuffer()
      ..writeln('---')
      ..writeln('title: ${_yaml(title)}')
      ..writeln('created: ${created.toIso8601String()}');
    if (tags.isNotEmpty) {
      fm.writeln('tags:');
      for (final t in tags) {
        fm.writeln('  - $t');
      }
    }
    if (r.sourceApp.trim().isNotEmpty) {
      fm.writeln('source_app: ${_yaml(r.sourceApp.trim())}');
    }
    if (r.sourceWindowTitle.trim().isNotEmpty) {
      fm.writeln('source_window: ${_yaml(r.sourceWindowTitle.trim())}');
    }
    if ((r.sourceUrl ?? '').trim().isNotEmpty) {
      fm.writeln('source_url: ${_yaml(r.sourceUrl!.trim())}');
    }
    fm.writeln('---');

    final body = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('## 我的想法')
      ..writeln()
      ..writeln(_orDash(r.userNote))
      ..writeln()
      ..writeln('## AI 摘要')
      ..writeln()
      ..writeln(_orPlaceholder(r.aiSummary, '_（暂无 AI 摘要）_'))
      ..writeln()
      ..writeln('## OCR 原文')
      ..writeln()
      ..writeln(_orPlaceholder(r.ocrText, '_（暂无 OCR 文本）_'))
      ..writeln()
      ..writeln('## 来源信息')
      ..writeln()
      ..writeln('- 应用：${_orDash(r.sourceApp)}')
      ..writeln('- 窗口标题：${_orDash(r.sourceWindowTitle)}')
      ..writeln('- 来源链接：${_orDash(r.sourceUrl ?? '')}')
      ..writeln('- 时间：${_humanTime(created)}')
      ..writeln()
      ..writeln('## 标签')
      ..writeln()
      ..writeln(tags.isEmpty ? '—' : tags.map((t) => '#$t').join(' '));

    return '$fm\n$body';
  }

  String _orDash(String s) => s.trim().isEmpty ? '—' : s.trim();

  String _orPlaceholder(String s, String placeholder) =>
      s.trim().isEmpty ? placeholder : s.trim();

  String _sanitizeTag(String t) =>
      t.trim().replaceAll('#', '').replaceAll(RegExp(r'\s+'), '-');

  String _yaml(String s) =>
      '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  String _humanTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
