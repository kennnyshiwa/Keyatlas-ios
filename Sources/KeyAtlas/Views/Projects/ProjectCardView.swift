import SwiftUI

/// Card view for project in a list
struct ProjectCardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let project: Project

    private var heroHeight: CGFloat {
        horizontalSizeClass == .compact ? 132 : 180
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image
            CachedImage(url: project.heroImageUrl)
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                // Status + Category row
                HStack {
                    StatusBadge(status: project.status)
                    Spacer()
                    if let category = project.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Title
                Text(project.title)
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Designer
                if let designer = project.designer {
                    HStack(spacing: 4) {
                        AvatarImage(url: designer.effectiveAvatarUrl, size: 20)
                        Text(designer.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Bottom row: pricing, dates, follow count
                HStack {
                    if let price = project.pricing?.formattedRange {
                        Text(price)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    if let follows = project.followCount, follows > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2")
                                .font(.caption2)
                            Text("\(follows)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let gbEnd = project.gbEndDate {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Ends \(gbEnd.readableDate)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.title), \(project.status.displayName)")
    }
}
