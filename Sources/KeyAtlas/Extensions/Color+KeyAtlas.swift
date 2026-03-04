import SwiftUI

extension Color {
    static let kaAccent = Color("AccentColor", bundle: nil)
    static let kaPrimary = Color.blue
    static let kaSecondary = Color.gray

    static func forStatus(_ status: ProjectStatus) -> Color {
        switch status {
        case .interestCheck: .blue
        case .groupBuy: .green
        case .production: .orange
        case .shipping: .purple
        case .extras: .indigo
        case .completed: .gray
        case .archived: .gray
        case .cancelled: .red
        case .inStock: .teal
        }
    }
}

extension View {
    /// Applies consistent card styling
    func cardStyle() -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
