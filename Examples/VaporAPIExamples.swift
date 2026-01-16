// VaporAPIExamples.swift
// Examples for interacting with the Rookery Vapor API

import Foundation

// MARK: - Rookery API Client

/// Client for interacting with the Rookery snippet API
final class RookeryClient {
    let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        // Configure ISO8601 date handling
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Snippet CRUD Operations

    /// List all snippets
    func listSnippets() async throws -> [SnippetDTO] {
        let url = baseURL.appendingPathComponent("/api/snippets")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([SnippetDTO].self, from: data)
    }

    /// Get a single snippet by ID
    func getSnippet(id: UUID) async throws -> SnippetDTO {
        let url = baseURL.appendingPathComponent("/api/snippets/\(id.uuidString)")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SnippetDTO.self, from: data)
    }

    /// Create a new snippet
    func createSnippet(_ snippet: CreateSnippetRequest) async throws -> SnippetDTO {
        let url = baseURL.appendingPathComponent("/api/snippets")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(snippet)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw RookeryError.createFailed
        }

        return try decoder.decode(SnippetDTO.self, from: data)
    }

    /// Update an existing snippet
    func updateSnippet(id: UUID, _ update: UpdateSnippetRequest) async throws -> SnippetDTO {
        let url = baseURL.appendingPathComponent("/api/snippets/\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(update)

        let (data, _) = try await session.data(for: request)
        return try decoder.decode(SnippetDTO.self, from: data)
    }

    /// Delete a snippet
    func deleteSnippet(id: UUID) async throws {
        let url = baseURL.appendingPathComponent("/api/snippets/\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw RookeryError.deleteFailed
        }
    }

    // MARK: - Image Generation

    /// Generate an image for a snippet using freeze
    func generateImage(
        for snippetId: UUID,
        theme: String = "dracula",
        language: String = "swift"
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/snippets/\(snippetId.uuidString)/image"),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "theme", value: theme),
            URLQueryItem(name: "language", value: language)
        ]

        let (data, response) = try await session.data(from: components.url!)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RookeryError.imageGenerationFailed
        }

        return data
    }

    // MARK: - Favorites

    /// Toggle favorite status for a snippet
    func toggleFavorite(id: UUID) async throws -> SnippetDTO {
        let url = baseURL.appendingPathComponent("/api/snippets/\(id.uuidString)/favorite")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, _) = try await session.data(for: request)
        return try decoder.decode(SnippetDTO.self, from: data)
    }

    /// Get all favorite snippets
    func listFavorites() async throws -> [SnippetDTO] {
        let url = baseURL.appendingPathComponent("/api/snippets/favorites")
        let (data, _) = try await session.data(from: url)
        return try decoder.decode([SnippetDTO].self, from: data)
    }

    // MARK: - Search

    /// Search snippets by title or code content
    func search(query: String) async throws -> [SnippetDTO] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/snippets/search"),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        let (data, _) = try await session.data(from: components.url!)
        return try decoder.decode([SnippetDTO].self, from: data)
    }
}

// MARK: - Request/Response Models

struct SnippetDTO: Codable, Identifiable {
    let id: UUID
    let title: String
    let code: String
    let language: String
    let tags: [String]
    let isFavorite: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct CreateSnippetRequest: Codable {
    let title: String
    let code: String
    let language: String
    let tags: [String]

    init(title: String, code: String, language: String = "swift", tags: [String] = []) {
        self.title = title
        self.code = code
        self.language = language
        self.tags = tags
    }
}

struct UpdateSnippetRequest: Codable {
    let title: String?
    let code: String?
    let language: String?
    let tags: [String]?
}

// MARK: - Errors

enum RookeryError: Error, LocalizedError {
    case createFailed
    case updateFailed
    case deleteFailed
    case notFound
    case imageGenerationFailed

