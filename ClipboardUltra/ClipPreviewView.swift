import SwiftUI
import AppKit

struct ClipPreviewView: View {
    let item: ClipItem
    @Environment(\.colorScheme) private var colorScheme

    private var panelBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1)),
                    Color(nsColor: NSColor(calibratedWhite: 0.13, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.992, alpha: 1)),
                    Color(nsColor: NSColor(calibratedRed: 0.945, green: 0.95, blue: 0.97, alpha: 1))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.white.opacity(0.88)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.25)
            : Color.black.opacity(0.10)
    }

    var body: some View {
        Group {
            if item.category == "Image",
               let data = item.imageData,
               let nsImage = NSImage(data: data) {
                imagePreview(nsImage)
            } else {
                textPreview(item.content)
            }
        }
        .background(panelBackground)
    }

    private func imagePreview(_ nsImage: NSImage) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Image Preview", systemImage: "photo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer(minLength: 10)

            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(maxWidth: 520, maxHeight: 340)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(borderColor, lineWidth: 1)
                        )
                )
                .shadow(color: shadowColor, radius: 16, x: 0, y: 6)
                .padding(.horizontal, 16)

            Spacer(minLength: 14)
        }
        .frame(width: 580, height: 430)
    }

    private func textPreview(_ text: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("Text Preview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Text(text)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .frame(maxWidth: 330, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                    )
                    .shadow(color: shadowColor, radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentMargins(.trailing, 14, for: .scrollIndicators)
        .frame(minWidth: 240, idealWidth: 340, maxWidth: 400,
               minHeight: 90, idealHeight: 180, maxHeight: 320)
    }
}
