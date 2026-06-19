#!/bin/bash
# SnapMindMac 无 Xcode 工程构建脚本：swiftc 直编 + 手工组 .app bundle + ad-hoc 签名。
# 不依赖 XcodeGen / Xcode 工程 / SwiftPM 联网依赖，全用系统框架。
# 用法：./build.sh [run]   —— 带 run 则构建后启动。
set -euo pipefail

APP_NAME="SnapMind"
BUNDLE_ID="com.munroe.snapmind"
VERSION="0.1.0"
BUILD_NUM="1"
DEPLOY_TARGET="14.0"

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/Sources"
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "==> 清理并准备 bundle"
rm -rf "$APP"
mkdir -p "$MACOS_DIR" "$RES_DIR"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
SWIFT_FILES="$(find "$SRC" -name '*.swift' | sort)"
echo "==> 编译源码："
echo "$SWIFT_FILES" | sed 's#^#    #'

# 调试构建：-Onone + 调试信息；发布时可加 -O。
swiftc $SWIFT_FILES \
  -o "$MACOS_DIR/$APP_NAME" \
  -target "arm64-apple-macos$DEPLOY_TARGET" \
  -sdk "$SDK" \
  -framework SwiftUI -framework AppKit -framework Carbon -framework Security \
  -framework ServiceManagement \
  -Onone -g

echo "==> 放置应用图标 + 品牌图"
if [ -f "$ROOT/assets/AppIcon.icns" ]; then
  cp "$ROOT/assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi
if [ -f "$ROOT/assets/icon-source.png" ]; then
  cp "$ROOT/assets/icon-source.png" "$RES_DIR/Logo.png"
fi

echo "==> 写 Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUM</string>
  <key>LSMinimumSystemVersion</key><string>$DEPLOY_TARGET</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>SnapMind · 瞬念</string>
  <key>NSAppleEventsUsageDescription</key><string>SnapMind 需要读取前台浏览器当前标签页的网址，作为截图笔记的来源链接。</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> 代码签名"
# 优先用稳定的自签名身份（指纹跨构建不变 → TCC 权限只需授权一次）。
SIGN_ID="SnapMind Local Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
  codesign --force --sign "$SIGN_ID" --timestamp=none "$APP"
  echo "   稳定身份签名：$SIGN_ID"
else
  codesign --force --sign - "$APP"
  echo "   ad-hoc 签名（未找到「$SIGN_ID」身份，权限每次重构会重置）"
fi

echo "✅ 构建完成：$APP"

if [ "${1:-}" = "run" ]; then
  echo "==> 启动"
  # 先杀掉旧实例，避免菜单栏重复
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.3
  open "$APP"
fi
