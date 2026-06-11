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
你是 SnapMind 截图知识助手。用户截取了一块屏幕区域并写下了自己的想法。请：
1. 提取截图中的全部可读文字（ocr_text），保留合理换行；无文字则为空字符串。
2. 结合截图内容与用户想法，生成简洁中文标题（title，≤20字，不要书名号/引号）。
3. 生成 2~4 句中文摘要（summary）：以知识总结的视角，直接提炼内容本身的核心信息、观点或结论（像读书笔记的要点），方便日后回顾。禁止描述画面或行为，禁止出现「截图」「图片」「用户」「界面」等字眼。
4. 生成 2~5 个中文标签（tags），每个 2~6 字，不带 # 号。

只输出一个 JSON 对象，不要任何其他文字或代码块标记：
{"ocr_text":"...","title":"...","summary":"...","tags":["..."]}''';

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

  /// 宽松解析：剥掉代码块围栏、截取首尾大括号之间的 JSON。
  AiCaptureResult _parse(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'^```(json)?', multiLine: true), '');
    s = s.replaceAll('```', '').trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw FormatException('AI 返回的不是 JSON：$raw');
    }
    final json = jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
    return AiCaptureResult(
      ocrText: (json['ocr_text'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
      tags: (json['tags'] as List?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
    );
  }
}
