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
            GeometryReader { geo in
                CachedImage(url: project.heroImageUrl)
                    .frame(width: geo.size.width, height: heroHeight)
                    .clipped()
            }
            .frame(height: heroHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                // Status + Category row
                HStack(alignment: .top, spacing: 6) {
                    compactBadge(
                        title: project.status.displayName,
                        icon: project.status.iconName,
                        foreground: Color.forStatus(project.status),
                        background: Color.forStatus(project.status).opacity(0.15)
                    )

                    if project.isRecentlyUpdated {
                        compactBadge(
                            title: "Recently updated",
                            icon: nil,
                            foreground: .orange,
                            background: .orange.opacity(0.16)
                        )
                    }

                    Spacer(minLength: 4)

                    if let profile = project.profile, !profile.isEmpty {
                        Text(profile)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
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

                // Bottom row: pricing + social proof + date
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let price = project.pricing?.formattedRange {
                            Text(price)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

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

                    HStack(spacing: 12) {
                        socialStat(icon: "person.2", value: project.followCount ?? 0)
                        socialStat(icon: "heart", value: project.favoriteCount ?? 0)
                        socialStat(icon: "bubble.left", value: project.commentCount)
                    }
                    .foregroundStyle(.secondary)
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

    private func socialStat(icon: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func compactBadge(title: String, icon: String?, foreground: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foreground)
        .frame(minHeight: 26)
        .frame(width: 72)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(background)
        .clipShape(Capsule())
    }
}
