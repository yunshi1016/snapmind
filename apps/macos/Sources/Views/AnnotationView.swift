import AppKit
import SwiftUI

/// 批注窗内容：缩略图 + 「我的想法」+ 保存/取消（⌘⏎ 存 / Esc 取消）。
struct AnnotationView: View {
    let image: NSImage
    let sourceApp: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var note = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile").foregroundStyle(Theme.brand)
                Text("整理这一帧想法").font(.headline)
                Spacer()
                if !sourceApp.isEmpty {
                    Text(sourceApp).font(.caption).foregroundStyle(.secondary)
                }
            }

            // 固定高度的居中容器：宽图/窄图/高图都整齐，不会撑乱窗口。
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.22))
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.12), lineWidth: 1))

            Text("我的想法").font(.subheadline.weight(.medium))
            TextEditor(text: $note)
                .font(.body)
                .frame(height: 96)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08)))
                .focused($editorFocused)

            HStack {
                Button("取消", role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("⌘⏎ 保存").font(.caption2).foregroundStyle(.tertiary)
                Button("保存") { onSave(note) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
            }
        }
        .padding(18)
        .frame(width: 420, height: 480)
        .onAppear { editorFocused = true }
    }
}
