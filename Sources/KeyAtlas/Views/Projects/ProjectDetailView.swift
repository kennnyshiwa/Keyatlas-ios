import SwiftUI

/// Full project detail view
struct ProjectDetailView: View {
    let slug: String
    @State private var viewModel = ProjectDetailViewModel()
    @State private var showEditSheet = false
    @Environment(AuthService.self) private var authService
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
            } else {
                ErrorView(message: "Unable to load project") { await viewModel.loadProject(slug: slug) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let project = viewModel.project,
               canQuickEdit(project: project) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Quick edit project")
                }
            }
        }
        .task { await viewModel.loadProject(slug: slug) }
        .sheet(isPresented: $showEditSheet) {
            if let project = viewModel.project {
                ProjectSubmissionView(projectToEdit: project)
            }
        }
    }

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero image
                ZStack(alignment: .bottomLeading) {
                    CachedImage(url: project.heroImageUrl, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(.black.opacity(0.03))
                        .clipped()

                    heroOverlay(project)
                }
                .frame(maxWidth: .infinity)
                .clipped()

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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Description")
                                .font(.headline)
                            descriptionContent(desc)
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

                    // Updates
                    if let updates = project.updates, !updates.isEmpty {
                        updatesSection(updates)
                    }

                    // Links
                    if let links = project.links, !links.isEmpty {
                        linksSection(links)
                    }

                    // Comments
                    commentsSection(project)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .navigationTitle("Project")
    }

    // MARK: - Hero overlay

    private func heroOverlay(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusBadge(status: project.status)
            Text(project.title.keyAtlasDisplayText)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Description rendering (text + inline images)

    @ViewBuilder
    private func descriptionContent(_ raw: String) -> some View {
        let segments = descriptionSegments(from: raw)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .text(let text):
                    if !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.92)
                    }
                case .image(let url):
                    CachedImage(url: url, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120, maxHeight: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .link(let label, let url):
                    if let linkURL = URL(string: url) {
                        Link(label, destination: linkURL)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(label)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private struct DescriptionSegment: Identifiable {
        enum Kind {
            case text(String)
            case image(String)
            case link(label: String, url: String)
        }
        let id: Int
        let kind: Kind
    }

    private func descriptionSegments(from raw: String) -> [DescriptionSegment] {
        let pattern = #"<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>|<a[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return [DescriptionSegment(id: 0, kind: .text(raw.keyAtlasDisplayText))]
        }

        let ns = raw as NSString
        let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty {
            return [DescriptionSegment(id: 0, kind: .text(raw.keyAtlasDisplayText))]
        }

        var segments: [DescriptionSegment] = []
        var cursor = 0
        var id = 0

        for m in matches {
            let full = m.range(at: 0)

            if full.location > cursor {
                let textChunk = ns.substring(with: NSRange(location: cursor, length: full.location - cursor))
                let cleaned = textChunk.keyAtlasDisplayText
                if !cleaned.isEmpty {
                    segments.append(DescriptionSegment(id: id, kind: .text(cleaned)))
                    id += 1
                }
            }

            let imgSrc = m.range(at: 1)
            let linkHref = m.range(at: 2)
            let linkLabel = m.range(at: 3)

            if imgSrc.location != NSNotFound {
                let url = ns.substring(with: imgSrc)
                if !url.isEmpty {
                    segments.append(DescriptionSegment(id: id, kind: .image(url)))
                    id += 1
                }
            } else if linkHref.location != NSNotFound {
                let url = ns.substring(with: linkHref)
                let labelRaw = linkLabel.location != NSNotFound ? ns.substring(with: linkLabel) : url
                let label = labelRaw.keyAtlasDisplayText.isEmpty ? url : labelRaw.keyAtlasDisplayText
                if !url.isEmpty {
                    segments.append(DescriptionSegment(id: id, kind: .link(label: label, url: url)))
                    id += 1
                }
            }

            cursor = full.location + full.length
        }

        if cursor < ns.length {
            let trailing = ns.substring(from: cursor).keyAtlasDisplayText
            if !trailing.isEmpty {
                segments.append(DescriptionSegment(id: id, kind: .text(trailing)))
            }
        }

        return segments.isEmpty
            ? [DescriptionSegment(id: 0, kind: .text(raw.keyAtlasDisplayText))]
            : segments
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

    private func updatesSection(_ updates: [ProjectUpdate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Updates")
                .font(.headline)
            ForEach(updates) { update in
                VStack(alignment: .leading, spacing: 4) {
                    Text(update.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(update.content.keyAtlasDisplayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(update.createdAt.relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private func canQuickEdit(project: Project) -> Bool {
        guard let me = authService.currentUser?.id,
              let owner = project.designer?.id else { return false }
        return me == owner
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
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                                .padding(.top, 2)
                            Text(link.title.keyAtlasDisplayText)
                                .font(.subheadline)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
