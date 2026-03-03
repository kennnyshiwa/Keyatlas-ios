import SwiftUI

/// Colored badge showing project status
struct StatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.forStatus(status).opacity(0.15))
        .foregroundStyle(Color.forStatus(status))
        .clipShape(Capsule())
        .accessibilityLabel("Status: \(status.displayName)")
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(ProjectStatus.allCases, id: \.self) { status in
            StatusBadge(status: status)
        }
    }
    .padding()
}
