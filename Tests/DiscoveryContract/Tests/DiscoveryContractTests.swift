import Foundation
import Testing
@testable import DiscoveryContract

private final class Wire: URLProtocol, @unchecked Sendable {
    struct State {
        var requests: [URLRequest] = []
        var status = 200
        var empty = false
        var held: [Wire] = []
        var hold = false
        var responseCookie: String?
    }
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var state = State()
    }
    private static let storage = Storage()
    static func reset(status: Int = 200, empty: Bool = false, hold: Bool = false) {
        storage.lock.withLock { storage.state = State(status: status, empty: empty, hold: hold) }
    }
    static var requests: [URLRequest] { storage.lock.withLock { storage.state.requests } }
    static var heldCount: Int { storage.lock.withLock { storage.state.held.count } }
    static func release() {
        let held = storage.lock.withLock { let held = storage.state.held; storage.state.held = []; storage.state.hold = false; return held }
        for wire in held { wire.respond() }
    }
    static func releaseLast(status: Int = 200, cookie: String? = nil, empty: Bool = false) {
        let wire = storage.lock.withLock {
            storage.state.status = status
            storage.state.empty = empty
            storage.state.responseCookie = cookie
            return storage.state.held.popLast()
        }
        wire?.respond()
    }
    static func releaseFirst(status: Int = 200) {
        let wire = storage.lock.withLock {
            storage.state.status = status
            storage.state.empty = false
            return storage.state.held.isEmpty ? nil : storage.state.held.removeFirst()
        }
        wire?.respond()
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let hold = Self.storage.lock.withLock {
            Self.storage.state.requests.append(request)
            if Self.storage.state.hold { Self.storage.state.held.append(self); return true }
            return false
        }
        if !hold { respond() }
    }
    private func respond() {
        let (status, empty) = Self.storage.lock.withLock { (Self.storage.state.status, Self.storage.state.empty) }
        let who = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        let followed = who != nil
        let card = """
        {"id":"candidate","slug":"candidate","title":"Candidate","status":"GROUP_BUY","category_id":"KEYCAPS","is_following":false,"is_favorited":true,"is_in_collection":true,"hero_image_url":"https://example.invalid/card.png","follow_count":7,"favorite_count":3,"updated_at":"2026-09-15T12:00:00.000Z"}
        """
        let anchor = """
        {"id":"anchor","slug":"anchor","title":"Anchor","status":"GROUP_BUY","category_id":"KEYCAPS","is_following":\(followed),"is_favorited":false,"is_in_collection":false}
        """
        let body: String
        switch request.url?.path {
        case "/api/v1/discover/recommended": body = empty ? "{\"anchor_title\":null,\"data\":[]}" : "{\"anchor_title\":\"Old \(who ?? "anonymous")\",\"data\":[\(card)]}"
        case "/api/v1/profile": body = "{\"data\":{\"id\":\"\(who ?? "anonymous")\",\"username\":\"fixture\"}}"
        case "/api/auth/signout": body = "{}"
        default: body = empty ? "{\"data\":[],\"has_more\":false}" : "{\"data\":[\(anchor),\(card)],\"has_more\":false,\"page\":1,\"page_size\":20,\"total\":2}"
        }
        // Deliberately cacheable response: production request must still bypass it.
        var headers = ["Content-Type": "application/json", "Cache-Control": "public, max-age=3600"]
        headers["Set-Cookie"] = Self.storage.lock.withLock { Self.storage.state.responseCookie }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
@MainActor
struct DiscoveryContractTests {
    let api: APIClient
    init() {
        Wire.reset(); KeychainService.reset(); AuthService.shared.currentUser = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Wire.self]
        config.urlCache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        api = APIClient(session: URLSession(configuration: config))
    }
    func signIn(_ id: String?) {
        KeychainService.reset(token: id)
        AuthService.shared.currentUser = id.map { UserSummary(id: $0, username: $0, name: nil, avatarUrl: nil, image: nil, role: nil) }
    }
    func waitForHeld() async throws {
        for _ in 0..<200 {
            if Wire.heldCount > 0 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Request never reached URLProtocol")
    }
    @Test func exactSnakeCaseThroughRealClientAndViewModel() async throws {
        signIn("alice")
        let model = DiscoverViewModel(api: api)
        await model.loadPersonalizedLanes()
        #expect(model.recommendationLabel == "Because you follow Old alice")
        let card = try #require(model.recommendations.first)
        #expect(card.isFollowing == false); #expect(card.isFavorited == true); #expect(card.isInCollection == true)
        #expect(card.heroImageUrl == "https://example.invalid/card.png"); #expect(card.followCount == 7)
        let request = try #require(Wire.requests.last)
        #expect(request.url?.path == "/api/v1/discover/recommended"); #expect(request.url?.query == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer alice")
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
        #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store")
        #expect(request.httpShouldHandleCookies == false)
    }
    @Test func noFollowErrorAndSignoutClearExistingCards() async {
        signIn("alice"); let model = DiscoverViewModel(api: api)
        await model.loadPersonalizedLanes(); #expect(model.recommendations.count == 1)
        Wire.reset(empty: true); await model.loadPersonalizedLanes(); #expect(model.recommendations.isEmpty)
        #expect(model.recommendationLabel == "From projects you follow")
        Wire.reset(); await model.loadPersonalizedLanes(); #expect(model.recommendations.count == 1)
        Wire.reset(status: 401); await model.loadPersonalizedLanes(); #expect(model.recommendations.isEmpty)
        Wire.reset(); await model.loadPersonalizedLanes(); signIn(nil)
        #expect(model.recommendations.isEmpty) // immediate, before refresh/task runs
        Wire.reset(); await model.loadPersonalizedLanes(); #expect(Wire.requests.isEmpty)
    }
    @Test func accountChangeHidesBothRailsAndReloadRestoresThem() async {
        signIn("alice")
        let discover = DiscoverViewModel(api: api), list = ProjectListViewModel(api: api)
        await discover.loadPersonalizedLanes(); await list.refresh()
        #expect(discover.recommendations.count == 1); #expect(list.recommendedProjects.map(\.id) == ["candidate"])
        #expect(list.recommendationLabel == "Because you follow Anchor"); #expect(!list.trendingProjects.isEmpty)
        signIn("bob"); #expect(discover.recommendations.isEmpty); #expect(list.recommendedProjects.isEmpty)
        await discover.loadPersonalizedLanes(); await list.refresh()
        #expect(discover.recommendationLabel == "Because you follow Old bob"); #expect(list.recommendedProjects.count == 1)
        signIn(nil); #expect(discover.recommendations.isEmpty); #expect(list.recommendedProjects.isEmpty)
        await list.refresh(); #expect(list.projects.count == 2); #expect(list.recommendedProjects.isEmpty)
        #expect(Wire.requests.last?.value(forHTTPHeaderField: "Authorization") == nil)
    }
    @Test func staleInflightCannotRepopulateEitherRail() async throws {
        signIn("alice"); let discover = DiscoverViewModel(api: api), list = ProjectListViewModel(api: api)
        Wire.reset(hold: true)
        let first = Task { await discover.loadPersonalizedLanes() }
        try await waitForHeld(); signIn("bob"); Wire.release(); await first.value
        #expect(discover.recommendations.isEmpty)
        Wire.reset(hold: true); let second = Task { await list.refresh() }
        try await waitForHeld(); signIn(nil); Wire.release(); await second.value
        #expect(list.projects.isEmpty); #expect(list.recommendedProjects.isEmpty)
    }
    @Test func newRefreshWinsOverOlderInflightResponse() async throws {
        signIn("alice"); let model = DiscoverViewModel(api: api)
        Wire.reset(hold: true); let older = Task { await model.loadPersonalizedLanes() }
        try await waitForHeld()
        let newer = Task { await model.loadPersonalizedLanes() }
        for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
        Wire.releaseLast(); await newer.value
        #expect(model.recommendations.count == 1)
        Wire.releaseLast(status: 500); await older.value
        #expect(model.recommendations.count == 1)
    }
    @Test func realAPIClientRejectsCredentialTransitionAndDoesNotUseCache() async throws {
        signIn("alice")
        let _: RecommendedProjectsResponse = try await api.request(path: "/api/v1/discover/recommended", authenticated: true)
        signIn("bob")
        let bob: RecommendedProjectsResponse = try await api.request(path: "/api/v1/discover/recommended", authenticated: true)
        #expect(bob.anchorTitle == "Old bob"); #expect(Wire.requests.count == 2)
        Wire.reset(hold: true)
        let pending = Task { try await api.request(path: "/api/v1/discover/recommended", authenticated: true) as RecommendedProjectsResponse }
        try await waitForHeld(); KeychainService.reset(); Wire.release()
        do { _ = try await pending.value; Issue.record("Stale credential request accepted") }
        catch { #expect(error.localizedDescription == APIError.unauthorized.localizedDescription) }
    }
    @Test func listPagingSortAndFilterArePreserved() async throws {
        signIn("alice"); let model = ProjectListViewModel(api: api)
        await model.refresh(); #expect(model.hasMore == false)
        let count = Wire.requests.count; await model.loadMore(); #expect(Wire.requests.count == count)
        await model.updateSort(.oldest); await model.updateFilter(.groupBuy)
        let url = try #require(Wire.requests.last?.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(query.contains(URLQueryItem(name: "sort", value: "oldest")))
        #expect(query.contains(URLQueryItem(name: "status", value: "GROUP_BUY")))
        #expect(query.contains(URLQueryItem(name: "page", value: "1")))
        #expect(query.contains(URLQueryItem(name: "page_size", value: "20")))
    }
    @Test func productionAuthServiceAccountAndSignoutLifecycle() async throws {
        let auth = AuthService(api: api)
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        let list = ProjectListViewModel(api: api, currentUserID: { auth.currentUser?.id })
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        #expect(auth.currentUser?.id == "alice")
        await discover.loadPersonalizedLanes(); await list.refresh()
        #expect(discover.recommendations.count == 1); #expect(list.recommendedProjects.count == 1)
        try await auth.signInWithOAuth(result: OAuthResult(token: "bob", userId: "bob", username: "bob", role: "USER", avatar: nil))
        #expect(auth.currentUser?.id == "bob")
        #expect(discover.recommendations.isEmpty); #expect(list.recommendedProjects.isEmpty)
        await discover.loadPersonalizedLanes(); await list.refresh()
        #expect(discover.recommendationLabel == "Because you follow Old bob")
        await auth.signOut()
        #expect(auth.currentUser == nil); #expect(KeychainService.load(.authToken) == nil)
        #expect(discover.recommendations.isEmpty); #expect(list.recommendedProjects.isEmpty)
        await list.refresh()
        #expect(Wire.requests.last?.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
        #expect(list.recommendedProjects.isEmpty)
    }
    @Test func delayedAuthRestoreCannotUndoSignout() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice")
        Wire.reset(hold: true)
        let restore = Task { await auth.restoreSession() }
        try await waitForHeld()
        let logout = Task { await auth.signOut() }
        for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
        #expect(auth.currentUser == nil)
        Wire.release(); await restore.value; await logout.value
        #expect(auth.currentUser == nil); #expect(KeychainService.load(.authToken) == nil)
    }
    @Test func credentialReplacementHidesPreviousAccountBeforeProfileArrives() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let model = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        await model.loadPersonalizedLanes(); #expect(model.recommendations.count == 1)
        Wire.reset(hold: true)
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "bob", userId: "bob", username: "bob", role: "USER", avatar: nil)) }
        try await waitForHeld()
        #expect(auth.currentUser == nil); #expect(model.recommendations.isEmpty)
        Wire.release(); try await login.value
        #expect(auth.currentUser?.id == "bob"); #expect(model.recommendations.isEmpty)
    }
    @Test func oldSignoutCannotClearNewAccountCredentials() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        Wire.reset(hold: true)
        let logout = Task { await auth.signOut() }
        try await waitForHeld()
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "bob", userId: "bob", username: "bob", role: "USER", avatar: nil)) }
        for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
        Wire.releaseLast(); try await login.value
        #expect(auth.currentUser?.id == "bob")
        Wire.releaseLast(); await logout.value
        #expect(auth.currentUser?.id == "bob"); #expect(KeychainService.load(.authToken) == "bob")
    }
    @Test func decodesActualProductionRouteArtifact() throws {
        guard let path = ProcessInfo.processInfo.environment["DISCOVERY_CONTRACT_INPUT"] else { return }
        let body = try JSONDecoder().decode(RecommendedProjectsResponse.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        #expect(body.anchorTitle == "old anchor"); #expect(body.data.count == 10)
        #expect(body.data.first?.title == "new-1"); #expect(body.data.allSatisfy { $0.isFollowing == false && $0.isInCollection == false })
    }
}


