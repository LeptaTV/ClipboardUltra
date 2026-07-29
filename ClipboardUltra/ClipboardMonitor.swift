import AppKit
import SwiftData

final class ClipboardMonitor {
    private var monitorTimer: Timer?
    private var purgeTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    var modelContext: ModelContext?

    private let maxHistoryItems = 500

    func start() {
        stop()

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }

        purgeTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.purgeExpired()
        }
    }

    func stop() {
        monitorTimer?.invalidate()
        purgeTimer?.invalidate()
        monitorTimer = nil
        purgeTimer = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if isSourceExcluded() { return }

        let sourceAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            if isDuplicateImage(imageData) { return }

            let item = ClipItem(
                content: "Image",
                category: "Image",
                imageData: imageData,
                sourceApp: sourceAppName
            )

            modelContext?.insert(item)
            enforceHistoryLimit()
            try? modelContext?.save()
            return
        }

        guard let rawContent = pasteboard.string(forType: .string) else { return }
        let content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        if isDuplicateOfRecent(content) { return }

        let category = detectCategory(for: content)
        let item = ClipItem(
            content: content,
            category: category,
            imageData: nil,
            sourceApp: sourceAppName
        )

        modelContext?.insert(item)
        enforceHistoryLimit()
        try? modelContext?.save()
    }

    private func isSourceExcluded() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        let excluded = UserDefaults.standard.stringArray(forKey: "excludedBundleIds") ?? []
        return excluded.contains(bundleId)
    }

    private func isDuplicateOfRecent(_ content: String) -> Bool {
        guard let context = modelContext else { return false }

        var descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.copiedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5

        guard let recentItems = try? context.fetch(descriptor) else { return false }

        return recentItems.contains {
            $0.category != "Image" &&
            $0.content.trimmingCharacters(in: .whitespacesAndNewlines) == content
        }
    }

    private func isDuplicateImage(_ data: Data) -> Bool {
        guard let context = modelContext else { return false }

        var descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.copiedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 5

        guard let recentItems = try? context.fetch(descriptor) else { return false }

        return recentItems.contains { $0.imageData == data }
    }

    private func enforceHistoryLimit() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.copiedAt, order: .reverse)]
        )

        guard let allItems = try? context.fetch(descriptor) else { return }
        guard allItems.count > maxHistoryItems else { return }

        let overflowItems = allItems.dropFirst(maxHistoryItems)

        for item in overflowItems {
            context.delete(item)
        }
    }

    private func purgeExpired() {
        guard let context = modelContext else { return }

        let days = UserDefaults.standard.integer(forKey: "expirationDays")
        guard days > 0 else { return }

        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            return
        }

        let descriptor = FetchDescriptor<ClipItem>()
        guard let allItems = try? context.fetch(descriptor) else { return }

        for item in allItems where !item.isPinned && item.copiedAt < cutoff {
            context.delete(item)
        }

        try? context.save()
    }

    private func detectCategory(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(location: 0, length: text.utf16.count)

        if isNumberLike(trimmed) {
            return "Number"
        }

        if let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = linkDetector.firstMatch(in: text, options: [], range: range),
           let url = match.url {
            if url.scheme == "mailto" || trimmed.contains("@") {
                return "Email"
            }
            return "URL"
        }

        return "Text"
    }

    private func isNumberLike(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let hasLetter = text.contains { $0.isLetter }
        guard !hasLetter else { return false }
        let hasDigit = text.contains { $0.isNumber }
        return hasDigit
    }
}
