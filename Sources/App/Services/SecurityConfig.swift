import Foundation

struct SecurityConfig {
    // Shared whitelist of allowed programming languages
    static let allowedLanguages: Set<String> = [
        "swift", "python", "javascript", "typescript", "java", "go", "rust",
        "c", "cpp", "csharp", "ruby", "php", "html", "css", "scss",
        "bash", "sh", "sql", "json", "yaml", "xml", "markdown", "md",
        "kotlin", "scala", "r", "perl", "lua", "elixir", "haskell", "clojure",
    ]
}
