import AppKit
import Carbon

final class ShortcutManager {
    static let shared = ShortcutManager()

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func startListening() {
        registerHotKey()
    }

    func reload() {
        unregisterHotKey()
        registerHotKey()
    }

    func stopListening() {
        unregisterHotKey()
    }

    private func registerHotKey() {
        let keyCode = UserDefaults.standard.integer(forKey: "shortcutKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "shortcutModifiers")

        guard keyCode != 0, modifiers != 0 else { return }

        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4342554C), id: 1)
        let carbonModifiers = carbonFlags(from: UInt(modifiers))

        RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let userData else { return noErr }

                let manager = Unmanaged<ShortcutManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if status == noErr && hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        manager.onTrigger?()
                    }
                }

                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func carbonFlags(from cocoaFlags: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: cocoaFlags)
        var result: UInt32 = 0

        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option)  { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift)   { result |= UInt32(shiftKey) }

        return result
    }
}