// Independent QA repros; production source copies remain byte-identical.
extension DiscoveryContractTests {
    @Test func qaSameAccountReloginMustNotResurrectHiddenState() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        let list = ProjectListViewModel(api: api, currentUserID: { auth.currentUser?.id })
        await discover.loadPersonalizedLanes(); await list.refresh()
        #expect(discover.recommendations.count == 1); #expect(list.recommendedProjects.count == 1)
        await auth.signOut()
        #expect(discover.recommendations.isEmpty); #expect(list.projects.isEmpty)
        try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil))
        #expect(auth.currentUser?.id == "alice")
        #expect(discover.recommendations.isEmpty, "Old-session cards must stay invalid before refresh")
        #expect(list.projects.isEmpty, "Old-session list must stay invalid before refresh")
    }
    @Test func qaSameCredentialInflightAfterLogoutLoginMustBeRejected() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(hold: true)
        let old = Task { await discover.loadPersonalizedLanes() }
        try await waitForHeld()
        let logout = Task { await auth.signOut() }
        for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
        Wire.releaseLast(); await logout.value
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil)) }
        for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
        Wire.releaseLast(); try await login.value
        Wire.releaseLast(); await old.value
        #expect(discover.recommendations.isEmpty, "Pre-logout response accepted by post-login session")
    }
}


