import SwiftUI
import SwiftData
import AppKit

@main
struct ClipboardUltraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var container: ModelContainer!
    var monitor: ClipboardMonitor!
    var hostingController: NSHostingController<AnyView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            container = try ModelContainer(for: ClipItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        monitor = ClipboardMonitor()
        monitor.modelContext = container.mainContext
        monitor.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeMenuBarImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "ClipboardUltra"
        }

        let rootView = AnyView(
            ContentView()
                .modelContainer(container)
        )

        hostingController = NSHostingController(rootView: rootView)

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 336, height: 440)

        applyAppearanceToPopoverOnly()

        ShortcutManager.shared.onTrigger = { [weak self] in
            self?.showPopoverFromShortcut()
        }
        ShortcutManager.shared.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        ShortcutManager.shared.stopListening()
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopoverFromShortcut() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            self.showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        applyAppearanceToPopoverOnly()

        if popover.isShown {
            popover.performClose(nil)
        }

        popover.contentSize = NSSize(width: 336, height: 440)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func applyAppearanceToPopoverOnly() {
        let preferred = UserDefaults.standard.string(forKey: "preferredColorScheme") ?? "dark"
        let appearanceName: NSAppearance.Name = (preferred == "dark") ? .darkAqua : .aqua
        let appearance = NSAppearance(named: appearanceName)

        hostingController?.view.appearance = appearance
        popover?.contentViewController?.view.appearance = appearance
        popover?.contentViewController?.view.window?.appearance = appearance
    }

    private func makeMenuBarImage() -> NSImage? {
        if let original = NSImage(named: "MenuBarIcon"),
           let image = original.copy() as? NSImage {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        if let fallback = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipboardUltra") {
            fallback.isTemplate = true
            fallback.size = NSSize(width: 18, height: 18)
            return fallback
        }

        return nil
    }
}
