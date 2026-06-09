import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/markdown/markdown_generator.dart';
import '../../core/models/capture_record.dart';
import '../../core/obsidian/obsidian_writer.dart';
import '../../providers.dart';
import '../../theme.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final configured = settings.isConfigured;

    return ScaffoldPage(
      content: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                const _Logo(),
                const SizedBox(height: 22),
                const Text(
                  'SnapMind',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '瞬念',
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Capture your thoughts from anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 26),
                _StatusPill(configured: configured),
                const SizedBox(height: 16),
                const _HotkeyHintCard(),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onOpenSettings,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            configured ? FluentIcons.settings : FluentIcons.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(configured ? '打开设置' : '去配置 Vault'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (configured) ...[
                  SizedBox(
                    width: double.infinity,
                    child: Button(
                      onPressed: () => _writeTestNote(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.edit, size: 14),
                            SizedBox(width: 8),
                            Text('写一篇测试笔记 (M2)'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: Button(
                    onPressed: () => windowManager.hide(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.chrome_minimize, size: 14),
                          SizedBox(width: 8),
                          Text('最小化到托盘'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'v0.0.1 · GPL-3.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: kBrandColor.withValues(alpha: 0.40),
            blurRadius: 36,
            spreadRadius: -8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = configured ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);
    final label = configured ? '已就绪' : '待配置 Vault';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotkeyHintCard extends StatelessWidget {
  const _HotkeyHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '全局截图快捷键',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _Kbd('Ctrl'),
              _KbdPlus(),
              _Kbd('Shift'),
              _KbdPlus(),
              _Kbd('1'),
              Spacer(),
              Text('即将启用', style: TextStyle(fontSize: 11, color: Color(0x66FFFFFF))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _KbdPlus extends StatelessWidget {
  const _KbdPlus();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('+', style: TextStyle(color: Color(0x55FFFFFF))),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// M2 临时验证：生成示例笔记并写入 Obsidian。M3–M6 会用真实截图流程替换触发。
Future<void> _writeTestNote(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  if (!settings.isConfigured) return;
  try {
    final now = DateTime.now();
    final record = CaptureRecord(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      userNote: '这是一条来自 SnapMind 的测试笔记，用于验证「生成 Markdown → 写入 Obsidian」闭环。',
      ocrText: '（示例）截图里识别到的文字会出现在这里。',
      aiTitle: 'SnapMind 测试笔记',
      aiSummary: '（示例）AI 生成的摘要会出现在这里。',
      tags: const ['snapmind', '测试'],
      sourceApp: 'SnapMind',
      sourceWindowTitle: 'M2 验证',
    );
    final markdown = const MarkdownGenerator().generate(record);
    final dateStr =
        '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}${_two(now.minute)}';
    final res = await const ObsidianWriter().writeNote(
      vaultPath: settings.vaultPath,
      capturesDir: settings.capturesDir,
      baseName: '$dateStr ${record.displayTitle}',
      markdown: markdown,
    );
    if (!context.mounted) return;
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('测试笔记已写入 Obsidian'),
        content: Text(res.fileName),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    await displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('写入失败'),
        content: Text('$e'),
        severity: InfoBarSeverity.error,
        onClose: close,
      ),
    );
  }
}