extension DiscoveryContractTests {
 @Test func qaRestoreStartedDuringPendingSignoutMustNotReauthenticate() async throws {
  let auth = AuthService(api: api)
  KeychainService.reset(token: "alice"); await auth.restoreSession()
  Wire.reset(hold: true)
  let logout = Task { await auth.signOut() }
  try await waitForHeld()
  #expect(auth.currentUser == nil)
  let restore = Task { await auth.restoreSession() }
  for _ in 0..<200 { if Wire.heldCount == 2 { break }; try await Task.sleep(for: .milliseconds(5)) }
  Wire.releaseLast(); await restore.value
  #expect(auth.currentUser == nil, "Restore used the credential being signed out and undid immediate hiding")
  Wire.releaseLast(); await logout.value
 }
}


extension DiscoveryContractTests {
    func waitForHeld(_ count: Int) async throws {
        for _ in 0..<200 {
            if Wire.heldCount == count { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Expected \(count) held requests; got \(Wire.heldCount)")
    }

    @Test(arguments: [200, 500])
    func sameCredentialOldClientResponseCannotWriteCookieOrSucceed(status: Int) async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        Wire.reset(hold: true)
        let old = Task { try await api.request(path: "/api/v1/discover/recommended", authenticated: true) as RecommendedProjectsResponse }
        try await waitForHeld(1)
        let logout = Task { await auth.signOut() }
        try await waitForHeld(2); Wire.releaseLast(); await logout.value
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil)) }
        try await waitForHeld(2); Wire.releaseLast(); try await login.value
        Wire.releaseLast(status: status, cookie: "old-session-cookie")
        do { _ = try await old.value; Issue.record("Prior lifetime response accepted") }
        catch { #expect(error.localizedDescription == APIError.unauthorized.localizedDescription) }
        #expect(KeychainService.load(.sessionCookie) == nil)
        #expect(auth.currentUser?.id == "alice")
    }

    @Test(arguments: [200, 500])
    func bothRailsKeepNewLifetimeResultsAfterOldSuccessOrError(status: Int) async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        let list = ProjectListViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(hold: true)
        let oldDiscover = Task { await discover.loadPersonalizedLanes() }
        try await waitForHeld(1)
        let oldList = Task { await list.refresh() }
        try await waitForHeld(2)
        let logout = Task { await auth.signOut() }
        try await waitForHeld(3); Wire.releaseLast(); await logout.value
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil)) }
        try await waitForHeld(3); Wire.releaseLast(); try await login.value
        let newDiscover = Task { await discover.loadPersonalizedLanes() }
        try await waitForHeld(3); Wire.releaseLast(); await newDiscover.value
        // No explicit refresh: a changed lifetime must reset list paging itself.
        let newList = Task { await list.loadProjects() }
        try await waitForHeld(3); Wire.releaseLast(); await newList.value
        Wire.releaseLast(status: status); await oldList.value
        Wire.releaseLast(status: status); await oldDiscover.value
        #expect(discover.recommendations.count == 1)
        #expect(discover.recommendationLabel == "Because you follow Old alice")
        #expect(list.projects.count == 2); #expect(list.recommendedProjects.count == 1)
        #expect(!list.trendingProjects.isEmpty); #expect(list.error == nil)
    }

    @Test func visibleLabelsErrorsAndPublicTrendingUseCorrectOwnership() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        let list = ProjectListViewModel(api: api, currentUserID: { auth.currentUser?.id })
        await discover.loadAll(); await list.refresh()
        Wire.reset(status: 500); await list.refresh(); #expect(list.error != nil)
        Wire.reset(); await auth.signOut()
        try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil))
        // No view task/load runs between transitions and these visible getters.
        #expect(discover.recommendations.isEmpty)
        #expect(discover.recommendationLabel == "From projects you follow")
        #expect(list.projects.isEmpty); #expect(list.error == nil)
        #expect(list.recommendationLabel == "From projects you follow")
        #expect(!discover.trendingThisWeek.isEmpty)
        await auth.signOut(); await list.loadProjects()
        #expect(list.projects.count == 2); #expect(!list.trendingProjects.isEmpty)
        #expect(list.recommendedProjects.isEmpty)
    }
}


