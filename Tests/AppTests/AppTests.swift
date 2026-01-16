import XCTest
import XCTVapor
import Fluent
import FluentSQLiteDriver
@testable import App

final class AppTests: XCTestCase {

    // MARK: - CRUD Tests

    func testListSnippets_Empty() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "api/snippets") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippets = try? res.content.decode([SnippetDTO].self)
            XCTAssertNotNil(snippets)
            XCTAssertEqual(snippets?.count, 0)
        }
    }

    func testCreateSnippet_Success() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Hello World",
                code: "print(\"Hello, World!\")",
                language: "swift",
                description: "A simple hello world",
                tags: ["example", "beginner"],
                isFavorite: false
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let snippet = try? res.content.decode(SnippetDTO.self)
            XCTAssertNotNil(snippet)
            XCTAssertEqual(snippet?.title, "Hello World")
            XCTAssertEqual(snippet?.language, "swift")
            XCTAssertEqual(snippet?.tags, ["example", "beginner"])
        })
    }

    func testCreateAndRetrieveSnippet() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        var createdID: UUID?

        // Create
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Test Snippet",
                code: "let x = 42",
                language: "swift",
                description: "Testing",
                tags: ["test"],
                isFavorite: true
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let snippet = try? res.content.decode(SnippetDTO.self)
            createdID = snippet?.id
        })

        guard let id = createdID else {
            XCTFail("Failed to create snippet")
            return
        }

        // Retrieve
        try await app.test(.GET, "api/snippets/\(id)") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippet = try? res.content.decode(SnippetDTO.self)
            XCTAssertEqual(snippet?.title, "Test Snippet")
            XCTAssertEqual(snippet?.code, "let x = 42")
            XCTAssertEqual(snippet?.isFavorite, true)
        }
    }

    func testUpdateSnippet() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        var snippetID: UUID?

        // Create
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Original",
                code: "original code",
                language: "swift",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            let snippet = try? res.content.decode(SnippetDTO.self)
            snippetID = snippet?.id
        })

        guard let id = snippetID else {
            XCTFail("Failed to create snippet")
            return
        }

        // Update
        try await app.test(.PUT, "api/snippets/\(id)", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Updated Title",
                code: "updated code",
                language: "python",
                description: "Now with description",
                tags: ["updated"],
                isFavorite: true
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let snippet = try? res.content.decode(SnippetDTO.self)
            XCTAssertEqual(snippet?.title, "Updated Title")
            XCTAssertEqual(snippet?.language, "python")
            XCTAssertEqual(snippet?.description, "Now with description")
        })
    }

    func testDeleteSnippet() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        var snippetID: UUID?

        // Create
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "To Delete",
                code: "delete me",
                language: "swift",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            let snippet = try? res.content.decode(SnippetDTO.self)
            snippetID = snippet?.id
        })

        guard let id = snippetID else {
            XCTFail("Failed to create snippet")
            return
        }

        // Delete
        try await app.test(.DELETE, "api/snippets/\(id)") { res async in
            XCTAssertEqual(res.status, .noContent)
        }

        // Verify gone
        try await app.test(.GET, "api/snippets/\(id)") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testGetNonexistentSnippet() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let fakeID = UUID()
        try await app.test(.GET, "api/snippets/\(fakeID)") { res async in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    // MARK: - Search Tests

    func testSearchSnippets_ByTitle() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        // Create test snippets
        try await createTestSnippet(app: app, title: "Swift Async Await", code: "async let x = fetch()", language: "swift")
        try await createTestSnippet(app: app, title: "Python Basics", code: "print('hello')", language: "python")
        try await createTestSnippet(app: app, title: "Swift Actors", code: "actor MyActor {}", language: "swift")

        // Search
        try await app.test(.GET, "api/snippets/search?q=Swift") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippets = try? res.content.decode([SnippetDTO].self)
            XCTAssertEqual(snippets?.count, 2)
        }
    }

    func testSearchSnippets_ByCode() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await createTestSnippet(app: app, title: "Snippet 1", code: "func fibonacci(_ n: Int) -> Int", language: "swift")
        try await createTestSnippet(app: app, title: "Snippet 2", code: "def factorial(n):", language: "python")

        try await app.test(.GET, "api/snippets/search?q=fibonacci") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippets = try? res.content.decode([SnippetDTO].self)
            XCTAssertEqual(snippets?.count, 1)
            XCTAssertEqual(snippets?.first?.title, "Snippet 1")
        }
    }

    func testSearchSnippets_NoResults() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await createTestSnippet(app: app, title: "Test", code: "code", language: "swift")

        try await app.test(.GET, "api/snippets/search?q=nonexistent") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippets = try? res.content.decode([SnippetDTO].self)
            XCTAssertEqual(snippets?.count, 0)
        }
    }

    func testSearchSnippets_EmptyQuery() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "api/snippets/search?q=") { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testSearchSnippets_MissingQuery() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "api/snippets/search") { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Tags and Languages Tests

    func testGetTags() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await createTestSnippet(app: app, title: "S1", code: "c", language: "swift", tags: ["async", "concurrency"])
        try await createTestSnippet(app: app, title: "S2", code: "c", language: "swift", tags: ["networking", "async"])
        try await createTestSnippet(app: app, title: "S3", code: "c", language: "python", tags: ["data-science"])

        try await app.test(.GET, "api/snippets/tags") { res async in
            XCTAssertEqual(res.status, .ok)
            let tags = try? res.content.decode([String].self)
            XCTAssertNotNil(tags)
            XCTAssertTrue(tags?.contains("async") ?? false)
            XCTAssertTrue(tags?.contains("concurrency") ?? false)
            XCTAssertTrue(tags?.contains("networking") ?? false)
            XCTAssertTrue(tags?.contains("data-science") ?? false)
        }
    }

    func testGetLanguages() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await createTestSnippet(app: app, title: "S1", code: "c", language: "swift")
        try await createTestSnippet(app: app, title: "S2", code: "c", language: "python")
        try await createTestSnippet(app: app, title: "S3", code: "c", language: "swift")
        try await createTestSnippet(app: app, title: "S4", code: "c", language: "javascript")

        try await app.test(.GET, "api/snippets/languages") { res async in
            XCTAssertEqual(res.status, .ok)
            let languages = try? res.content.decode([String].self)
            XCTAssertNotNil(languages)
            XCTAssertEqual(languages?.count, 3) // swift, python, javascript (unique)
            XCTAssertTrue(languages?.contains("swift") ?? false)
            XCTAssertTrue(languages?.contains("python") ?? false)
            XCTAssertTrue(languages?.contains("javascript") ?? false)
        }
    }

    // MARK: - Validation Tests

    func testCreateSnippet_TitleTooLong() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let longTitle = String(repeating: "a", count: 201)
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: longTitle,
                code: "test",
                language: "swift",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testCreateSnippet_CodeTooLarge() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let largeCode = String(repeating: "x", count: 100_001)
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Test",
                code: largeCode,
                language: "swift",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testCreateSnippet_InvalidLanguage() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Test",
                code: "test",
                language: "invalid-language",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testCreateSnippet_EmptyTitle() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "   ",
                code: "test",
                language: "swift",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testCreateSnippet_TooManyTags() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let manyTags = Array(repeating: "tag", count: 21)
        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Test",
                code: "test",
                language: "swift",
                description: nil,
                tags: manyTags,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    // MARK: - Security Tests

    func testCreateSnippet_CommandInjectionInLanguage() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: "Test",
                code: "test",
                language: "swift; rm -rf /",
                description: nil,
                tags: nil,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testSearch_SQLInjection() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "api/snippets/search?q=' OR '1'='1") { res async in
            // Should not error or return all data
            XCTAssertTrue(res.status == .ok || res.status == .badRequest)
        }
    }

    func testSearch_QueryTooLong() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        let longQuery = String(repeating: "x", count: 101)
        try await app.test(.GET, "api/snippets/search?q=\(longQuery)") { res async in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Syntax Highlighter Tests

    func testSyntaxHighlighter_HTMLEscaping() throws {
        let highlighter = SyntaxHighlighterService()
        let maliciousCode = "<script>alert('XSS')</script>"

        let result = highlighter.highlight(maliciousCode, language: "javascript")

        // Should not contain raw script tags
        XCTAssertFalse(result.contains("<script>alert('XSS')</script>"))
        XCTAssertTrue(result.contains("&lt;") || result.contains("&gt;"))
    }

    func testSyntaxHighlighter_LanguageInjection() throws {
        let highlighter = SyntaxHighlighterService()
        let maliciousLanguage = "javascript\" onload=\"alert('XSS')\""

        let result = highlighter.highlight("test", language: maliciousLanguage)

        XCTAssertFalse(result.contains("onload=\"alert"))
    }

    // MARK: - Health Check

    func testHealthCheck() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }

    // MARK: - Bulk Operations Tests

    func testListMultipleSnippets() async throws {
        let app = try await makeTestApp()
        defer { Task { try? await app.asyncShutdown() } }

        // Create 5 snippets
        for i in 1...5 {
            try await createTestSnippet(app: app, title: "Snippet \(i)", code: "code \(i)", language: "swift")
        }

        try await app.test(.GET, "api/snippets") { res async in
            XCTAssertEqual(res.status, .ok)
            let snippets = try? res.content.decode([SnippetDTO].self)
            XCTAssertEqual(snippets?.count, 5)
        }
    }

    // MARK: - Helper Methods

    private func makeTestApp() async throws -> Application {
        let app = try await Application.make(.testing)

        // Use in-memory SQLite for testing
        app.databases.use(.sqlite(.memory), as: .sqlite)

        // Configure Leaf
        app.views.use(.leaf)

        // Add migrations
        app.migrations.add(CreateSnippet())

        // Run migrations
        try await app.autoMigrate()

        // Register routes
        try routes(app)

        return app
    }

    @discardableResult
    private func createTestSnippet(
        app: Application,
        title: String,
        code: String,
        language: String,
        tags: [String]? = nil
    ) async throws -> UUID {
        var createdID: UUID?

        try await app.test(.POST, "api/snippets", beforeRequest: { req in
            try req.content.encode(CreateSnippetDTO(
                title: title,
                code: code,
                language: language,
                description: nil,
                tags: tags,
                isFavorite: nil
            ))
        }, afterResponse: { res async in
            let snippet = try? res.content.decode(SnippetDTO.self)
            createdID = snippet?.id
        })

        guard let id = createdID else {
            throw TestError.failedToCreateSnippet
        }
        return id
    }
}

enum TestError: Error {
    case failedToCreateSnippet
}
