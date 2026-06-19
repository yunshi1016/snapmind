import AppKit

/// 一张截图（备份路径 + 物理像素尺寸）。
struct CaptureShot {
    let path: String
    let pixelWidth: Int
    let pixelHeight: Int
}

/// 屏幕抓取 + 备份目录管理。用系统原生 `screencapture -i` 框选（省掉自绘 overlay）。
struct CaptureService {
    static let backupPrefix = "SnapMind_"

    /// 交互式区域截图。返回临时 PNG 路径；用户取消（Esc）返回 nil。
    func captureInteractive() async -> String? {
        let tmp = NSTemporaryDirectory()
            + "snapmind_shot_\(Int(Date().timeIntervalSince1970 * 1000)).png"
        await runScreencapture(to: tmp)
        let fm = FileManager.default
        guard fm.fileExists(atPath: tmp),
              let size = (try? fm.attributesOfItem(atPath: tmp)[.size]) as? Int,
              size > 0
        else { return nil }   // 取消 → 不生成文件
        return tmp
    }

    private func runScreencapture(to path: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                // -i 交互框选；-x 静音。
                proc.arguments = ["-i", "-x", path]
                do {
                    try proc.run()
                    proc.waitUntilExit()
                } catch {
                    Log.write("capture: screencapture 启动失败 \(error)")
                }
                cont.resume()
            }
        }
    }

    /// 把临时截图存入备份目录（SnapMind_ 时间戳命名）。
    func saveToBackup(tempPath: String, backupDirConfigured: String) -> CaptureShot? {
        let dir = SettingsStore.resolveBackupDir(backupDirConfigured)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(Self.backupFileName())
        do {
            try FileManager.default.copyItem(atPath: tempPath, toPath: dest.path)
        } catch {
            Log.write("capture: 存备份失败 \(error)")
            return nil
        }
        let (w, h) = Self.pixelSize(of: dest.path)
        return CaptureShot(path: dest.path, pixelWidth: w, pixelHeight: h)
    }

    /// 带毫秒的时间戳文件名（避免同秒覆盖）。
    static func backupFileName(_ at: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return "\(backupPrefix)\(f.string(from: at)).png"
    }

    static func pixelSize(of path: String) -> (Int, Int) {
        guard let img = NSImage(contentsOfFile: path) else { return (0, 0) }
        for rep in img.representations {
            if let bm = rep as? NSBitmapImageRep {
                return (bm.pixelsWide, bm.pixelsHigh)
            }
        }
        return (Int(img.size.width), Int(img.size.height))
    }

    /// 按保留策略清理备份：删除超过 retentionDays 天的截图。
    /// retentionDays <= 0 不在此清（0=用完即删由保存流程处理）。
    /// 安全：只删文件名以 SnapMind_ 开头的 .png，绝不碰用户的其他图片。
    func cleanupBackups(backupDirConfigured: String, retentionDays: Int) {
        guard retentionDays > 0 else { return }
        let dir = SettingsStore.resolveBackupDir(backupDirConfigured)
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for url in items {
            let name = url.lastPathComponent
            guard name.hasPrefix(Self.backupPrefix),
                  name.lowercased().hasSuffix(".png") else { continue }
            if let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate, mod < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
