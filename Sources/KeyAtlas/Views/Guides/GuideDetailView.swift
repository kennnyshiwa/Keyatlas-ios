import SwiftUI

struct GuideDetailView: View {
    let slug: String
    @State private var viewModel = GuideViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.selectedGuide == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.selectedGuide == nil {
                ErrorView(message: error) { await viewModel.loadGuide(slug: slug) }
            } else if let guide = viewModel.selectedGuide {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Hero
                        if guide.heroImage != nil {
                            CachedImage(url: guide.heroImage)
                                .frame(height: 200)
                                .clipped()
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text(guide.title)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack {
                                if let author = guide.author {
                                    AvatarImage(url: author.effectiveAvatarUrl, size: 28)
                                    Text(author.displayName)
                                        .font(.subheadline)
                                }
                                Spacer()
                                Text(guide.createdAt.readableDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let difficulty = guide.difficulty {
                                Text(difficulty)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.quaternary)
                                    .clipShape(Capsule())
                            }

                            if let content = guide.content {
                                RichCommentView(content: content)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadGuide(slug: slug) }
    }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ), proposal: .unspecified)
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}
