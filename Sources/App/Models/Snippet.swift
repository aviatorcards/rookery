import Fluent
import Vapor

final class Snippet: Model, Content, @unchecked Sendable {
    static let schema = "snippets"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "language")
    var language: String
    
    @OptionalField(key: "description")
    var description: String?
    
    @Field(key: "tags")
    var tags: [String]
    
    @Field(key: "is_favorite")
    var isFavorite: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        title: String,
        code: String,
        language: String,
        description: String? = nil,
        tags: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.code = code
        self.language = language
        self.description = description
        self.tags = tags
        self.isFavorite = isFavorite
    }
}

// DTO for creating/updating snippets
struct CreateSnippetDTO: Content {
    let title: String
    let code: String
    let language: String
    let description: String?
    let tags: [String]?
    let isFavorite: Bool?

    // SECURITY: Whitelist of allowed languages
    private static let allowedLanguages: Set<String> = [
        "swift", "python", "javascript", "typescript", "java", "go", "rust",
        "c", "cpp", "csharp", "ruby", "php", "html", "css", "scss",
        "bash", "sh", "sql", "json", "yaml", "xml", "markdown", "md",
        "kotlin", "scala", "r", "perl", "lua", "elixir", "haskell", "clojure"
    ]

    /// Validates the DTO fields to prevent malicious input
    func validate() throws {
        // Validate title
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Title cannot be empty")
        }
        guard title.count <= 200 else {
            throw Abort(.badRequest, reason: "Title must be 200 characters or less")
        }

        // Validate code
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Code cannot be empty")
        }
        guard code.count <= 100_000 else {
            throw Abort(.badRequest, reason: "Code must be 100,000 characters or less")
        }

        // Validate language
        let normalizedLanguage = language.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.allowedLanguages.contains(normalizedLanguage) else {
            throw Abort(.badRequest, reason: "Invalid language. Allowed: \(Self.allowedLanguages.sorted().joined(separator: ", "))")
        }

        // Validate description (if provided)
        if let desc = description, !desc.isEmpty {
            guard desc.count <= 1000 else {
                throw Abort(.badRequest, reason: "Description must be 1000 characters or less")
            }
        }

        // Validate tags (if provided)
        if let tagList = tags {
            guard tagList.count <= 20 else {
                throw Abort(.badRequest, reason: "Maximum 20 tags allowed")
            }

            for tag in tagList {
                let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTag.isEmpty else {
                    throw Abort(.badRequest, reason: "Tags cannot be empty")
                }
                guard trimmedTag.count <= 50 else {
                    throw Abort(.badRequest, reason: "Each tag must be 50 characters or less")
                }
            }
        }
    }

    /// Returns a normalized version with trimmed whitespace
    func normalized() -> CreateSnippetDTO {
        return CreateSnippetDTO(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            code: code,
            language: language.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            isFavorite: isFavorite
        )
    }
}

// DTO for snippet responses
struct SnippetDTO: Content {
    let id: UUID
    let title: String
    let code: String
    let language: String
    let description: String?
    let tags: [String]
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    init(from snippet: Snippet) throws {
        guard let id = snippet.id else {
            throw Abort(.internalServerError, reason: "Snippet missing ID")
        }
        self.id = id
        self.title = snippet.title
        self.code = snippet.code
        self.language = snippet.language
        self.description = snippet.description
        self.tags = snippet.tags
        self.isFavorite = snippet.isFavorite
        self.createdAt = snippet.createdAt
        self.updatedAt = snippet.updatedAt
    }
}
