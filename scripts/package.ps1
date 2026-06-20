# 把 release 构建产物打包成便携 zip（解压即用，无需安装/证书）。
# 用法（在仓库根目录）：  pwsh scripts/package.ps1
# 前置：先跑过  flutter build windows --release

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$releaseDir = Join-Path $root 'apps/desktop/build/windows/x64/runner/Release'
$distDir = Join-Path $root 'dist'

if (-not (Test-Path (Join-Path $releaseDir 'snapmind.exe'))) {
  Write-Error "未找到 release 产物，请先运行：flutter build windows --release"
}

# 读版本号（pubspec version 的主体部分）
$pubspec = Get-Content (Join-Path $root 'apps/desktop/pubspec.yaml')
$verLine = ($pubspec | Select-String '^version:\s*(.+)$').Matches.Groups[1].Value.Trim()
$version = ($verLine -split '\+')[0]

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zipName = "SnapMind-v$version-windows-x64-portable.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath
# 顺带把浏览器扩展打进包里，解压即可加载（网页来源链接功能需要它；不装不影响截图）。
$extDir = Join-Path $root 'extension'
if (Test-Path $extDir) {
  Compress-Archive -Path $extDir -DestinationPath $zipPath -Update
}
$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "✅ 便携包已生成：$zipPath  ($sizeMB MB)"
Write-Host "   分发说明：解压后双击 snapmind.exe 即可运行，无需安装。"
