import SwiftUI
import UIKit

/// Full project detail view
struct ProjectDetailView: View {
    let slug: String
    @State private var viewModel = ProjectDetailViewModel()
    @State private var showEditSheet = false
    @State private var showFollowNotice = false
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
            if let project = viewModel.project {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(
                            item: shareURL(for: project, ref: "ios_share"),
                            subject: Text(project.title),
                            message: Text(shareMessage(for: project, ref: "ios_share"))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            copyShareMessage(project: project, ref: "ios_share")
                        } label: {
                            Label("Copy message", systemImage: "doc.on.doc")
                        }

                        Button {
                            copyShareMessage(project: project, ref: "ios_discord")
                        } label: {
                            Label("Copy Discord message", systemImage: "bubble.left.and.bubble.right")
                        }

                        Button {
                            copyShareMessage(project: project, ref: "ios_reddit")
                        } label: {
                            Label("Copy Reddit message", systemImage: "text.bubble")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share project")

                    // Edit button (owner only)
                    if canQuickEdit(project: project) {
                        Button {
                            showEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Quick edit project")
                    }
                }
            }
        }
        .task { await viewModel.loadProject(slug: slug) }
        .onChange(of: viewModel.followConfirmationMessage) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { showFollowNotice = true }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { showFollowNotice = false }
                    viewModel.followConfirmationMessage = nil
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if showFollowNotice, let message = viewModel.followConfirmationMessage {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .accessibilityLabel("Follow confirmation: \(message)")
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            Task { await viewModel.loadProject(slug: slug) }
        }) {
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
                    CachedImage(url: project.heroImageUrl, contentMode: .fit, targetSize: CGSize(width: 600, height: 250), priority: .high)
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(.black.opacity(0.03))
                        .clipped()

                    heroOverlay(project)
                }
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 20) {
                    // Category & Profile tags
                    if project.category != nil || (project.profile != nil && !project.profile!.isEmpty) {
                        HStack(spacing: 8) {
                            if let category = project.category {
                                capsuleTag(category.name, icon: "tag", color: .blue)
                            }
                            if let profile = project.profile, !profile.isEmpty {
                                capsuleTag(profile, icon: "cube", color: .purple)
                            }
                        }
                    }

                    // Tags
                    if let tags = project.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

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

                    // Sound Tests
                    if let soundTests = project.soundTests, !soundTests.isEmpty {
                        soundTestsSection(soundTests)
                    }

                    // Links
                    if let links = project.links, !links.isEmpty {
                        linksSection(links)
                    }

                    // Comments
                    commentsSection(project)

                    // Related projects
                    if !viewModel.relatedProjects.isEmpty {
                        relatedProjectsSection
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .navigationTitle("Project")
        .refreshable {
            await viewModel.loadProject(slug: slug)
        }
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
        VStack(spacing: 10) {
            // Buttons row
            HStack(spacing: 12) {
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
                        "Favorite",
                        systemImage: project.isFavorited == true ? "heart.fill" : "heart"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(project.isFavorited == true ? .red : .gray)
                .disabled(viewModel.isTogglingFavorite)
                .accessibilityLabel(project.isFavorited == true ? "Unfavorite" : "Favorite")

                Button {
                    Task { await viewModel.toggleCollection() }
                } label: {
                    Label(
                        "Collect",
                        systemImage: project.isInCollection == true ? "tray.full.fill" : "tray.and.arrow.down"
                    )
                    .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(project.isInCollection == true ? .orange : .gray)
                .disabled(viewModel.isTogglingCollection)
                .accessibilityLabel(project.isInCollection == true ? "Remove from collection" : "Add to collection")

                Spacer()
            }

            // Stats row
            HStack(spacing: 16) {
                statPill(icon: "person.2", label: "followers", value: project.followCount ?? 0)
                statPill(icon: "heart", label: "favorites", value: project.favoriteCount ?? 0)
                statPill(icon: "bubble.left", label: "comments", value: project.commentCount)
                Spacer()
            }
        }
    }

    private func statPill(icon: String, label: String = "", value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel("\(value) \(label.isEmpty ? "interactions" : label)")
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
                    CachedImage(url: url, contentMode: .fit, targetSize: CGSize(width: 400, height: 340), priority: .low)
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

                // If the anchor wraps an image, render it as image (common Geekhack pattern)
                if let imgRegex = try? NSRegularExpression(pattern: #"<img[^>]*src=[\"']([^\"']+)[\"'][^>]*>"#, options: [.caseInsensitive]),
                   let imgMatch = imgRegex.firstMatch(in: labelRaw, options: [], range: NSRange(location: 0, length: (labelRaw as NSString).length)),
                   imgMatch.range(at: 1).location != NSNotFound {
                    let imgURL = (labelRaw as NSString).substring(with: imgMatch.range(at: 1))
                    if !imgURL.isEmpty {
                        segments.append(DescriptionSegment(id: id, kind: .image(imgURL)))
                        id += 1
                    }
                } else {
                    let label = labelRaw.keyAtlasDisplayText.isEmpty ? url : labelRaw.keyAtlasDisplayText
                    if !url.isEmpty {
                        segments.append(DescriptionSegment(id: id, kind: .link(label: label, url: url)))
                        id += 1
                    }
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

    private func shareURL(for project: Project, ref: String) -> URL {
        var components = URLComponents(string: "https://keyatlas.io/projects/\(project.slug)")!
        components.queryItems = [
            URLQueryItem(name: "ref", value: ref),
        ]
        return components.url ?? URL(string: "https://keyatlas.io/projects/\(project.slug)")!
    }

    private func shareMessage(for project: Project, ref: String) -> String {
        return shareURL(for: project, ref: ref).absoluteString
    }

    private func copyShareMessage(project: Project, ref: String) {
        UIPasteboard.general.string = shareMessage(for: project, ref: ref)
    }

    private func canQuickEdit(project: Project) -> Bool {
        guard let me = authService.currentUser else { return false }
        if me.isAdmin { return true }
        guard let owner = project.designer?.id else { return false }
        return me.id == owner
    }

    // MARK: - Capsule tag

    private func capsuleTag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    // MARK: - Related projects

    private var relatedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Related Projects")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.relatedProjects) { related in
                        NavigationLink(value: related.slug) {
                            VStack(alignment: .leading, spacing: 4) {
                                CachedImage(url: related.heroImageUrl, contentMode: .fill, targetSize: CGSize(width: 160, height: 100))
                                    .frame(width: 160, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(related.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 160, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sound Tests

    private func soundTestsSection(_ soundTests: [SoundTest]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sound Tests")
                .font(.headline)
            ForEach(soundTests) { test in
                if let url = URL(string: test.url) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(test.title ?? "Sound Test")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let platform = test.platform, !platform.isEmpty {
                                    Text(platform)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityLabel("Play sound test: \(test.title ?? "Sound Test")")
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
                            RichCommentView(content: comment.content)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }
}