    var errorDescription: String? {
        switch self {
        case .createFailed:
            return "Failed to create snippet"
        case .updateFailed:
            return "Failed to update snippet"
        case .deleteFailed:
            return "Failed to delete snippet"
        case .notFound:
            return "Snippet not found"
        case .imageGenerationFailed:
            return "Failed to generate image"
        }
    }
}

// MARK: - Usage Examples

/// Demonstrates basic CRUD operations with the Rookery API
func basicCRUDExample() async {
    let client = RookeryClient()

    do {
        // Create a new snippet
        let newSnippet = try await client.createSnippet(CreateSnippetRequest(
            title: "Hello World",
            code: """
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }

            print(greet(name: "World"))
            """,
            language: "swift",
            tags: ["example", "beginner"]
        ))
        print("Created snippet: \(newSnippet.id)")

        // Read it back
        let fetched = try await client.getSnippet(id: newSnippet.id)
        print("Fetched: \(fetched.title)")

        // Update the snippet
        let updated = try await client.updateSnippet(
            id: newSnippet.id,
            UpdateSnippetRequest(
                title: "Hello World (Updated)",
                code: nil,
                language: nil,
                tags: ["example", "beginner", "updated"]
            )
        )
        print("Updated title: \(updated.title)")

        // List all snippets
        let allSnippets = try await client.listSnippets()
        print("Total snippets: \(allSnippets.count)")

        // Delete the snippet
        try await client.deleteSnippet(id: newSnippet.id)
        print("Deleted snippet")

    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

/// Demonstrates search and favorites functionality
func searchAndFavoritesExample() async {
    let client = RookeryClient()

    do {
        // Create some test snippets
        let snippets = [
            CreateSnippetRequest(title: "Quick Sort", code: "func quickSort...", tags: ["algorithm", "sorting"]),
            CreateSnippetRequest(title: "Merge Sort", code: "func mergeSort...", tags: ["algorithm", "sorting"]),
            CreateSnippetRequest(title: "Binary Search", code: "func binarySearch...", tags: ["algorithm", "search"])
        ]

        var createdIds: [UUID] = []
        for snippet in snippets {
            let created = try await client.createSnippet(snippet)
            createdIds.append(created.id)
        }

        // Search for sorting algorithms
        let sortingSnippets = try await client.search(query: "sort")
        print("Found \(sortingSnippets.count) sorting snippets")

        // Mark first one as favorite
        if let first = createdIds.first {
            let favorited = try await client.toggleFavorite(id: first)
            print("Marked as favorite: \(favorited.isFavorite)")
        }

        // List all favorites
        let favorites = try await client.listFavorites()
        print("Total favorites: \(favorites.count)")

        // Cleanup
        for id in createdIds {
            try await client.deleteSnippet(id: id)
        }

    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

/// Demonstrates image generation
func imageGenerationExample() async {
    let client = RookeryClient()

    do {
        // Create a snippet
        let snippet = try await client.createSnippet(CreateSnippetRequest(
            title: "Fibonacci",
            code: """
            func fibonacci(_ n: Int) -> Int {
                guard n > 1 else { return n }
                return fibonacci(n - 1) + fibonacci(n - 2)
            }
            """,
            language: "swift"
        ))

        // Generate an image with different themes
        let themes = ["dracula", "monokai", "github"]

        for theme in themes {
            let imageData = try await client.generateImage(
                for: snippet.id,
                theme: theme,
                language: "swift"
            )
            print("Generated \(theme) image: \(imageData.count) bytes")

            // Save to disk
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("snippet_\(theme).png")
            try imageData.write(to: url)
            print("Saved to: \(url.path)")
        }

        // Cleanup
        try await client.deleteSnippet(id: snippet.id)

    } catch {
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - curl Command Examples

/*
 # List all snippets
 curl http://localhost:8080/api/snippets

 # Get a specific snippet
 curl http://localhost:8080/api/snippets/{id}

 # Create a snippet
 curl -X POST http://localhost:8080/api/snippets \
   -H "Content-Type: application/json" \
   -d '{
     "title": "Hello World",
     "code": "print(\"Hello, World!\")",
     "language": "swift",
     "tags": ["example"]
   }'

 # Update a snippet
 curl -X PUT http://localhost:8080/api/snippets/{id} \
   -H "Content-Type: application/json" \
   -d '{
     "title": "Updated Title"
   }'

 # Delete a snippet
 curl -X DELETE http://localhost:8080/api/snippets/{id}

 # Toggle favorite
 curl -X POST http://localhost:8080/api/snippets/{id}/favorite

 # Search snippets
 curl "http://localhost:8080/api/snippets/search?q=hello"

 # Generate image
 curl "http://localhost:8080/api/snippets/{id}/image?theme=dracula&language=swift" \
   --output snippet.png
 */
