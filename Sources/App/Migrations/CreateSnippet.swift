import Fluent

struct CreateSnippet: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("snippets")
            .id()
            .field("title", .string, .required)
            .field("code", .string, .required)
            .field("language", .string, .required)
            .field("description", .string)
            .field("tags", .array(of: .string), .required)
            .field("is_favorite", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("snippets").delete()
    }
}
