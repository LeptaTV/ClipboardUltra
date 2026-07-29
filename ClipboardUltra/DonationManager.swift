import AppKit

enum DonationManager {
    static let donationURL = "https://buymeacoffee.com/lepta"

    static func openDonationPage() {
        guard let url = URL(string: donationURL) else { return }
        NSWorkspace.shared.open(url)
    }
}