extension DiscoveryContractTests {
    @Test(arguments: [200, 500])
    func oldListCompletionCannotPopulateOrExposeErrorWithoutNewViewTask(status: Int) async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let list = ProjectListViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(hold: true)
        let old = Task { await list.refresh() }
        try await waitForHeld(1)
        let logout = Task { await auth.signOut() }
        try await waitForHeld(2); Wire.releaseLast(); await logout.value
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil)) }
        try await waitForHeld(2); Wire.releaseLast(); try await login.value
        Wire.releaseLast(status: status); await old.value
        #expect(list.projects.isEmpty); #expect(list.recommendedProjects.isEmpty)
        #expect(list.error == nil)
    }
}

extension DiscoveryContractTests {
    @Test(arguments: [200, 500])
    func qaOldFullDiscoverLoadCannotExposeErrorAfterSameAccountRelogin(status: Int) async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(hold: true)
        let old = Task { await discover.loadAll() }
        try await waitForHeld(6)
        let logout = Task { await auth.signOut() }
        try await waitForHeld(7); Wire.releaseLast(); await logout.value
        let login = Task { try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil)) }
        try await waitForHeld(7); Wire.releaseLast(); try await login.value
        #expect(auth.currentUser?.id == "alice")
        // No new view reload: all six responses belong to the previous lifetime.
        for _ in 0..<6 { Wire.releaseLast(status: status, cookie: "old-lifetime-cookie") }
        await old.value
        #expect(KeychainService.load(.sessionCookie) == nil)
        #expect(discover.recommendations.isEmpty)
        #expect(discover.groupBuys.isEmpty)
        #expect(discover.error == nil, "Old public requests must not install an auth error in the new lifetime; DiscoverView displays this when groupBuys is empty")
    }
    @Test func qaAlreadyVisibleDiscoverErrorMustNotSurviveSameAccountRelogin() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(status: 500); await discover.loadAll()
        #expect(discover.error != nil)
        Wire.reset(); await auth.signOut()
        try await auth.signInWithOAuth(result: OAuthResult(token: "alice", userId: "alice", username: "alice", role: "USER", avatar: nil))
        #expect(discover.error == nil, "Visible errors still belong to the prior authentication lifetime before a new view task runs")
    }
}

