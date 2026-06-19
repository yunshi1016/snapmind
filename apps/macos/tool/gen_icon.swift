// 从源 logo PNG 生成 macOS .icns（圆角方形，全尺寸 iconset）。
// 用法：swift tool/gen_icon.swift <source.png> <out.icns>
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: gen_icon <source.png> <out.icns>\n".utf8))
    exit(1)
}
guard let src = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write(Data("无法读取源图 \(args[1])\n".utf8))
    exit(1)
}

let iconset = NSTemporaryDirectory() + "SnapMind.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    // macOS 连续圆角近似：半径 ≈ 0.2237 × 边长。
    let radius = CGFloat(px) * 0.2237
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    src.draw(in: rect, from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for (name, px) in entries {
    if let data = render(px) {
        try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", args[2]]
try! p.run()
p.waitUntilExit()
print("✅ 生成 \(args[2])")
