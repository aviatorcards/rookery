// ErrorHandling.swift
// Swift Error Handling Patterns and Best Practices

import Foundation

// MARK: - Custom Error Types

/// Define domain-specific errors with associated values
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case noData
    case decodingFailed(underlying: Error)
    case httpError(statusCode: Int, message: String?)
    case timeout
    case noConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .noData:
            return "No data received from server"
        case .decodingFailed(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message ?? "Unknown error")"
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No internet connection"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again"
        case .timeout:
            return "The server is taking too long to respond. Try again later."
        default:
            return nil
        }
    }
}

// MARK: - Result Type Patterns

/// Using Result for explicit error handling
func fetchData(from urlString: String) -> Result<Data, NetworkError> {
    guard let url = URL(string: urlString) else {
        return .failure(.invalidURL(urlString))
    }

    // Simulated synchronous fetch for example purposes
    do {
        let data = try Data(contentsOf: url)
        return .success(data)
    } catch {
        return .failure(.noData)
    }
}

/// Transform Result with map and flatMap
func fetchAndDecode<T: Decodable>(
    from urlString: String,
    as type: T.Type
) -> Result<T, NetworkError> {
    fetchData(from: urlString).flatMap { data in
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return .success(decoded)
        } catch {
            return .failure(.decodingFailed(underlying: error))
        }
    }
}

// MARK: - Error Chaining and Wrapping

/// Wrapper error that preserves context
struct ContextualError: Error, LocalizedError {
    let context: String
    let underlying: Error
    let file: String
    let line: Int

    var errorDescription: String? {
        "\(context): \(underlying.localizedDescription)"
    }

    init(_ context: String, underlying: Error, file: String = #file, line: Int = #line) {
        self.context = context
        self.underlying = underlying
        self.file = file
        self.line = line
    }
}

/// Wrap errors with context
func loadUserProfile(id: Int) throws -> UserProfile {
    do {
        let data = try loadFromDisk(filename: "user_\(id).json")
        return try JSONDecoder().decode(UserProfile.self, from: data)
    } catch {
        throw ContextualError("Failed to load user profile \(id)", underlying: error)
    }
}

// MARK: - Typed Throws (Swift 6)

/// Using typed throws for precise error handling
enum ValidationError: Error {
    case emptyField(String)
    case invalidFormat(field: String, expected: String)
    case outOfRange(field: String, min: Int, max: Int)
}

func validateEmail(_ email: String) throws(ValidationError) {
    guard !email.isEmpty else {
        throw .emptyField("email")
    }

    let emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
    guard email.contains(emailRegex) else {
        throw .invalidFormat(field: "email", expected: "user@domain.com")
    }
}

// MARK: - Error Recovery Patterns

/// Retry with exponential backoff
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: Duration = .seconds(1),
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    var delay = initialDelay

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                try await Task.sleep(for: delay)
                delay = delay * 2  // Exponential backoff
            }
        }
    }

    throw lastError!
}

/// Fallback with default value
func withFallback<T>(
    default defaultValue: T,
    operation: () throws -> T
) -> T {
    do {
        return try operation()
    } catch {
        return defaultValue
    }
}

// MARK: - Validation with Multiple Errors

/// Collect multiple validation errors
struct ValidationResult {
    private var errors: [ValidationError] = []

    mutating func add(_ error: ValidationError) {
        errors.append(error)
    }

    var isValid: Bool { errors.isEmpty }
    var allErrors: [ValidationError] { errors }

    func throwIfInvalid() throws {
        guard let first = errors.first else { return }
        if errors.count == 1 {
            throw first
        } else {
            throw CompositeValidationError(errors: errors)
        }
    }
}

struct CompositeValidationError: Error, LocalizedError {
    let errors: [ValidationError]

    var errorDescription: String? {
        "Multiple validation errors: \(errors.map { "\($0)" }.joined(separator: ", "))"
    }
}

/// Validate a form collecting all errors
func validateForm(name: String, email: String, age: Int) -> ValidationResult {
    var result = ValidationResult()

    if name.isEmpty {
        result.add(.emptyField("name"))
    }

    if email.isEmpty {
        result.add(.emptyField("email"))
    } else if !email.contains("@") {
        result.add(.invalidFormat(field: "email", expected: "valid email address"))
    }

    if age < 0 || age > 150 {
        result.add(.outOfRange(field: "age", min: 0, max: 150))
    }

    return result
}

// MARK: - Guard and Early Exit Pattern

/// Clean error handling with guard statements
func processOrder(orderData: [String: Any]) throws -> Order {
    guard let id = orderData["id"] as? String else {
        throw OrderError.missingField("id")
    }

    guard let items = orderData["items"] as? [[String: Any]], !items.isEmpty else {
        throw OrderError.missingField("items")
    }

    guard let total = orderData["total"] as? Double, total > 0 else {
        throw OrderError.invalidValue("total must be positive")
    }

    return Order(id: id, itemCount: items.count, total: total)
}

// MARK: - Optional to Error Conversion

extension Optional {
    /// Unwrap or throw an error
    func orThrow(_ error: @autoclosure () -> Error) throws -> Wrapped {
        guard let value = self else {
            throw error()
        }
        return value
    }
}

// Usage example
func findUser(id: Int, in users: [User]) throws -> User {
    try users.first { $0.id == id }
        .orThrow(UserError.notFound(id: id))
}

// MARK: - Supporting Types

struct UserProfile: Codable {
    let id: Int
    let name: String
    let email: String
}

struct Order {
    let id: String
    let itemCount: Int
    let total: Double
}

struct User: Identifiable {
    let id: Int
    let name: String
}

enum OrderError: Error {
    case missingField(String)
    case invalidValue(String)
}

enum UserError: Error {
    case notFound(id: Int)
}

func loadFromDisk(filename: String) throws -> Data {
    let url = URL(fileURLWithPath: filename)
    return try Data(contentsOf: url)
}
