import Foundation

/// Central API client for all KeyAtlas REST calls
actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://keyatlas.io")!
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
        ]
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Auth token management

    private var authToken: String? {
        KeychainService.load(.authToken)
    }

    // MARK: - Generic request

    func request<T: Codable & Sendable>(
        _ method: HTTPMethod = .get,
        path: String,
        query: [String: String]? = nil,
        body: (any Encodable & Sendable)? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        var url = baseURL.appendingPathComponent(path)

        if let query, !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = components.url!
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if authenticated, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Also send session cookie if available
        if authenticated, let cookie = KeychainService.load(.sessionCookie) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Store set-cookie header for session-based auth
        if let setCookie = httpResponse.value(forHTTPHeaderField: "Set-Cookie") {
            try? KeychainService.save(setCookie, for: .sessionCookie)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 422:
            if let errorResponse = try? decoder.decode(ValidationError.self, from: data) {
                throw APIError.validation(errorResponse.message)
            }
            throw APIError.validation("Invalid request")
        case 429:
            throw APIError.rateLimited
        default:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.server(errorResponse.message ?? "Server error")
            }
            throw APIError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    /// Fire-and-forget POST/PUT/DELETE that returns no meaningful body
    func requestVoid(
        _ method: HTTPMethod = .post,
        path: String,
        body: (any Encodable & Sendable)? = nil,
        authenticated: Bool = true
    ) async throws {
        let _: EmptyResponse = try await request(method, path: path, body: body, authenticated: authenticated)
    }

    // MARK: - Multipart upload

    func upload(
        path: String,
        imageData: Data,
        filename: String,
        mimeType: String = "image/jpeg",
        additionalFields: [String: String] = [:]
    ) async throws -> UploadResponse {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let cookie = KeychainService.load(.sessionCookie) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // Additional fields
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        // File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.uploadFailed
        }
        return try decoder.decode(UploadResponse.self, from: data)
    }
}

// MARK: - Types

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIError: Error, LocalizedError, Sendable {
    case invalidResponse
    case unauthorized
    case notFound
    case validation(String)
    case rateLimited
    case server(String)
    case uploadFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid server response"
        case .unauthorized: "Please sign in to continue"
        case .notFound: "Not found"
        case .validation(let msg): msg
        case .rateLimited: "Too many requests. Please wait."
        case .server(let msg): msg
        case .uploadFailed: "Upload failed"
        case .decodingFailed: "Failed to parse response"
        }
    }
}

struct ErrorResponse: Codable, Hashable, Sendable {
    let message: String?
    let error: String?
}

struct ValidationError: Codable, Hashable, Sendable {
    let message: String
    let errors: [String: [String]]?
}

struct EmptyResponse: Codable, Hashable, Sendable {}

struct UploadResponse: Codable, Hashable, Sendable {
    let url: String?
    let id: String?
}

struct APIDataResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T
}
