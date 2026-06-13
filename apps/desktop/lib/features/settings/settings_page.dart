import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../../models/app_settings.dart';
import '../../providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _vault;
  late final TextEditingController _captures;
  late final TextEditingController _backupDir;
  late final TextEditingController _hotkey;
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;

  AiProviderPreset _preset = AiProviderPreset.presets.first;
  int _retentionDays = 7;
  bool _obscureKey = true;
  bool _dirty = false;
  bool _loadingKey = true;
  bool _autoStart = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _vault = TextEditingController(text: s.vaultPath);
    _captures = TextEditingController(text: s.capturesDir);
    _backupDir = TextEditingController(text: s.screenshotBackupDir);
    _hotkey = TextEditingController(text: s.hotkey);
    _baseUrl = TextEditingController(text: s.aiBaseUrl);
    _model = TextEditingController(text: s.aiModel);
    _apiKey = TextEditingController();
    _preset = _detectPreset(s.aiBaseUrl);
    _retentionDays = _validRetention(s.screenshotRetentionDays);
    for (final c in [
      _vault,
      _captures,
      _backupDir,
      _hotkey,
      _baseUrl,
      _apiKey,
      _model,
    ]) {
      c.addListener(_markDirty);
    }
    _loadApiKey();
    _loadAutoStart();
  }

  Future<void> _loadAutoStart() async {
    final enabled = await launchAtStartup.isEnabled();
    if (mounted) setState(() => _autoStart = enabled);
  }

  Future<void> _toggleAutoStart(bool on) async {
    if (on) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    final enabled = await launchAtStartup.isEnabled();
    if (mounted) setState(() => _autoStart = enabled);
  }

  Future<void> _loadApiKey() async {
    final key = await ref.read(settingsServiceProvider).readApiKey();
    if (!mounted) return;
    setState(() {
      _apiKey.text = key ?? '';
      _loadingKey = false;
      _dirty = false;
    });
  }

  int _validRetention(int days) {
    return RetentionOption.options.any((o) => o.days == days) ? days : 7;
  }

  AiProviderPreset _detectPreset(String baseUrl) {
    for (final p in AiProviderPreset.presets) {
      if (p.baseUrl.isNotEmpty && p.baseUrl == baseUrl) return p;
    }
    return AiProviderPreset.presets.last; // 自定义
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [
      _vault,
      _captures,
      _backupDir,
      _hotkey,
      _baseUrl,
      _apiKey,
      _model,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFolder(TextEditingController target) async {
    final path = await getDirectoryPath(confirmButtonText: '选择此文件夹');
    if (path != null) {
      target.text = path;
      _markDirty();
    }
  }

  Future<void> _save() async {
    final next = AppSettings(
      vaultPath: _vault.text.trim(),
      capturesDir: _captures.text.trim(),
      screenshotBackupDir: _backupDir.text.trim(),
      screenshotRetentionDays: _retentionDays,
      hotkey: _hotkey.text.trim(),
      aiBaseUrl: _baseUrl.text.trim(),
      aiModel: _model.text.trim(),
    );
    await ref.read(settingsProvider.notifier).save(next);
    await ref.read(settingsServiceProvider).writeApiKey(_apiKey.text);
    if (!mounted) return;
    setState(() => _dirty = false);
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('设置已保存'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('设置')),
      children: [
        _section(
          icon: FluentIcons.library,
          title: '知识库',
          subtitle: '笔记会写入你的 Obsidian Vault。',
          children: [
            InfoLabel(
              label: 'Obsidian Vault 路径',
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _vault,
                      placeholder: r'例如 D:\Obsidian\MyVault',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _browseButton(() => _pickFolder(_vault)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: '笔记保存目录（相对 Vault）',
              child: TextBox(
                controller: _captures,
                placeholder: 'Inbox/Captures',
              ),
            ),
          ],
        ),
        _section(
          icon: FluentIcons.camera,
          title: '截图备份',
          subtitle: '截图不会写进笔记，仅作可回看的临时备份，到期自动清理。可选 Vault 之外的文件夹。',
          children: [
            InfoLabel(
              label: '备份文件夹',
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _backupDir,
                      placeholder:
                          r'留空 = 默认 %LOCALAPPDATA%\SnapMind\Screenshots',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _browseButton(() => _pickFolder(_backupDir)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: '保留时长',
              child: ComboBox<int>(
                isExpanded: true,
                value: _retentionDays,
                items: [
                  for (final o in RetentionOption.options)
                    ComboBoxItem(value: o.days, child: Text(o.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _retentionDays = v);
                  _markDirty();
                },
              ),
            ),
          ],
        ),
        _section(
          icon: FluentIcons.keyboard_classic,
          title: '快捷键',
          subtitle: '在任意程序按下即可触发截图捕捉。',
          children: [
            InfoLabel(
              label: '全局截图快捷键',
              child: TextBox(controller: _hotkey, placeholder: 'Ctrl+Shift+1'),
            ),
          ],
        ),
        _section(
          icon: FluentIcons.power_button,
          title: '启动',
          subtitle: '常驻系统托盘，随时按快捷键截图。',
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '开机自动启动',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                ToggleSwitch(
                  checked: _autoStart,
                  onChanged: _toggleAutoStart,
                ),
              ],
            ),
          ],
        ),
        _section(
          icon: FluentIcons.robot,
          title: 'AI 服务',
          subtitle: 'OpenAI 兼容接口。模型须为多模态（能读图）。',
          children: [
            InfoLabel(
              label: '服务商预设',
              child: ComboBox<AiProviderPreset>(
                isExpanded: true,
                value: _preset,
                items: [
                  for (final p in AiProviderPreset.presets)
                    ComboBoxItem(value: p, child: Text(p.label)),
                ],
                onChanged: (p) {
                  if (p == null) return;
                  setState(() => _preset = p);
                  if (p.baseUrl.isNotEmpty) {
                    _baseUrl.text = p.baseUrl;
                    _markDirty();
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: 'Base URL',
              child: TextBox(
                controller: _baseUrl,
                placeholder: 'https://api.minimax.io/v1',
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: 'API Key',
              child: TextBox(
                controller: _apiKey,
                obscureText: _obscureKey,
                placeholder: _loadingKey ? '读取中…' : 'sk-…',
                suffix: IconButton(
                  icon: Icon(
                    _obscureKey ? FluentIcons.red_eye : FluentIcons.hide3,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: '模型',
              child: TextBox(controller: _model, placeholder: 'MiniMax-M3'),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ MiniMax 请用 M3 / VL 系列等多模态模型，纯文本款（如 M2.7）读不了截图。',
              style: TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: _dirty ? _save : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('保存设置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _browseButton(VoidCallback onPressed) {
    return Button(
      onPressed: onPressed,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.folder_open),
          SizedBox(width: 6),
          Text('浏览'),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: kBrandIconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0x99FFFFFF)),
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

const Color kBrandIconColor = Color(0xFF9C8FFF);
