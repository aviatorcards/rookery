import Vapor
import Fluent

struct SnippetController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let snippets = routes.grouped("api", "snippets")
        
        snippets.get(use: index)
        snippets.get(":snippetID", use: show)
        snippets.post(use: create)
        snippets.put(":snippetID", use: update)
        snippets.delete(":snippetID", use: delete)
        snippets.get("search", use: search)
        snippets.get(":snippetID", "freeze", use: freeze)
        snippets.get("tags", use: tags)
        snippets.get("languages", use: languages)
    }
    
    // GET /api/snippets - List all snippets
    func index(req: Request) async throws -> [SnippetDTO] {
        let snippets = try await Snippet.query(on: req.db).all()
        return try snippets.map { try SnippetDTO(from: $0) }
    }
    
    // GET /api/snippets/:id - Get specific snippet
    func show(req: Request) async throws -> SnippetDTO {
        guard let snippet = try await Snippet.find(req.parameters.get("snippetID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return try SnippetDTO(from: snippet)
    }
    
    // POST /api/snippets - Create new snippet
    func create(req: Request) async throws -> SnippetDTO {
        let dto = try req.content.decode(CreateSnippetDTO.self)

        // SECURITY: Validate input before processing
        try dto.validate()

        // Normalize and sanitize input
        let normalizedDTO = dto.normalized()

        let snippet = Snippet(
            title: normalizedDTO.title,
            code: normalizedDTO.code,
            language: normalizedDTO.language,
            description: normalizedDTO.description,
            tags: normalizedDTO.tags ?? [],
            isFavorite: normalizedDTO.isFavorite ?? false
        )

        try await snippet.save(on: req.db)
        return try SnippetDTO(from: snippet)
    }
    
    // PUT /api/snippets/:id - Update snippet
    func update(req: Request) async throws -> SnippetDTO {
        guard let snippet = try await Snippet.find(req.parameters.get("snippetID"), on: req.db) else {
            throw Abort(.notFound)
        }

        let dto = try req.content.decode(CreateSnippetDTO.self)

        // SECURITY: Validate input before processing
        try dto.validate()

        // Normalize and sanitize input
        let normalizedDTO = dto.normalized()

        snippet.title = normalizedDTO.title
        snippet.code = normalizedDTO.code
        snippet.language = normalizedDTO.language
        snippet.description = normalizedDTO.description
        snippet.tags = normalizedDTO.tags ?? []
        snippet.isFavorite = normalizedDTO.isFavorite ?? false

        try await snippet.save(on: req.db)
        return try SnippetDTO(from: snippet)
    }
    
    // DELETE /api/snippets/:id - Delete snippet
    func delete(req: Request) async throws -> HTTPStatus {
        guard let snippet = try await Snippet.find(req.parameters.get("snippetID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        try await snippet.delete(on: req.db)
        return .noContent
    }
    
    // GET /api/snippets/search?q=query - Search snippets
    func search(req: Request) async throws -> [SnippetDTO] {
        guard let query = req.query[String.self, at: "q"] else {
            throw Abort(.badRequest, reason: "Missing search query parameter 'q'")
        }

        // Validate query length to prevent DoS
        guard !query.isEmpty && query.count <= 100 else {
            throw Abort(.badRequest, reason: "Search query must be 1-100 characters")
        }

        // Use safe contains filter instead of raw SQL LIKE to prevent SQL injection
        let snippets = try await Snippet.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$title ~~ query)
                group.filter(\.$code ~~ query)
                group.filter(\.$description ~~ query)
            }
            .all()

        return try snippets.map { try SnippetDTO(from: $0) }
    }
    
    // GET /api/snippets/:id/freeze - Generate freeze image
    func freeze(req: Request) async throws -> Response {
        guard let snippet = try await Snippet.find(req.parameters.get("snippetID"), on: req.db) else {
            throw Abort(.notFound)
        }
        
        // Extract query parameters with defaults
        let theme = req.query[String.self, at: "theme"] ?? "catppuccin-mocha"
        let format = req.query[String.self, at: "format"] ?? "png"
        let window = req.query[Bool.self, at: "window"] ?? true
        let padding = req.query[String.self, at: "padding"] ?? "20,40"
        let margin = req.query[String.self, at: "margin"] ?? "0"
        let background = req.query[Bool.self, at: "background"] ?? true
        let showLineNumbers = req.query[Bool.self, at: "showLineNumbers"] ?? false
        
        let config = FreezeService.FreezeConfig(
            theme: theme,
            window: window,
            padding: padding,
            margin: margin,
            background: background,
            showLineNumbers: showLineNumbers
        )
        
        let freezeService = FreezeService()
        let imageData = try await freezeService.generateImage(
            code: snippet.code,
            language: snippet.language,
            config: config,
            format: format,
            on: req
        )
        
        let response = Response()
        response.body = .init(data: imageData)
        response.headers.contentType = format == "svg" ? .init(type: "image", subType: "svg+xml") : .png
        return response
    }
    
    // GET /api/snippets/tags - List all unique tags
    func tags(req: Request) async throws -> [String] {
        let snippets = try await Snippet.query(on: req.db).all()
        let allTags = snippets.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    // GET /api/snippets/languages - List all unique languages
    func languages(req: Request) async throws -> [String] {
        let snippets = try await Snippet.query(on: req.db).all()
        let allLanguages = snippets.map { $0.language }
        return Array(Set(allLanguages)).sorted()
    }
}
