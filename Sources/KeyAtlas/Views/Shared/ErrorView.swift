import SwiftUI

/// Reusable error state view with retry action
struct ErrorView: View {
    let message: String
    var retryAction: (() async -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retryAction {
                Button("Try Again") {
                    Task { await retryAction() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .accessibilityLabel("Error: \(message)")
    }
}

/// Empty state view
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }
}

/// Loading overlay
struct LoadingOverlay: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}
