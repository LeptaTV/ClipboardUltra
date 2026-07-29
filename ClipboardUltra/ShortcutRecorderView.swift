import SwiftUI
import AppKit

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: UInt

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.keyCode = keyCode
        view.modifiers = modifiers
        view.onCapture = { code, mods in
            keyCode = code
            modifiers = mods
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.needsDisplay = true
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((Int, UInt) -> Void)?
    var keyCode: Int = 0
    var modifiers: UInt = 0
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }

        let mods = event.modifierFlags
            .intersection([.command, .option, .control, .shift])
            .rawValue

        keyCode = Int(event.keyCode)
        modifiers = mods
        onCapture?(keyCode, mods)

        isRecording = false
        needsDisplay = true
    }

    private func modifierString() -> String {
        var result = ""
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)

        if mods.contains(.control) { result += "⌃" }
        if mods.contains(.option) { result += "⌥" }
        if mods.contains(.shift) { result += "⇧" }
        if mods.contains(.command) { result += "⌘" }

        return result
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgColor: NSColor = isRecording
            ? .controlAccentColor.withAlphaComponent(0.15)
            : .quaternarySystemFill

        bgColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        var text = "Click to record"
        if isRecording {
            text = "Press keys..."
        } else if keyCode != 0 {
            text = modifierString() + keyName(for: keyCode)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 11, weight: .medium)
        ]

        let size = text.size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )

        text.draw(at: point, withAttributes: attrs)
    }

    private func keyName(for code: Int) -> String {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J",
            40: "K", 45: "N", 46: "M", 49: "Space"
        ]

        return map[code] ?? "Key\(code)"
    }
}
