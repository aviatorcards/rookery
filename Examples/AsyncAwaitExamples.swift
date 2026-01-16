// AsyncAwaitExamples.swift
// Swift Concurrency Patterns - Modern async/await examples

import Foundation

// MARK: - Basic Async Function

/// Simple async function that fetches data
func fetchUserData(id: Int) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// MARK: - Structured Concurrency with TaskGroup

/// Fetch multiple resources concurrently using TaskGroup
func fetchAllUsers(ids: [Int]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await fetchUserData(id: id)
            }
        }

        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}

// MARK: - Actor for Thread-Safe State

/// Thread-safe cache using Swift actors
actor UserCache {
    private var cache: [Int: User] = [:]

    func user(for id: Int) -> User? {
        cache[id]
    }

    func store(_ user: User, for id: Int) {
        cache[id] = user
    }

    func clear() {
        cache.removeAll()
    }

    var count: Int {
        cache.count
    }
}

// MARK: - AsyncSequence Example

/// Custom AsyncSequence for paginated API results
struct PaginatedResults<T: Decodable>: AsyncSequence {
    typealias Element = [T]

    let baseURL: URL
    let pageSize: Int

    struct AsyncIterator: AsyncIteratorProtocol {
        let baseURL: URL
        let pageSize: Int
        var currentPage = 0
        var hasMorePages = true

        mutating func next() async throws -> [T]? {
            guard hasMorePages else { return nil }

            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(currentPage)"),
                URLQueryItem(name: "limit", value: "\(pageSize)")
            ]

            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let page = try JSONDecoder().decode(PageResponse<T>.self, from: data)

            currentPage += 1
            hasMorePages = page.hasMore

            return page.items.isEmpty ? nil : page.items
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(baseURL: baseURL, pageSize: pageSize)
    }
}

// MARK: - Continuation for Callback-based APIs

/// Wrap callback-based API in async/await
func loadImage(from url: URL) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else if let data = data {
                continuation.resume(returning: data)
            } else {
                continuation.resume(throwing: URLError(.unknown))
            }
        }
        task.resume()
    }
}

// MARK: - Task Cancellation

/// Demonstrate proper task cancellation handling
func fetchWithTimeout<T>(
    timeout: Duration,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: timeout)
            throw CancellationError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - AsyncStream for Event Sources

/// Create an AsyncStream for real-time events
func eventStream() -> AsyncStream<Event> {
    AsyncStream { continuation in
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            continuation.yield(Event(timestamp: Date(), type: .heartbeat))
        }

        continuation.onTermination = { _ in
            timer.invalidate()
        }
    }
}

// MARK: - MainActor for UI Updates

@MainActor
class ViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            users = try await fetchAllUsers(ids: [1, 2, 3, 4, 5])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Supporting Types

struct User: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
}

struct PageResponse<T: Decodable>: Decodable {
    let items: [T]
    let hasMore: Bool
}

struct Event {
    let timestamp: Date
    let type: EventType

    enum EventType {
        case heartbeat
        case message(String)
        case disconnect
    }
}
