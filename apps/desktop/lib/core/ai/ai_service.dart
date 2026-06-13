import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// AI 识别结果（任一字段都可能为空字符串/空列表，调用方自行降级）。
class AiCaptureResult {
  const AiCaptureResult({
    required this.ocrText,
    required this.title,
    required this.summary,
    required this.tags,
  });

  final String ocrText;
  final String title;
  final String summary;
  final List<String> tags;
}

/// OpenAI 兼容多模态客户端：截图 + 用户批注 → OCR 原文 / 标题 / 摘要 / 标签。
/// 默认 MiniMax，可指向任意 OpenAI 兼容端点。失败抛异常，由调用方降级。
class AiService {
  AiService({
    required String baseUrl,
    required String apiKey,
    required this.model,
    Duration timeout = const Duration(seconds: 60),
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: timeout,
            sendTimeout: timeout,
          ),
        );

  final Dio _dio;
  final String model;

  static const String _systemPrompt = '''
你是 SnapMind 截图知识助手。用户截取了一块屏幕区域并写下了自己的想法。
TITLE / SUMMARY / TAGS 一律用简体中文输出（即使截图内容是英文，也要用中文转述）；
OCR 项保留截图里文字的原始语言。
严格按下面的模板输出：每个标记 ###XXX### 单独占一行，下面紧跟该项内容。
不要输出 JSON、不要代码块、不要任何额外说明。各项内容里可以自由使用任何标点（包括引号、换行）。

###TITLE###
（简洁中文标题，不超过 20 字，不带书名号/引号）
###SUMMARY###
（2~4 句中文摘要：以知识总结的视角，直接提炼内容本身的核心信息、观点或结论，像读书笔记的要点，方便日后回顾。禁止描述画面或行为，禁止出现「截图」「图片」「用户」「界面」等字眼）
###OCR###
（截图中的全部可读文字，保留合理换行；没有文字则此项留空）
###TAGS###
（2~5 个中文标签，用中文顿号、或英文逗号分隔，不带 # 号）''';

  Future<AiCaptureResult> analyzeCapture({
    required Uint8List pngBytes,
    required String userNote,
  }) async {
    final dataUri = 'data:image/png;base64,${base64Encode(pngBytes)}';
    final resp = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: {
        'model': model,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': userNote.trim().isEmpty
                    ? '（用户没有写想法，请只根据截图内容生成。）'
                    : '我的想法：${userNote.trim()}',
              },
              {
                'type': 'image_url',
                'image_url': {'url': dataUri},
              },
            ],
          },
        ],
      },
    );

    final content = (((resp.data?['choices'] as List?)?.first
            as Map<String, dynamic>?)?['message']
        as Map<String, dynamic>?)?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw StateError('AI 返回内容为空');
    }
    return _parse(content);
  }

  /// 按 ###TITLE### / ###SUMMARY### / ###OCR### / ###TAGS### 标记切分。
  /// 字段内含引号/换行/任意标点都不影响（这正是弃用 JSON 的原因）。
  AiCaptureResult _parse(String raw) {
    const keys = ['TITLE', 'SUMMARY', 'OCR', 'TAGS'];
    final map = <String, String>{};
    for (final key in keys) {
      final marker = '###$key###';
      final start = raw.indexOf(marker);
      if (start < 0) continue;
      final contentStart = start + marker.length;
      var end = raw.length;
      for (final other in keys) {
        if (other == key) continue;
        final pos = raw.indexOf('###$other###', contentStart);
        if (pos >= 0 && pos < end) end = pos;
      }
      map[key] = raw.substring(contentStart, end).trim();
    }
    final tags = (map['TAGS'] ?? '')
        .split(RegExp(r'[,，、\n]'))
        .map((e) => e.replaceAll('#', '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final result = AiCaptureResult(
      title: map['TITLE'] ?? '',
      summary: map['SUMMARY'] ?? '',
      ocrText: map['OCR'] ?? '',
      tags: tags,
    );
    // 一个标记都没命中（模型完全不听话）→ 视为失败，触发降级。
    if (map.isEmpty) {
      throw FormatException('AI 输出未含任何标记：$raw');
    }
    return result;
  }
}
