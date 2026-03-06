import SwiftUI

/// Main tab bar container
struct ContentView: View {
    @Environment(AuthService.self) private var authService
    @State private var selectedTab = 0
    @State private var showSearch = false
    @State private var showSubmitProject = false
    @State private var unreadNotificationCount = 0
    @State private var notificationTimer: Timer?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home — Project listing
            ProjectListView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            // Discover — IC, GB, Ending Soon, New
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sparkle.magnifyingglass")
                }
                .tag(1)

            // Forums
            ForumListView()
                .tabItem {
                    Label("Forums", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(2)

            // Calendar
            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(3)

            // Profile
            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .badge(unreadNotificationCount > 0 ? unreadNotificationCount : 0)
                .tag(4)
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating action buttons
            VStack(spacing: 12) {
                // Search FAB
                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.blue))
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Search")

                // Submit project FAB (authenticated only)
                if authService.isAuthenticated {
                    Button {
                        showSubmitProject = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.green))
                            .shadow(radius: 4)
                    }
                    .accessibilityLabel("Submit new project")
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 80)
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
        .fullScreenCover(isPresented: $showSubmitProject) {
            ProjectSubmissionView()
        }
        .task {
            await fetchUnreadCount()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Refresh count when switching to profile tab
            if newTab == 4 && authService.isAuthenticated {
                Task { await fetchUnreadCount() }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                Task { await fetchUnreadCount() }
                startNotificationTimer()
            } else {
                stopNotificationTimer()
                unreadNotificationCount = 0
            }
        }
        .onAppear {
            if authService.isAuthenticated {
                startNotificationTimer()
            }
        }
        .onDisappear {
            stopNotificationTimer()
        }
    }

    private func fetchUnreadCount() async {
        guard authService.isAuthenticated else { return }
        do {
            struct NotifResponse: Codable, Sendable { let data: [AppNotification] }
            let response: NotifResponse = try await APIClient.shared.request(
                path: "/api/v1/notifications",
                authenticated: true
            )
            let count = response.data.filter { !$0.isRead }.count
            await MainActor.run { unreadNotificationCount = count }
        } catch {
            // Silently fail
        }
    }

    private func startNotificationTimer() {
        stopNotificationTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { await fetchUnreadCount() }
        }
        notificationTimer = timer
    }

    private func stopNotificationTimer() {
        notificationTimer?.invalidate()
        notificationTimer = nil
    }
}
