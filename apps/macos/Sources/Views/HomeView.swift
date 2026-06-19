import AppKit
import SwiftUI

/// 首页：品牌信息 + 快捷键提示 + 配置状态 + 最近保存反馈。
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            brandLogo
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: Theme.brand.opacity(0.25), radius: 12, y: 4)
            Text("SnapMind · 瞬念")
                .font(.largeTitle.bold())
            Text("Capture your thoughts from anywhere.")
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("按").foregroundStyle(.secondary)
                Text(model.settings.hotkey)
                    .font(.body.monospaced().weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.brand.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Theme.brand)
                Text("截图 → 写想法 → 自动整理进 Obsidian").foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            if !model.settings.isConfigured {
                Label("尚未设置 Obsidian 库路径 —— 去「设置」配置后才能保存笔记",
                      systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).padding(.top, 8)
            }

            if let name = model.lastSavedName {
                Divider().padding(.vertical, 8)
                VStack(spacing: 4) {
                    Label("最近保存", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                    Text(name).font(.callout).textSelection(.enabled)
                    if let path = model.lastSavedPath {
                        Text(path).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    /// 品牌图：优先用打包的 logo（你的黑曜石 logo），缺失则回退到符号。
    @ViewBuilder private var brandLogo: some View {
        if let url = Bundle.main.url(forResource: "Logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "viewfinder")
                .font(.system(size: 48)).foregroundStyle(Theme.brand)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
