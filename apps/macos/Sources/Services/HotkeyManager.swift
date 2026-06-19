import AppKit
import Carbon

/// 全局快捷键（Carbon RegisterEventHotKey）。系统级、无需辅助功能权限。
/// mM3 先固定 ⌃⇧1；后续可扩展为可配置 keyCode/modifiers。
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    /// 默认 ⌃⇧1：keyCode = kVK_ANSI_1，修饰 = control + shift。
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_1),
                  modifiers: UInt32 = UInt32(controlKey | shiftKey),
                  handler: @escaping () -> Void) {
        unregister()
        onTrigger = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                Log.write("hotkey: event handler fired")
                mgr.onTrigger?()
                return noErr
            },
            1, &eventType, selfPtr, &handlerRef)

        // 'SMHD' 作为 signature，便于识别。
        let hotKeyID = EventHotKeyID(signature: 0x534D_4844, id: 1)
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                            GetApplicationEventTarget(), 0, &hotKeyRef)
        Log.write("hotkey: register keyCode=\(keyCode) mods=\(modifiers) "
            + "install=\(installStatus) reg=\(regStatus) "
            + "hotKeyRef=\(hotKeyRef != nil)")
    }

    func unregister() {
        if let h = hotKeyRef { UnregisterEventHotKey(h); hotKeyRef = nil }
        if let e = handlerRef { RemoveEventHandler(e); handlerRef = nil }
        onTrigger = nil
    }
}