extension DiscoveryContractTests {
    @Test(arguments: [false, true])
    func currentDiscoverErrorsAndPublicRecoveryRemainVisible(authenticated: Bool) async throws {
        signIn(authenticated ? "alice" : nil)
        let discover = DiscoverViewModel(api: api)
        Wire.reset(status: 500)
        await discover.loadAll()
        #expect(discover.error == "HTTP 500")
        #expect(!discover.isLoading)
        #expect(Wire.requests.count == (authenticated ? 6 : 5))
        #expect(Wire.requests.filter { $0.url?.path != "/api/v1/discover/recommended" }.allSatisfy {
            $0.value(forHTTPHeaderField: "Authorization") == nil && $0.value(forHTTPHeaderField: "Cookie") == nil
        })
        Wire.reset()
        await discover.loadAll()
        #expect(discover.error == nil)
        #expect(!discover.isLoading)
        #expect(discover.interestChecks.count == 2); #expect(discover.groupBuys.count == 2)
        #expect(discover.endingSoon.count == 2); #expect(discover.newThisWeek.count == 2)
        #expect(discover.trendingThisWeek.count == 2)
        #expect(discover.recommendations.count == (authenticated ? 1 : 0))
    }

    @Test(arguments: [200, 500], [false, true])
    func fullDiscoverLoadsKeepNewerErrorsResultsAndLoading(oldStatus: Int, olderFinishesFirst: Bool) async throws {
        signIn("alice")
        let discover = DiscoverViewModel(api: api)
        Wire.reset(hold: true)
        let older = Task { await discover.loadAll() }
        try await waitForHeld(6)
        #expect(discover.isLoading)
        let newer = Task { await discover.loadAll() }
        try await waitForHeld(12)
        // Opposite statuses prove both old-success/new-error and old-error/new-success.
        let newStatus = oldStatus == 200 ? 500 : 200
        if olderFinishesFirst {
            for _ in 0..<6 { Wire.releaseFirst(status: oldStatus) }
            await older.value
            // Older defer must not end the still-pending newer load.
            #expect(discover.isLoading); #expect(discover.error == nil)
            #expect(discover.interestChecks.isEmpty); #expect(discover.groupBuys.isEmpty)
            #expect(discover.endingSoon.isEmpty); #expect(discover.newThisWeek.isEmpty)
            #expect(discover.trendingThisWeek.isEmpty); #expect(discover.recommendations.isEmpty)
        }
        for _ in 0..<6 { Wire.releaseLast(status: newStatus, empty: true) }
        await newer.value
        #expect(!discover.isLoading)
        #expect(discover.error == (newStatus == 500 ? "HTTP 500" : nil))
        if !olderFinishesFirst {
            for _ in 0..<6 { Wire.releaseFirst(status: oldStatus) }
            await older.value
        }
        #expect(!discover.isLoading)
        #expect(discover.error == (newStatus == 500 ? "HTTP 500" : nil))
        #expect(discover.interestChecks.isEmpty); #expect(discover.groupBuys.isEmpty)
        #expect(discover.endingSoon.isEmpty); #expect(discover.newThisWeek.isEmpty)
        #expect(discover.trendingThisWeek.isEmpty); #expect(discover.recommendations.isEmpty)
    }

    @Test func fullDiscoverLoadingIsHiddenImmediatelyAcrossLifetime() async throws {
        let auth = AuthService(api: api)
        KeychainService.reset(token: "alice"); await auth.restoreSession()
        let discover = DiscoverViewModel(api: api, currentUserID: { auth.currentUser?.id })
        Wire.reset(hold: true)
        let older = Task { await discover.loadAll() }
        try await waitForHeld(6); #expect(discover.isLoading)
        let logout = Task { await auth.signOut() }
        try await waitForHeld(7)
        #expect(!discover.isLoading); #expect(discover.error == nil)
        Wire.releaseLast(); await logout.value
        let newer = Task { await discover.loadAll() }
        try await waitForHeld(11) // five anonymous public requests, six old requests
        for _ in 0..<6 { Wire.releaseFirst(status: 500) }
        await older.value
        #expect(discover.isLoading); #expect(discover.error == nil)
        for _ in 0..<5 { Wire.releaseLast() }
        await newer.value
        #expect(!discover.isLoading); #expect(discover.error == nil)
        #expect(!discover.trendingThisWeek.isEmpty); #expect(discover.recommendations.isEmpty)
    }
}
