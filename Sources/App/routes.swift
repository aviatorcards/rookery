import Vapor
import Fluent
import Leaf

// Context structures for Leaf templates
struct LanguageCount: Encodable {
    let name: String
    let count: Int
}

struct IndexContext: Encodable {
    let snippets: [Snippet]
    let languages: [LanguageCount]
    let title: String
}

struct SnippetContext: Encodable {
    let snippet: Snippet
    let highlightedCode: String
    let title: String
}

func routes(_ app: Application) throws {
    // API routes
    try app.register(collection: SnippetController())
    
    // Web routes
    app.get { req async throws -> View in
        let snippets = try await Snippet.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()

        // Collect unique languages with counts
        var languageCounts: [String: Int] = [:]
        for snippet in snippets {
            languageCounts[snippet.language, default: 0] += 1
        }

        let languages = languageCounts
            .map { LanguageCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }  // Sort by count descending

        let context = IndexContext(
            snippets: snippets,
            languages: languages,
            title: "Rookery - Your Code Colony"
        )

        return try await req.view.render("index", context)
    }
    
    app.get("snippets", ":snippetID") { req async throws -> View in
        guard let snippet = try await Snippet.find(req.parameters.get("snippetID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        let highlighter = SyntaxHighlighterService()
        let highlightedCode = highlighter.highlight(snippet.code, language: snippet.language)
        
        let context = SnippetContext(
            snippet: snippet,
            highlightedCode: highlightedCode,
            title: snippet.title
        )
        
        return try await req.view.render("snippet", context)
    }
    
    // Health check
    app.get("health") { req in
        return ["status": "healthy", "app": "rookery"]
    }
}
