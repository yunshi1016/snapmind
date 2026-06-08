import 'package:flutter_test/flutter_test.dart';
import 'package:snapmind/core/markdown/markdown_generator.dart';
import 'package:snapmind/core/models/capture_record.dart';

void main() {
  const gen = MarkdownGenerator();

  test('完整字段：渲染 frontmatter / 各章节 / 标签，且不嵌入截图', () {
    final r = CaptureRecord(
      id: 'x',
      createdAt: DateTime(2026, 6, 8, 22, 30),
      userNote: '这是我的想法\n第二行',
      ocrText: '识别出来的文字',
      aiTitle: '一个标题',
      aiSummary: '这是摘要',
      tags: ['flutter', 'ai 工具'],
      sourceApp: 'chrome.exe',
      sourceWindowTitle: '某网页 - Google Chrome',
      sourceUrl: 'https://example.com',
    );
    final md = gen.generate(r);

    expect(md, startsWith('---'));
    expect(md, contains('title: "一个标题"'));
    expect(md, contains('created: 2026-06-08T22:30:00'));
    expect(md, contains('# 一个标题'));
    expect(md, contains('## 我的想法'));
    expect(md, contains('这是我的想法'));
    expect(md, contains('## AI 摘要'));
    expect(md, contains('这是摘要'));
    expect(md, contains('## OCR 原文'));
    expect(md, contains('识别出来的文字'));
    expect(md, contains('- 应用：chrome.exe'));
    expect(md, contains('- 时间：2026-06-08 22:30'));
    expect(md, contains('https://example.com'));
    expect(md, contains('#flutter'));
    expect(md, contains('#ai-工具')); // 空格被清洗成 -

    // v1 决策：不嵌入截图
    expect(md, isNot(contains('![[')));
    expect(md, isNot(contains('## 截图')));
  });

  test('空 AI 字段→占位符；标题退化到批注首行', () {
    final r = CaptureRecord(
      id: 'y',
      createdAt: DateTime(2026, 1, 1, 9, 5),
      userNote: '只有想法',
    );
    final md = gen.generate(r);
    expect(md, contains('# 只有想法'));
    expect(md, contains('（暂无 AI 摘要）'));
    expect(md, contains('（暂无 OCR 文本）'));
    expect(md, contains('- 应用：—')); // 空来源显示破折号
  });
}
