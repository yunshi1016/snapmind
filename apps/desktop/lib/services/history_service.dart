import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/models/capture_record.dart';

/// 本地历史：把每条已保存的 CaptureRecord 存入 SQLite，供历史页回看。
class HistoryService {
  HistoryService._(this._db);

  final Database _db;

  static const _table = 'captures';

  static Future<HistoryService> open() async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'snapmind_history.db');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE $_table (
              id TEXT PRIMARY KEY,
              created_at TEXT NOT NULL,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              user_note TEXT NOT NULL,
              tags TEXT NOT NULL,
              source_app TEXT NOT NULL,
              source_window TEXT NOT NULL,
              markdown_path TEXT NOT NULL,
              screenshot_path TEXT,
              status TEXT NOT NULL,
              json TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_created ON $_table (created_at DESC)',
          );
        },
      ),
    );
    return HistoryService._(db);
  }

  Future<void> add(CaptureRecord r) async {
    await _db.insert(_table, {
      'id': r.id,
      'created_at': r.createdAt.toIso8601String(),
      'title': r.displayTitle,
      'summary': r.aiSummary,
      'user_note': r.userNote,
      'tags': r.tags.join(','),
      'source_app': r.sourceApp,
      'source_window': r.sourceWindowTitle,
      'markdown_path': r.markdownPath,
      'screenshot_path': r.screenshotPath,
      'status': r.status.name,
      'json': jsonEncode(r.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CaptureRecord>> recent({int limit = 200}) async {
    final rows = await _db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => CaptureRecord.fromJson(
            jsonDecode(row['json'] as String) as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final r = await _db.rawQuery('SELECT COUNT(*) c FROM $_table');
    return (r.first['c'] as int?) ?? 0;
  }
}
