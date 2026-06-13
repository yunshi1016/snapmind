/// 捕获来源类型（v1 仅截图）。
enum CaptureSourceType { screenshot }

/// 记录状态。
enum CaptureStatus {
  draft, // 草稿（批注中）
  saving, // 写入中
  saved, // 已写入
  aiFailed, // AI 失败但已降级保存
}

/// 一次捕获的领域模型（纯 Dart，可跨端复用）。
class CaptureRecord {
  const CaptureRecord({
    required this.id,
    required this.createdAt,
    required this.userNote,
    this.screenshotPath,
    this.vaultPath = '',
    this.markdownPath = '',
    this.ocrText = '',
    this.aiTitle = '',
    this.aiSummary = '',
    this.tags = const [],
    this.sourceApp = '',
    this.sourceWindowTitle = '',
    this.sourceUrl,
    this.sourceType = CaptureSourceType.screenshot,
    this.status = CaptureStatus.draft,
  });

  final String id;
  final DateTime createdAt;

  /// 用户写下的「我的想法」。
  final String userNote;

  /// 截图备份路径（不嵌入笔记；到期清理后可能为 null/失效）。
  final String? screenshotPath;

  final String vaultPath;
  final String markdownPath;

  final String ocrText;
  final String aiTitle;
  final String aiSummary;
  final List<String> tags;

  final String sourceApp;
  final String sourceWindowTitle;
  final String? sourceUrl;

  final CaptureSourceType sourceType;
  final CaptureStatus status;

  /// 展示/文件名用标题：优先 AI 标题，退化到批注首行，再退化到默认。
  String get displayTitle {
    if (aiTitle.trim().isNotEmpty) return aiTitle.trim();
    final firstLine = userNote.trim().split('\n').first.trim();
    if (firstLine.isNotEmpty) return firstLine;
    return '未命名捕获';
  }

  CaptureRecord copyWith({
    String? id,
    DateTime? createdAt,
    String? userNote,
    String? screenshotPath,
    String? vaultPath,
    String? markdownPath,
    String? ocrText,
    String? aiTitle,
    String? aiSummary,
    List<String>? tags,
    String? sourceApp,
    String? sourceWindowTitle,
    String? sourceUrl,
    CaptureSourceType? sourceType,
    CaptureStatus? status,
  }) {
    return CaptureRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userNote: userNote ?? this.userNote,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      vaultPath: vaultPath ?? this.vaultPath,
      markdownPath: markdownPath ?? this.markdownPath,
      ocrText: ocrText ?? this.ocrText,
      aiTitle: aiTitle ?? this.aiTitle,
      aiSummary: aiSummary ?? this.aiSummary,
      tags: tags ?? this.tags,
      sourceApp: sourceApp ?? this.sourceApp,
      sourceWindowTitle: sourceWindowTitle ?? this.sourceWindowTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'userNote': userNote,
    'screenshotPath': screenshotPath,
    'vaultPath': vaultPath,
    'markdownPath': markdownPath,
    'ocrText': ocrText,
    'aiTitle': aiTitle,
    'aiSummary': aiSummary,
    'tags': tags,
    'sourceApp': sourceApp,
    'sourceWindowTitle': sourceWindowTitle,
    'sourceUrl': sourceUrl,
    'sourceType': sourceType.name,
    'status': status.name,
  };

  factory CaptureRecord.fromJson(Map<String, dynamic> json) {
    return CaptureRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userNote: (json['userNote'] as String?) ?? '',
      screenshotPath: json['screenshotPath'] as String?,
      vaultPath: (json['vaultPath'] as String?) ?? '',
      markdownPath: (json['markdownPath'] as String?) ?? '',
      ocrText: (json['ocrText'] as String?) ?? '',
      aiTitle: (json['aiTitle'] as String?) ?? '',
      aiSummary: (json['aiSummary'] as String?) ?? '',
      tags:
          (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      sourceApp: (json['sourceApp'] as String?) ?? '',
      sourceWindowTitle: (json['sourceWindowTitle'] as String?) ?? '',
      sourceUrl: json['sourceUrl'] as String?,
      sourceType: CaptureSourceType.values.byName(
        (json['sourceType'] as String?) ?? CaptureSourceType.screenshot.name,
      ),
      status: CaptureStatus.values.byName(
        (json['status'] as String?) ?? CaptureStatus.draft.name,
      ),
    );
  }
}
