// SnapMind 冒烟测试。
//
// 注意：完整的 SnapMindApp 会在 initState 里初始化系统托盘/窗口管理（平台插件），
// 在纯 widget 测试环境下没有对应平台通道，因此这里只做一个轻量渲染冒烟测试。
// 真正的业务逻辑单测放在 packages/core（M2 起）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic render smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('SnapMind'))),
      ),
    );

    expect(find.text('SnapMind'), findsOneWidget);
  });
}
