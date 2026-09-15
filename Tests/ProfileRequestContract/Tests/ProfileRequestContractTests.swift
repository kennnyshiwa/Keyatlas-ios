import Foundation
import Testing
@testable import ProfileContract

private let username = "profile-contract-fixture"
private let profilePath = "/api/v1/users/profile-contract-fixture"
private let fakeToken = "isolated-test-token-not-a-real-credential"
private let fakeCookie = "profile_contract=isolated-test-cookie"

enum Credentials: CaseIterable, Sendable {
    case anonymous, bearer, cookie, both
    var token: String? { self == .bearer || self == .both ? fakeToken : nil }
    var cookie: String? { self == .cookie || self == .both ? fakeCookie : nil }
}

// Catch ALL requests, including unexpected hosts/paths: never forward to a network.
private final class Wire: URLProtocol, @unchecked Sendable {
    struct State {
        var requests: [URLRequest] = []
        var following = false
        var failure: Int?
        var setCookie = false
    }
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var state = State()
    }
    private static let storage = Storage()
    static func reset(following: Bool = false, failure: Int? = nil, setCookie: Bool = false) {
        storage.lock.withLock {
            storage.state = State(following: following, failure: failure, setCookie: setCookie)
        }
    }
    static var requests: [URLRequest] { storage.lock.withLock { storage.state.requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body, cookie): (Int, String, Bool) = Self.storage.lock.withLock {
            Self.storage.state.requests.append(request)
            let authorized = request.value(forHTTPHeaderField: "Authorization") == "Bearer \(fakeToken)"
                || request.value(forHTTPHeaderField: "Cookie") == fakeCookie
            guard request.url?.host == "keyatlas.io" else { return (599, "{}", false) }
            if let failure = Self.storage.state.failure { return (failure, "{}", false) }
            if request.url?.path == profilePath + "/follow" {
                guard authorized else { return (401, "{}", false) }
                switch request.httpMethod {
                case "POST": Self.storage.state.following = true
                case "DELETE": Self.storage.state.following = false
                default: return (405, "{}", false)
                }
                return (200, "{}", false)
            }
            guard request.httpMethod == "GET" else { return (405, "{}", false) }
            let following = authorized && Self.storage.state.following
            let publicBody = """
            {"id":"fixture-user","username":"profile-contract-fixture","avatar_url":"https://example.invalid/avatar.png","follower_count":\(Self.storage.state.following ? 8 : 7),"following_count":2,"is_following":\(following),"projects":[]}
            """
            if request.url?.path == "/api/v1/profile", authorized {
                return (200, "{\"data\":\(publicBody)}", false)
            }
            guard request.url?.path == profilePath else { return (404, "{}", false) }
            return (200, publicBody, Self.storage.state.setCookie)
        }
        var headers = ["Content-Type": "application/json", "Cache-Control": "no-store"]
        if cookie { headers["Set-Cookie"] = fakeCookie }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized)
