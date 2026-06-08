/// AI 服务商预设：一键填入对应的 OpenAI 兼容 baseURL。
class AiProviderPreset {
  const AiProviderPreset(this.label, this.baseUrl);

  final String label;
  final String baseUrl;

  static const List<AiProviderPreset> presets = [
    AiProviderPreset('MiniMax（国际）', 'https://api.minimax.io/v1'),
    AiProviderPreset('MiniMax（国内）', 'https://api.minimaxi.com/v1'),
    AiProviderPreset('OpenAI', 'https://api.openai.com/v1'),
    AiProviderPreset('DeepSeek', 'https://api.deepseek.com/v1'),
    AiProviderPreset('通义 DashScope', 'https://dashscope.aliyuncs.com/compatible-mode/v1'),
    AiProviderPreset('智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4'),
    AiProviderPreset('本地 Ollama', 'http://localhost:11434/v1'),
    AiProviderPreset('自定义', ''),
  ];
}

/// 截图备份保留时长选项（天）。0=用完即删，-1=永久保留。
class RetentionOption {
  const RetentionOption(this.label, this.days);

  final String label;
  final int days;

  static const List<RetentionOption> options = [
    RetentionOption('不保留（用完即删）', 0),
    RetentionOption('保留 1 天', 1),
    RetentionOption('保留 7 天', 7),
    RetentionOption('保留 30 天', 30),
    RetentionOption('永久保留', -1),
  ];
}

/// 应用设置（不含 API Key —— Key 单独走系统安全存储）。
class AppSettings {
  const AppSettings({
    required this.vaultPath,
    required this.capturesDir,
    required this.screenshotBackupDir,
    required this.screenshotRetentionDays,
    required this.hotkey,
    required this.aiBaseUrl,
    required this.aiModel,
  });

  /// Obsidian Vault 根目录（绝对路径）。
  final String vaultPath;

  /// 笔记保存目录（相对 Vault），例如 Inbox/Captures。
  final String capturesDir;

  /// 截图备份文件夹（绝对路径，可在 Vault 之外）。留空则用默认（%LOCALAPPDATA%\SnapMind\Screenshots）。
  /// 注意：截图不嵌入笔记，仅作为可回看的临时备份，到期自动清理。
  final String screenshotBackupDir;

  /// 截图备份保留天数。0=用完即删，-1=永久保留，N=保留 N 天后自动清理。
  final int screenshotRetentionDays;

  /// 全局快捷键（展示用字符串，M3 解析），例如 Ctrl+Shift+1。
  final String hotkey;

  /// AI 服务 baseURL（OpenAI 兼容）。
  final String aiBaseUrl;

  /// AI 模型 id（必须多模态，能读图）。
  final String aiModel;

  factory AppSettings.defaults() => const AppSettings(
    vaultPath: '',
    capturesDir: 'Inbox/Captures',
    screenshotBackupDir: '',
    screenshotRetentionDays: 7,
    hotkey: 'Ctrl+Shift+1',
    aiBaseUrl: 'https://api.minimax.io/v1',
    aiModel: 'MiniMax-M3',
  );

  /// 是否已完成最小可用配置（至少设置了 Vault 路径）。
  bool get isConfigured => vaultPath.trim().isNotEmpty;

  AppSettings copyWith({
    String? vaultPath,
    String? capturesDir,
    String? screenshotBackupDir,
    int? screenshotRetentionDays,
    String? hotkey,
    String? aiBaseUrl,
    String? aiModel,
  }) {
    return AppSettings(
      vaultPath: vaultPath ?? this.vaultPath,
      capturesDir: capturesDir ?? this.capturesDir,
      screenshotBackupDir: screenshotBackupDir ?? this.screenshotBackupDir,
      screenshotRetentionDays: screenshotRetentionDays ?? this.screenshotRetentionDays,
      hotkey: hotkey ?? this.hotkey,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiModel: aiModel ?? this.aiModel,
    );
  }

  Map<String, dynamic> toJson() => {
    'vaultPath': vaultPath,
    'capturesDir': capturesDir,
    'screenshotBackupDir': screenshotBackupDir,
    'screenshotRetentionDays': screenshotRetentionDays,
    'hotkey': hotkey,
    'aiBaseUrl': aiBaseUrl,
    'aiModel': aiModel,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final d = AppSettings.defaults();
    return AppSettings(
      vaultPath: (json['vaultPath'] as String?) ?? d.vaultPath,
      capturesDir: (json['capturesDir'] as String?) ?? d.capturesDir,
      screenshotBackupDir: (json['screenshotBackupDir'] as String?) ?? d.screenshotBackupDir,
      screenshotRetentionDays:
          (json['screenshotRetentionDays'] as num?)?.toInt() ?? d.screenshotRetentionDays,
      hotkey: (json['hotkey'] as String?) ?? d.hotkey,
      aiBaseUrl: (json['aiBaseUrl'] as String?) ?? d.aiBaseUrl,
      aiModel: (json['aiModel'] as String?) ?? d.aiModel,
    );
  }
}
