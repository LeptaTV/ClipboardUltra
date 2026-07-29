import SwiftUI
import AppKit

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var showPreview = false

    private var categoryIcon: String {
        switch item.category {
        case "Number":
            return "number"
        case "URL":
            return "link"
        case "Email":
            return "envelope.fill"
        case "Image":
            return "photo.fill"
        default:
            return "doc.text"
        }
    }

    private var categoryColor: Color {
        switch item.category {
        case "Number":
            return .orange
        case "URL":
            return .blue
        case "Email":
            return .purple
        case "Image":
            return .pink
        default:
            return .gray
        }
    }

    private var bubbleColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(isHovering ? 0.09 : 0.07)
            : Color(nsColor: NSColor(calibratedRed: 0.955, green: 0.955, blue: 0.97, alpha: 1))
    }

    private var bubbleBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    private var bubbleShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.06)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: categoryIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(categoryColor)
                .frame(width: 20, height: 20)
                .background(categoryColor.opacity(0.14))
                .clipShape(Circle())

            Button(action: onCopy) {
                VStack(alignment: .leading, spacing: 3) {
                    if item.category == "Image",
                       let data = item.imageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text(item.content)
                            .lineLimit(2)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }

                    HStack(spacing: 5) {
                        Text(item.category)

                        if let sourceApp = item.sourceApp, !sourceApp.isEmpty {
                            Text("• \(sourceApp)")
                        }
                    }
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .foregroundColor(item.isPinned ? .yellow : .secondary.opacity(0.65))
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Pin")

                Button {
                    showPreview.toggle()
                } label: {
                    Image(systemName: "binoculars.fill")
                        .foregroundColor(.secondary.opacity(0.78))
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Preview")
                .popover(isPresented: $showPreview, arrowEdge: .trailing) {
                    ClipPreviewView(item: item)
                }

                Button {
                    shareItem()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary.opacity(0.75))
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Share")

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.65))
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(isHovering ? 1 : 0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(bubbleColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(bubbleBorder, lineWidth: 1)
                )
        )
        .shadow(color: bubbleShadow, radius: 5, x: 0, y: 2)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func shareItem() {
        var itemsToShare: [Any] = []

        if item.category == "Image",
           let data = item.imageData,
           let image = NSImage(data: data) {
            itemsToShare = [image]
        } else {
            itemsToShare = [item.content]
        }

        let picker = NSSharingServicePicker(items: itemsToShare)

        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else {
            return
        }

        let rect = NSRect(
            x: contentView.bounds.midX,
            y: contentView.bounds.midY,
            width: 1,
            height: 1
        )

        picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
    }
}
