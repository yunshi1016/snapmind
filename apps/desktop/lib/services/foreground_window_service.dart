import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// 触发截图瞬间的前台窗口信息。
class ForegroundWindowInfo {
  const ForegroundWindowInfo({this.app = '', this.title = '', this.url = ''});

  /// 前台进程的可执行文件名，如 chrome.exe。
  final String app;

  /// 前台窗口标题。
  final String title;

  /// 浏览器地址栏 URL（暂未实现，恒为空——见下方说明）。
  final String url;
}

/// 纯 Dart win32 FFI 取前台窗口元数据（仅 Windows）。
/// 必须在隐藏/弹出 SnapMind 自己的窗口**之前**调用，否则焦点已变。
///
/// 注：地址栏 URL 曾尝试用 UI Automation 读取，但内联 UIA/COM 的原生访问违例
/// 无法被 Dart try/catch 捕获，一旦指针出错就会崩溃整个进程。已暂时移除，
/// URL 恒为空；可靠取 URL 的方案是浏览器扩展（独立子项目）。
class ForegroundWindowService {
  const ForegroundWindowService();

  ForegroundWindowInfo capture() {
    try {
      final hwnd = GetForegroundWindow();
      if (hwnd == 0) return const ForegroundWindowInfo();

      // 窗口标题
      var title = '';
      final titleBuf = wsalloc(1024);
      try {
        final len = GetWindowText(hwnd, titleBuf, 1024);
        if (len > 0) title = titleBuf.toDartString();
      } finally {
        free(titleBuf);
      }

      // 进程可执行文件名
      var app = '';
      final pidPtr = calloc<Uint32>();
      try {
        GetWindowThreadProcessId(hwnd, pidPtr);
        final pid = pidPtr.value;
        if (pid != 0) {
          final hProc = OpenProcess(
            PROCESS_QUERY_LIMITED_INFORMATION,
            FALSE,
            pid,
          );
          if (hProc != 0) {
            final exeBuf = wsalloc(MAX_PATH);
            final sizePtr = calloc<Uint32>()..value = MAX_PATH;
            try {
              if (QueryFullProcessImageName(hProc, 0, exeBuf, sizePtr) != 0) {
                final full = exeBuf.toDartString();
                app = full.split(r'\').last;
              }
            } finally {
              free(exeBuf);
              free(sizePtr);
              CloseHandle(hProc);
            }
          }
        }
      } finally {
        free(pidPtr);
      }

      return ForegroundWindowInfo(app: app, title: title);
    } catch (_) {
      // 来源信息是锦上添花，任何失败都不阻塞截图流程。
      return const ForegroundWindowInfo();
    }
  }
}
