import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Query(sort: \ClipItem.copiedAt, order: .reverse) private var items: [ClipItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showClearAllConfirmation = false
    @State private var showCopiedToast = false
    @State private var showSettings = false

    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "dark"

    private let categories = ["All", "Text", "Number", "URL", "Email", "Image"]

    private var filteredItems: [ClipItem] {
        items
            .filter { item in
                (selectedCategory == "All" || item.category == selectedCategory) &&
                (
                    searchText.isEmpty ||
                    item.content.localizedCaseInsensitiveContains(searchText) ||
                    (item.sourceApp?.localizedCaseInsensitiveContains(searchText) ?? false)
                )
            }
            .sorted {
                if $0.isPinned != $1.isPinned {
                    return $0.isPinned && !$1.isPinned
                }
                return $0.copiedAt > $1.copiedAt
            }
    }

    private var groupedItems: [(date: Date, items: [ClipItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredItems) { item in
            calendar.startOfDay(for: item.copiedAt)
        }

        return grouped
            .map {
                (
                    date: $0.key,
                    items: $0.value.sorted { lhs, rhs in
                        if lhs.isPinned != rhs.isPinned {
                            return lhs.isPinned && !rhs.isPinned
                        }
                        return lhs.copiedAt > rhs.copiedAt
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var panelBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(calibratedWhite: 0.12, alpha: 1))
            : Color(nsColor: NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.975, alpha: 1))
    }

    private var sectionBubble: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color(nsColor: NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.955, alpha: 1))
    }

    private var softBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    private var softShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.black.opacity(0.07)
    }

    var body: some View {
        ZStack {
            panelBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if showSettings {
                    SettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                } else {
                    filtersSection

                    Divider()
                        .overlay(softBorder)
                        .padding(.top, 4)

                    listSection
                }
            }
            .frame(width: 336, height: 440)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(showClearAllConfirmation)

            if showClearAllConfirmation {
                clearAllDialog
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if showCopiedToast {
                copiedToast
            }
        }
        .frame(width: 336, height: 440)
        .animation(.easeOut(duration: 0.16), value: showClearAllConfirmation)
        .preferredColorScheme(preferredColorScheme == "dark" ? .dark : .light)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("ClipboardUltra")
                .font(.system(size: 12.5, weight: .bold))

            Spacer()

            Button {
                DonationManager.openDonationPage()
            } label: {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Buy me a coffee")

            Button {
                showClearAllConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Clear all history")
            .disabled(items.isEmpty)

            Button {
                preferredColorScheme = preferredColorScheme == "dark" ? "light" : "dark"
            } label: {
                Image(systemName: preferredColorScheme == "dark" ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 10.5))
            }
            .buttonStyle(.plain)

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var filtersSection: some View {
        VStack(spacing: 8) {
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(sectionBubble)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(softBorder, lineWidth: 1)
                        )
                        .shadow(color: softShadow, radius: 6, x: 0, y: 2)
                )
                .padding(.horizontal, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category)
                                .font(.system(size: 10.5, weight: selectedCategory == category ? .semibold : .medium))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Group {
                                        if selectedCategory == category {
                                            Capsule(style: .continuous)
                                                .fill(Color.accentColor)
                                                .shadow(color: Color.accentColor.opacity(0.22), radius: 5, x: 0, y: 2)
                                        } else {
                                            Capsule(style: .continuous)
                                                .fill(sectionBubble)
                                                .overlay(
                                                    Capsule(style: .continuous)
                                                        .stroke(softBorder, lineWidth: 1)
                                                )
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 2)
    }

    private var listSection: some View {
        Group {
            if groupedItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()

                    Image(systemName: "tray")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)

                    Text("No clipboard items yet")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11.5))

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groupedItems, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sectionTitle(for: group.date))
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 2)

                                LazyVStack(spacing: 6) {
                                    ForEach(group.items) { item in
                                        ClipRowView(
                                            item: item,
                                            onCopy: { copyToClipboard(item) },
                                            onDelete: {
                                                modelContext.delete(item)
                                                try? modelContext.save()
                                            },
                                            onTogglePin: {
                                                item.isPinned.toggle()
                                                try? modelContext.save()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var clearAllDialog: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.red)

                Text("Delete all items?")
                    .font(.system(size: 14, weight: .semibold))

                Text("This will permanently remove every item from your clipboard history.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 210)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    showClearAllConfirmation = false
                }
                .buttonStyle(.bordered)

                Button("Delete All", role: .destructive) {
                    for item in items {
                        modelContext.delete(item)
                    }
                    try? modelContext.save()
                    showClearAllConfirmation = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(16)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(softBorder, lineWidth: 1)
                )
        )
        .shadow(color: softShadow, radius: 18, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.06))
                .blur(radius: 16)
                .offset(y: 8)
                .allowsHitTesting(false)
        )
    }

    private var copiedToast: some View {
        VStack {
            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))

                Text("Copied")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(sectionBubble)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(softBorder, lineWidth: 1)
                    )
            )
            .shadow(color: softShadow, radius: 6, x: 0, y: 2)
            .padding(.bottom, 10)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(1)
    }

    private func copyToClipboard(_ item: ClipItem) {
        NSPasteboard.general.clearContents()

        if item.category == "Image", let data = item.imageData {
            NSPasteboard.general.setData(data, forType: .png)
        } else {
            NSPasteboard.general.setString(item.content, forType: .string)
        }

        showCopiedToast = false
        DispatchQueue.main.async {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showCopiedToast = false
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
