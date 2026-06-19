#!/bin/bash
# 把 build/SnapMind.app 打成便携 zip（解压即用）。未公证 → 他人首次需右键打开绕过 Gatekeeper。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="0.1.0"

"$ROOT/build.sh"

DIST="$ROOT/dist"
mkdir -p "$DIST"
ARCH="$(uname -m)"
ZIP="$DIST/SnapMind-v$VERSION-macos-$ARCH.zip"
rm -f "$ZIP"

# ditto 保留 bundle 结构/签名，优于 zip。
ditto -c -k --keepParent "$ROOT/build/SnapMind.app" "$ZIP"

echo "✅ 便携包：$ZIP  ($(du -h "$ZIP" | cut -f1))"
echo "   分发：解压 → 右键「打开」一次（未公证，本地 ad-hoc 签名）。"
