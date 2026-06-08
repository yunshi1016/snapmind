import 'dart:io';

import 'package:path/path.dart' as p;

class ObsidianWriteResult {
  const ObsidianWriteResult({required this.markdownPath, required this.fileName});

  final String markdownPath;
  final String fileName;
}

/// 把 Markdown 写入 Obsidian Vault 的笔记目录。纯 dart:io，可跨端复用。
class ObsidianWriter {
  const ObsidianWriter();

  /// 写入 `<vaultPath>/<capturesDir>/<baseName>.md`。
  /// 自动创建目录、清洗非法文件名、重名时追加 (1)/(2)…
  Future<ObsidianWriteResult> writeNote({
    required String vaultPath,
    required String capturesDir,
    required String baseName,
    required String markdown,
  }) async {
    final dirPath = p.normalize(p.join(vaultPath, capturesDir));
    await Directory(dirPath).create(recursive: true);

    final safeBase = sanitizeFileName(baseName);
    var fileName = '$safeBase.md';
    var file = File(p.join(dirPath, fileName));
    var i = 1;
    while (file.existsSync()) {
      fileName = '$safeBase ($i).md';
      file = File(p.join(dirPath, fileName));
      i++;
    }
    await file.writeAsString(markdown, flush: true);
    return ObsidianWriteResult(markdownPath: file.path, fileName: fileName);
  }

  /// 清洗 Windows 非法文件名字符（\ / : * ? " < > | 与控制字符）。
  static String sanitizeFileName(String name) {
    var s = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'[ .]+$'), ''); // Windows 不允许结尾的点/空格
    if (s.isEmpty) s = 'capture';
    if (s.length > 80) s = s.substring(0, 80).trim();
    return s;
  }
}
