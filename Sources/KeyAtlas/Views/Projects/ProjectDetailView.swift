import SwiftUI

/// Full project detail view
struct ProjectDetailView: View {
    let slug: String
    @State private var viewModel = ProjectDetailViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.project == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.project == nil {
                ErrorView(message: error) { await viewModel.loadProject(slug: slug) }
            } else if let project = viewModel.project {
                projectContent(project)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadProject(slug: slug) }
    }

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                CachedImage(url: project.heroImageUrl)
                    .frame(height: 250)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        heroOverlay(project)
                    }

                VStack(alignment: .leading, spacing: 20) {
                    // Action buttons
                    actionRow(project)

                    // GB dates
                    if let start = project.gbStartDate, let end = project.gbEndDate {
                        HStack(spacing: 16) {
                            dateChip(label: "Starts", date: start)
                            dateChip(label: "Ends", date: end)
                            if let delivery = project.estimatedDelivery {
                                dateChip(label: "Delivery", date: delivery)
                            }
                        }
                    }

                    // Pricing
                    if let pricing = project.pricing?.formattedRange {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pricing")
                                .font(.headline)
                            Text(pricing)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }

                    // Description
                    if let desc = project.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.headline)
                            Text(desc)
                                .font(.body)
                        }
                    }

                    // Vendors
                    if let vendors = project.vendors, !vendors.isEmpty {
                        vendorSection(vendors)
                    }

                    // Gallery
                    if let gallery = project.gallery, !gallery.isEmpty {
                        GalleryPreview(images: gallery)
                    }

                    // Timeline
                    if let timeline = project.timeline, !timeline.isEmpty {
                        timelineSection(timeline)
                    }

                    // Links
                    if let links = project.links, !links.isEmpty {
                        linksSection(links)
                    }

                    // Comments
                    commentsSection(project)
                }
                .padding()
            }
        }
        .navigationTitle(project.title)
    }

    // MARK: - Hero overlay

    private func heroOverlay(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusBadge(status: project.status)
            Text(project.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .shadow(radius: 4)
            if let designer = project.designer {
                Text("by \(designer.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Action row

    private func actionRow(_ project: Project) -> some View {
        HStack(spacing: 16) {
            Button {
                Task { await viewModel.toggleFollow() }
            } label: {
                Label(
                    project.isFollowing == true ? "Following" : "Follow",
                    systemImage: project.isFollowing == true ? "bell.fill" : "bell"
                )
                .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .tint(project.isFollowing == true ? .gray : .blue)
            .disabled(viewModel.isTogglingFollow)
            .accessibilityLabel(project.isFollowing == true ? "Unfollow project" : "Follow project")

            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Label(
                    "\(project.favoriteCount ?? 0)",
                    systemImage: project.isFavorited == true ? "heart.fill" : "heart"
                )
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(project.isFavorited == true ? .red : .gray)
            .disabled(viewModel.isTogglingFavorite)
            .accessibilityLabel(project.isFavorited == true ? "Unfavorite" : "Favorite")

            Spacer()

            if let follows = project.followCount {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                    Text("\(follows)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Date chip

    private func dateChip(label: String, date: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(date.readableDate)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Vendors

    private func vendorSection(_ vendors: [ProjectVendor]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vendors")
                .font(.headline)
            ForEach(vendors) { pv in
                if let vendor = pv.vendor {
                    HStack {
                        AvatarImage(url: vendor.logoUrl, size: 32)
                        VStack(alignment: .leading) {
                            Text(vendor.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if let region = pv.region {
                                Text(region)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let urlStr = pv.url, let url = URL(string: urlStr) {
                            Button {
                                openURL(url)
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .accessibilityLabel("Open \(vendor.name) storefront")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Timeline

    private func timelineSection(_ entries: [TimelineEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let desc = entry.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let date = entry.date {
                            Text(date.readableDate)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Links

    private func linksSection(_ links: [ProjectLink]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)
            ForEach(links) { link in
                if let url = URL(string: link.url) {
                    Button {
                        openURL(url)
                    } label: {
                        Label(link.title, systemImage: "link")
                            .font(.subheadline)
                    }
                    .accessibilityLabel("Open link: \(link.title)")
                }
            }
        }
    }

    // MARK: - Comments

    private func commentsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.headline)

            // Comment input
            HStack {
                TextField("Add a comment…", text: $viewModel.commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .accessibilityLabel("Comment text field")

                Button {
                    Task { await viewModel.postComment() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isPostingComment)
                .accessibilityLabel("Post comment")
            }

            // Comment list
            if let comments = project.comments {
                if comments.isEmpty {
                    Text("No comments yet. Be the first!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                AvatarImage(url: comment.author?.effectiveAvatarUrl, size: 24)
                                Text(comment.author?.displayName ?? "Anonymous")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(comment.createdAt.relativeTime)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(comment.content)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }
}
