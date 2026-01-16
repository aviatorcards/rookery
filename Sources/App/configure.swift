import Vapor
import Fluent
import FluentSQLiteDriver
import Leaf

public func configure(_ app: Application) async throws {
    // Configure SQLite database
    app.databases.use(.sqlite(.file("rookery.sqlite")), as: .sqlite)
    
    // Configure Leaf templating
    app.views.use(.leaf)
    
    // Configure middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // SECURITY: Add rate limiting to prevent API abuse
    // 100 requests per minute per IP address
    app.middleware.use(RateLimitMiddleware(maxRequests: 100, windowSeconds: 60))
    
    // Add migrations
    app.migrations.add(CreateSnippet())
    
    // Run migrations automatically
    try await app.autoMigrate()
    
    // Register routes
    try routes(app)
}
