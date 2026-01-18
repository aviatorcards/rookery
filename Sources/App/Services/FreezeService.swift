import Foundation
import Vapor

struct FreezeService {
    // SECURITY: Whitelist of allowed themes to prevent command injection
    private static let allowedThemes: Set<String> = [
        "catppuccin-mocha", "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato",
        "dracula", "nord", "tokyonight", "gruvbox", "gruvbox-light",
        "base16", "charm", "github-dark", "github-light",
        "monokai", "solarized-dark", "solarized-light", "zenburn",
    ]

    // SECURITY: Whitelist of allowed formats to prevent path traversal
    private static let allowedFormats: Set<String> = ["png", "svg"]

    /// Generates a beautiful code image using the freeze CLI tool
    /// - Parameters:
    ///   - code: The code to render
    ///   - language: Programming language for syntax highlighting
    ///   - theme: Freeze theme (default: catppuccin-mocha)
    ///   - format: Output format (png or svg)
    ///   - req: Vapor request
    /// - Returns: Image data
    /// Configuration options for Freeze
    struct FreezeConfig {
        let theme: String
        let window: Bool
        let padding: String
        let margin: String
        let background: Bool
        let showLineNumbers: Bool
    }

    /// Generates a beautiful code image using the freeze CLI tool
    /// - Parameters:
    ///   - code: The code to render
    ///   - language: Programming language for syntax highlighting
    ///   - config: Configuration options
    ///   - format: Output format (png or svg)
    ///   - req: Vapor request
    /// - Returns: Image data
    func generateImage(
        code: String,
        language: String,
        config: FreezeConfig,
        format: String = "png",
        on req: Request
    ) async throws -> Data {
        // SECURITY: Validate code size to prevent DoS
        guard !code.isEmpty && code.count <= 100_000 else {
            throw Abort(.badRequest, reason: "Code must be between 1-100,000 characters")
        }

        // SECURITY: Validate theme is in whitelist
        let normalizedTheme = config.theme.lowercased()
        guard Self.allowedThemes.contains(normalizedTheme) else {
            throw Abort(
                .badRequest,
                reason:
                    "Invalid theme. Allowed themes: \(Self.allowedThemes.sorted().joined(separator: ", "))"
            )
        }

        // SECURITY: Validate language is in whitelist
        let normalizedLanguage = language.lowercased()
        guard SecurityConfig.allowedLanguages.contains(normalizedLanguage) else {
            throw Abort(
                .badRequest,
                reason:
                    "Invalid language. Allowed languages: \(SecurityConfig.allowedLanguages.sorted().joined(separator: ", "))"
            )
        }

        // SECURITY: Validate format is in whitelist
        let normalizedFormat = format.lowercased()
        guard Self.allowedFormats.contains(normalizedFormat) else {
            throw Abort(
                .badRequest,
                reason:
                    "Invalid format. Allowed formats: \(Self.allowedFormats.sorted().joined(separator: ", "))"
            )
        }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory

        // Create unique filenames using validated inputs
        let uuid = UUID().uuidString
        let inputFile = tempDir.appendingPathComponent("snippet-\(uuid).\(normalizedLanguage)")
        let outputFile = tempDir.appendingPathComponent("output-\(uuid).\(normalizedFormat)")

        // SECURITY: Verify paths are within temp directory (defense in depth)
        guard inputFile.path.hasPrefix(tempDir.path),
            outputFile.path.hasPrefix(tempDir.path)
        else {
            throw Abort(.internalServerError, reason: "Invalid file path")
        }

        // Write code to temp file
        try code.write(to: inputFile, atomically: true, encoding: .utf8)

        defer {
            // Cleanup temp files with logging
            do {
                try fileManager.removeItem(at: inputFile)
            } catch {
                req.logger.warning("Failed to cleanup input file: \(error)")
            }
            do {
                try fileManager.removeItem(at: outputFile)
            } catch {
                req.logger.warning("Failed to cleanup output file: \(error)")
            }
        }

        // Check if freeze is installed
        let freezePath = try await findFreezePath()

        // Prepare freeze command with validated inputs
        let process = Process()
        process.executableURL = URL(fileURLWithPath: freezePath)

        // Build arguments
        var args = [
            inputFile.path,
            "-o", outputFile.path,
            "--theme", normalizedTheme,
            "--language", normalizedLanguage,
        ]

        // Add optional flags
        if config.window {
            args.append("--window")
        } else {
            args.append("--window=false")
        }

        if !config.background {
            args.append("--background=false")
        }

        if config.showLineNumbers {
            args.append("--show-line-numbers")
        }

        // Sanitize numeric inputs (padding/margin) by ensuring they are integers
        // We accept strings to handle "20,40" format if needed, but for safety let's assume single numbers for now or validate structure
        // Since we are invoking a shell command, let's be strict.
        // We will trust the validation in the controller or do it here.
        // Simple regex check for safe characters 0-9 and commas
        let safePattern = try! NSRegularExpression(pattern: "^[0-9,]+$")

        if !config.padding.isEmpty {
            let range = NSRange(location: 0, length: config.padding.utf16.count)
            if safePattern.firstMatch(in: config.padding, options: [], range: range) != nil {
                args.append(contentsOf: ["--padding", config.padding])
            }
        }

        if !config.margin.isEmpty {
            let range = NSRange(location: 0, length: config.margin.utf16.count)
            if safePattern.firstMatch(in: config.margin, options: [], range: range) != nil {
                args.append(contentsOf: ["--margin", config.margin])
            }
        }

        process.arguments = args

        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Run freeze with timeout to prevent resource exhaustion
        try process.run()

        // SECURITY: Implement timeout to prevent hanging processes
        let timeoutSeconds: TimeInterval = 10.0
        let startTime = Date()

        // Wait for process with timeout
        while process.isRunning {
            if Date().timeIntervalSince(startTime) > timeoutSeconds {
                process.terminate()
                // Give it a moment to terminate gracefully
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                req.logger.warning("Freeze process timed out after \(timeoutSeconds) seconds")
                throw Abort(.requestTimeout, reason: "Image generation timed out")
            }
            // Sleep briefly to avoid busy waiting
            try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds
        }

        // Check if process succeeded
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            // SECURITY: Log detailed error but return generic message to user
            req.logger.error(
                "Freeze process failed with status \(process.terminationStatus): \(errorMessage)")
            throw Abort(.internalServerError, reason: "Failed to generate image")
        }

        // Read generated image
        guard fileManager.fileExists(atPath: outputFile.path) else {
            throw Abort(.internalServerError, reason: "Freeze did not generate output file")
        }

        let imageData = try Data(contentsOf: outputFile)
        return imageData
    }

    /// Finds the freeze executable path
    private func findFreezePath() async throws -> String {
        // Common installation paths
        let possiblePaths = [
            "/usr/local/bin/freeze",
            "/opt/homebrew/bin/freeze",
            "/usr/bin/freeze",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try to find via 'which' command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["freeze"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
                !path.isEmpty
            {
                return path
            }
        }

        // SECURITY: Don't reveal system details to users
        throw Abort(.serviceUnavailable, reason: "Image generation service is unavailable")
    }
}
