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
      ..writeln('## OCR 识别')
      ..writeln()
      ..writeln(
        r.ocrText.trim().isEmpty
            ? '_（暂无 OCR 文本）_'
            : _normalizeOcr(r.ocrText.trim()),
      )
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

  /// 把 OCR 的 Markdown 调整成可安全嵌入笔记的 Obsidian Markdown：
  /// 笔记自身用 # 作标题、## 作段落，所以 OCR 内的 # / ## 标题要降到 ###，
  /// 否则会顶破整篇大纲。跳过代码围栏内的行（避免改动代码里的 # 注释）。
  String _normalizeOcr(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    var inFence = false;
    final out = <String>[];
    for (final line in lines) {
      final stripped = line.replaceFirst(RegExp(r'^ +'), '');
      if (stripped.startsWith('```') || stripped.startsWith('~~~')) {
        inFence = !inFence;
        out.add(line);
        continue;
      }
      if (!inFence) {
        final m = RegExp(r'^(#{1,6}) ').firstMatch(stripped);
        if (m != null && m.group(1)!.length < 3) {
          out.add('#' * (3 - m.group(1)!.length) + stripped);
          continue;
        }
      }
      out.add(line);
    }
    return out.join('\n');
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
