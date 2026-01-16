import Vapor

/// Simple in-memory rate limiting middleware
/// SECURITY: Prevents abuse by limiting requests per IP address
final class RateLimitMiddleware: AsyncMiddleware {
    // Track request counts per IP address
    private actor RequestTracker {
        private var requests: [String: (count: Int, resetTime: Date)] = [:]
        private let maxRequests: Int
        private let windowSeconds: TimeInterval

        init(maxRequests: Int = 100, windowSeconds: TimeInterval = 60) {
            self.maxRequests = maxRequests
            self.windowSeconds = windowSeconds
        }

        func checkAndIncrement(ip: String) -> Bool {
            let now = Date()

            // Clean up old entries periodically
            if requests.count > 1000 {
                requests = requests.filter { $0.value.resetTime > now }
            }

            if let entry = requests[ip] {
                // Check if window has expired
                if now > entry.resetTime {
                    // Reset counter for new window
                    requests[ip] = (count: 1, resetTime: now.addingTimeInterval(windowSeconds))
                    return true
                } else if entry.count < maxRequests {
                    // Increment counter within window
                    requests[ip] = (count: entry.count + 1, resetTime: entry.resetTime)
                    return true
                } else {
                    // Rate limit exceeded
                    return false
                }
            } else {
                // First request from this IP
                requests[ip] = (count: 1, resetTime: now.addingTimeInterval(windowSeconds))
                return true
            }
        }

        func getRemainingTime(ip: String) -> TimeInterval? {
            guard let entry = requests[ip] else { return nil }
            return entry.resetTime.timeIntervalSince(Date())
        }
    }

    private let tracker: RequestTracker

    init(maxRequests: Int = 100, windowSeconds: TimeInterval = 60) {
        self.tracker = RequestTracker(maxRequests: maxRequests, windowSeconds: windowSeconds)
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Get client IP address
        let clientIP = request.headers.forwarded.first?.for ??
                       request.peerAddress?.ipAddress ??
                       "unknown"

        // Check rate limit
        let allowed = await tracker.checkAndIncrement(ip: clientIP)

        if allowed {
            return try await next.respond(to: request)
        } else {
            // Rate limit exceeded
            let remainingTime = await tracker.getRemainingTime(ip: clientIP) ?? 60
            request.logger.warning("Rate limit exceeded for IP: \(clientIP)")

            let response = Response(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: String(Int(remainingTime)))
            response.body = .init(string: "Rate limit exceeded. Please try again later.")
            return response
        }
    }
}
