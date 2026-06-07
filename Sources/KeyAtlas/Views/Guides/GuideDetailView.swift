import SwiftUI

struct GuideDetailView: View {
    let slug: String
    @State private var viewModel = GuideViewModel()
    @State private var showEditSheet = false
    @Environment(AuthService.self) private var authService

    private var canEdit: Bool {
        guard let user = authService.currentUser,
              let guide = viewModel.selectedGuide else { return false }
        return guide.author?.id == user.id || user.isAdmin
    }

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

                            if let content = guide.content, !content.isEmpty {
                                HTMLContentView(html: content)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                ErrorView(message: "Unable to load guide") { await viewModel.loadGuide(slug: slug) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit, viewModel.selectedGuide != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let guide = viewModel.selectedGuide {
                GuideEditView(guide: guide) {
                    Task { await viewModel.loadGuide(slug: slug) }
                }
            }
        }
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
