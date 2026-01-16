// NetworkingExamples.swift
// Modern Swift Networking Patterns with URLSession

import Foundation

// MARK: - API Client Protocol

/// Protocol for type-safe API clients
protocol APIClient {
    var baseURL: URL { get }
    var session: URLSession { get }

    func send<T: Decodable>(_ request: APIRequest<T>) async throws -> T
}

/// Generic API request definition
struct APIRequest<Response: Decodable> {
    let method: HTTPMethod
    let path: String
    var queryItems: [URLQueryItem]?
    var body: Encodable?
    var headers: [String: String]?

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }
}

// MARK: - Concrete API Client Implementation

/// Production-ready API client with error handling
final class HTTPClient: APIClient {
    let baseURL: URL
    let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder

        // Configure date decoding strategy
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func send<T: Decodable>(_ request: APIRequest<T>) async throws -> T {
        let urlRequest = try buildRequest(request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func buildRequest<T>(_ request: APIRequest<T>) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)!
        components.queryItems = request.queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        // Set default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add custom headers
        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Encode body if present
        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return urlRequest
    }
}

// MARK: - Type-Safe Endpoints

/// Define endpoints as static properties for type safety
enum Endpoints {
    static func users() -> APIRequest<[User]> {
        APIRequest(method: .get, path: "/users")
    }

    static func user(id: Int) -> APIRequest<User> {
        APIRequest(method: .get, path: "/users/\(id)")
    }

    static func createUser(_ user: CreateUserRequest) -> APIRequest<User> {
        APIRequest(method: .post, path: "/users", body: user)
    }

    static func updateUser(id: Int, _ user: UpdateUserRequest) -> APIRequest<User> {
        APIRequest(method: .put, path: "/users/\(id)", body: user)
    }

    static func deleteUser(id: Int) -> APIRequest<EmptyResponse> {
        APIRequest(method: .delete, path: "/users/\(id)")
    }

    static func searchUsers(query: String, page: Int = 1) -> APIRequest<PaginatedResponse<User>> {
        APIRequest(
            method: .get,
            path: "/users/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: "\(page)")
            ]
        )
    }
}

// MARK: - Request/Response Models

struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

struct UpdateUserRequest: Encodable {
    let name: String?
    let email: String?
}

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let createdAt: Date?
}

struct EmptyResponse: Decodable {}

struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let page: Int
    let totalPages: Int
    let totalCount: Int
}

// MARK: - API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, _):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Type Erasure Helper

struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

// MARK: - URLSession Extensions

extension URLSession {
    /// Download with progress reporting
    func downloadWithProgress(
        from url: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        let (asyncBytes, response) = try await bytes(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let contentLength = response.expectedContentLength
        var receivedLength: Int64 = 0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)

        for try await byte in asyncBytes {
            try fileHandle.write(contentsOf: [byte])
            receivedLength += 1

            if contentLength > 0 {
                let progress = Double(receivedLength) / Double(contentLength)
                progressHandler(progress)
            }
        }

        try fileHandle.close()
        return tempURL
    }
}

// MARK: - Multipart Form Data Upload

struct MultipartFormData {
    private var boundary: String
    private var data = Data()

    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func append(_ value: String, forKey key: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func append(_ fileData: Data, forKey key: String, filename: String, mimeType: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }

    func finalize() -> Data {
        var finalData = data
        finalData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalData
    }
}

/// Upload file with multipart form data
func uploadFile(
    to url: URL,
    fileData: Data,
    filename: String,
    mimeType: String
) async throws -> Data {
    var formData = MultipartFormData()
    formData.append(fileData, forKey: "file", filename: filename, mimeType: mimeType)

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = formData.finalize()

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw APIError.invalidResponse
    }

    return data
}

// MARK: - WebSocket Example

/// Simple WebSocket client
actor WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func connect() {
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        startReceiving()
    }

    func send(_ message: String) async throws {
        try await webSocketTask?.send(.string(message))
    }

    func send(_ data: Data) async throws {
        try await webSocketTask?.send(.data(data))
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            Task { [weak self] in
                switch result {
                case .success(let message):
                    await self?.handleMessage(message)
                    self?.startReceiving()
                case .failure(let error):
                    print("WebSocket error: \(error)")
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("Received text: \(text)")
        case .data(let data):
            print("Received data: \(data.count) bytes")
        @unknown default:
            break
        }
    }
}

// MARK: - Usage Example

func exampleUsage() async {
    let client = HTTPClient(baseURL: URL(string: "https://api.example.com")!)

    do {
        // Fetch all users
        let users = try await client.send(Endpoints.users())
        print("Found \(users.count) users")

        // Create a new user
        let newUser = try await client.send(
            Endpoints.createUser(CreateUserRequest(name: "John", email: "john@example.com"))
        )
        print("Created user: \(newUser.name)")

        // Search users
        let searchResults = try await client.send(Endpoints.searchUsers(query: "john"))
        print("Search found \(searchResults.totalCount) results")

    } catch let error as APIError {
        print("API Error: \(error.errorDescription ?? "Unknown")")
    } catch {
        print("Error: \(error)")
    }
}
