import Splash

struct SyntaxHighlighterService {
    // SECURITY: Whitelist of allowed languages to prevent XSS
    private static let allowedLanguages: Set<String> = [
        "swift", "python", "javascript", "typescript", "java", "go", "rust",
        "c", "cpp", "csharp", "ruby", "php", "html", "css", "scss",
        "bash", "sh", "sql", "json", "yaml", "xml", "markdown", "md",
        "kotlin", "scala", "r", "perl", "lua", "elixir", "haskell", "clojure"
    ]

    /// Highlights code and returns HTML
    func highlight(_ code: String, language: String) -> String {
        // SECURITY: Validate and sanitize language to prevent XSS via class attribute injection
        let normalizedLanguage = language.lowercased()
        let safeLanguage = normalizedLanguage.filter { $0.isLetter || $0.isNumber || $0 == "-" }

        // Validate language is in whitelist
        guard Self.allowedLanguages.contains(safeLanguage) else {
            // Unknown language - just use generic highlighting
            return """
            <pre><code>\(escapeHTML(code))</code></pre>
            """
        }

        // Splash primarily supports Swift
        if safeLanguage == "swift" {
            let highlighter = SyntaxHighlighter(format: HTMLOutputFormat())
            return highlighter.highlight(code)
        }

        // For other languages, return code wrapped in pre/code tags with escaped language class
        return """
        <pre><code class="language-\(safeLanguage)">\(escapeHTML(code))</code></pre>
        """
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

