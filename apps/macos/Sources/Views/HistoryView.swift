import AppKit
import SwiftUI

/// 历史页：保存过的截图笔记列表（最新在前），可在 Obsidian 打开 / 删除。
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var pendingDelete: CaptureRecord?

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView(
                    "暂无历史",
                    systemImage: "clock",
                    description: Text("按 \(model.settings.hotkey) 截图保存后，笔记会出现在这里"))
            } else {
                List {
                    ForEach(model.history) { record in
                        HistoryRow(record: record,
                                   onOpen: { open(record) },
                                   onDelete: { pendingDelete = record })
                    }
                }
            }
        }
        .confirmationDialog("删除这条记录？",
                            isPresented: Binding(
                                get: { pendingDelete != nil },
                                set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { record in
            Button("删除笔记文件", role: .destructive) {
                model.deleteHistory(record)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { record in
            Text("将从历史移除，并删除 Obsidian 库中的 \(record.displayTitle).md")
        }
    }

    private func open(_ record: CaptureRecord) {
        // 优先 obsidian:// 深链；失败则直接打开 .md 文件。
        if !record.markdownPath.isEmpty {
            let encoded = record.markdownPath
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let uri = URL(string: "obsidian://open?path=\(encoded)") {
                NSWorkspace.shared.open(uri)
                return
            }
            NSWorkspace.shared.open(URL(fileURLWithPath: record.markdownPath))
        }
    }
}

private struct HistoryRow: View {
    let record: CaptureRecord
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayTitle)
                    .font(.headline).lineLimit(1)
                Text(Self.dateFmt.string(from: record.createdAt))
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if !record.sourceApp.isEmpty {
                        Label(record.sourceApp, systemImage: "app.dashed")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let url = record.sourceUrl, !url.isEmpty {
                        Label("链接", systemImage: "link")
                            .font(.caption2).foregroundStyle(Theme.brand)
                    }
                    if record.status == .aiFailed {
                        Label("AI 降级", systemImage: "exclamationmark.triangle")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Button { onOpen() } label: { Image(systemName: "arrow.up.forward.app") }
                .buttonStyle(.borderless).help("在 Obsidian 打开")
            Button { onDelete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("删除")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var thumbnail: some View {
        if let p = record.screenshotPath, let img = NSImage(contentsOfFile: p) {
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 40).clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            RoundedRectangle(cornerRadius: 5).fill(.quaternary)
                .frame(width: 56, height: 40)
                .overlay(Image(systemName: "doc.text").foregroundStyle(.secondary))
        }
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }()
}