struct ProfileRequestContractTests {
    private let api: APIClient
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Wire.self]
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        api = APIClient(session: URLSession(configuration: config))
        Wire.reset()
        KeychainService.reset()
    }

    private func setup(_ credentials: Credentials, following: Bool = false) {
        KeychainService.reset(token: credentials.token, cookie: credentials.cookie)
        Wire.reset(following: following)
    }

    private func check(_ request: URLRequest, method: String, path: String, credentials: Credentials) {
        #expect(request.httpMethod == method)
        #expect(request.url?.scheme == "https")
        #expect(request.url?.host == "keyatlas.io")
        #expect(request.url?.path == path)
        #expect(request.url?.query == nil)
        #expect(request.url?.user == nil)
        #expect(request.url?.password == nil)
        #expect(request.httpBody == nil)
        #expect(request.httpBodyStream == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == credentials.token.map { "Bearer \($0)" })
        #expect(request.value(forHTTPHeaderField: "Cookie") == credentials.cookie)
    }

    @Test(arguments: Credentials.allCases)
    func initialAndPublicRefreshUseOptionalCredentials(_ credentials: Credentials) async throws {
        setup(credentials, following: true)
        let model = ProfileViewModel(api: api)
        await model.loadProfile(username: username)
        #expect(model.error == nil)
        #expect(model.profile?.isFollowing == (credentials != .anonymous))
        #expect(model.profile?.email == nil)
        #expect(model.profile?.effectiveAvatarUrl == "https://example.invalid/avatar.png")
        #expect(model.profile?.projects?.isEmpty == true)
        await model.loadProfile(username: username)
        #expect(model.error == nil)
        #expect(model.profile?.isFollowing == (credentials != .anonymous))
        #expect(Wire.requests.count == 2)
        for request in Wire.requests { check(request, method: "GET", path: profilePath, credentials: credentials) }
    }

    @Test(arguments: [Credentials.bearer, .cookie, .both])
    func followThenUnfollowRefreshServerState(_ credentials: Credentials) async throws {
        setup(credentials)
        let model = ProfileViewModel(api: api)
        await model.loadProfile(username: username)
        #expect(model.profile?.isFollowing == false)
        await model.toggleFollow(username: username, isFollowing: false)
        #expect(model.error == nil)
        #expect(model.profile?.isFollowing == true)
        #expect(model.profile?.followerCount == 8)
        await model.toggleFollow(username: username, isFollowing: true)
        #expect(model.error == nil)
        #expect(model.profile?.isFollowing == false)
        #expect(model.profile?.followerCount == 7)
        let requests = Wire.requests
        #expect(requests.count == 5)
        let expected = [("GET", profilePath), ("POST", profilePath + "/follow"), ("GET", profilePath),
                        ("DELETE", profilePath + "/follow"), ("GET", profilePath)]
        for (request, pair) in zip(requests, expected) {
            check(request, method: pair.0, path: pair.1, credentials: credentials)
        }
    }

    @Test func refreshAfterLogoutDoesNotReuseViewerCredentials() async throws {
        setup(.both, following: true)
        let model = ProfileViewModel(api: api)
        await model.loadProfile(username: username)
        #expect(model.profile?.isFollowing == true)
        KeychainService.reset()
        await model.loadProfile(username: username)
        #expect(model.error == nil)
        #expect(model.profile?.isFollowing == false)
        check(try #require(Wire.requests.last), method: "GET", path: profilePath, credentials: .anonymous)
    }

    @Test func apiDefaultRemainsCredentialFree() async throws {
        setup(.both, following: true)
        let profile: UserProfile = try await api.request(path: profilePath)
        #expect(profile.isFollowing == false)
        #expect(KeychainService.readCount == 0)
        check(try #require(Wire.requests.first), method: "GET", path: profilePath, credentials: .anonymous)
    }

    @Test func authenticatedFlagDoesNotRequireLogin() async throws {
        setup(.anonymous)
        let profile: UserProfile = try await api.request(path: profilePath, authenticated: true)
        #expect(profile.id == "fixture-user")
        check(try #require(Wire.requests.first), method: "GET", path: profilePath, credentials: .anonymous)
    }

    @Test func failedMutationDoesNotRefreshOrFabricateFollowing() async throws {
        setup(.bearer)
        let model = ProfileViewModel(api: api)
        await model.loadProfile(username: username)
        Wire.reset(failure: 401)
        await model.toggleFollow(username: username, isFollowing: false)
        #expect(model.error == APIError.unauthorized.localizedDescription)
        #expect(model.profile?.isFollowing == false)
        #expect(Wire.requests.count == 1)
        check(try #require(Wire.requests.first), method: "POST", path: profilePath + "/follow", credentials: .bearer)
    }

    @Test func missingProfileKeepsExistingErrorContract() async {
        Wire.reset(failure: 404)
        let model = ProfileViewModel(api: api)
        await model.loadProfile(username: username)
        #expect(model.profile == nil)
        #expect(model.error == APIError.notFound.localizedDescription)
    }

    @Test func currentProfileRetainsAuthenticatedWrappedContract() async throws {
        setup(.both)
        let model = ProfileViewModel(api: api)
        await model.loadCurrentProfile()
        #expect(model.error == nil)
        #expect(model.profile?.id == "fixture-user")
        check(try #require(Wire.requests.first), method: "GET", path: "/api/v1/profile", credentials: .both)
    }

    @Test func responseCookieWritesOnlyToMemoryDouble() async throws {
        setup(.anonymous)
        Wire.reset(setCookie: true)
        let _: UserProfile = try await api.request(path: profilePath, authenticated: true)
        #expect(KeychainService.load(.sessionCookie) == fakeCookie)
    }
}
