import SwiftUI

/// 主窗口：原生侧边栏（首页 / 历史 / 设置），替代顶部分段标签栏，Mac 观感更协调。
struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Section? = .home

    enum Section: String, CaseIterable, Identifiable {
        case home, history, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .home: "首页"
            case .history: "历史"
            case .settings: "设置"
            }
        }
        var icon: String {
            switch self {
            case .home: "house"
            case .history: "clock"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 172, max: 220)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "viewfinder")
                        .foregroundStyle(Theme.brand)
                    Text("SnapMind").font(.headline)
                    Text("瞬念").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
            }
        } detail: {
            switch selection ?? .home {
            case .home: HomeView()
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
