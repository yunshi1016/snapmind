import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:snapmind/core/obsidian/obsidian_writer.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('snapmind_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  const writer = ObsidianWriter();

  test('写入 .md 并自动建目录', () async {
    final res = await writer.writeNote(
      vaultPath: tmp.path,
      capturesDir: 'Inbox/Captures',
      baseName: 'Hello World',
      markdown: '# Hi',
    );
    final f = File(res.markdownPath);
    expect(f.existsSync(), isTrue);
    expect(f.readAsStringSync(), '# Hi');
    expect(res.fileName, 'Hello World.md');
    expect(p.dirname(res.markdownPath), endsWith(p.join('Inbox', 'Captures')));
  });

  test('重名追加 (1)', () async {
    final a = await writer.writeNote(
      vaultPath: tmp.path,
      capturesDir: 'c',
      baseName: 'note',
      markdown: 'a',
    );
    final b = await writer.writeNote(
      vaultPath: tmp.path,
      capturesDir: 'c',
      baseName: 'note',
      markdown: 'b',
    );
    expect(a.fileName, 'note.md');
    expect(b.fileName, 'note (1).md');
  });

  test('清洗非法文件名字符', () {
    final cleaned = ObsidianWriter.sanitizeFileName('a/b:c*?"<>|d');
    expect(cleaned, isNot(matches(RegExp(r'[\\/:*?"<>|]'))));
    expect(ObsidianWriter.sanitizeFileName('   '), 'capture');
    expect(ObsidianWriter.sanitizeFileName('结尾点.'), '结尾点');
  });
}
