# Rookery

**A colony of code fragments**

Rookery is a Swift-based web application for managing code snippets with beautiful image generation powered by [freeze](https://github.com/charmbracelet/freeze). Think of it as your personal GitHub Gists, but local and focused on Swift's dynamic programming capabilities.

## Features

- **Snippet Management**: Store and organize code snippets with metadata
- **Syntax Highlighting**: Beautiful code display using Splash
- **Image Generation**: Create stunning code images with freeze
- **Search & Filter**: Find snippets by title, language, tags, or content
- **Favorites**: Mark important snippets for quick access
- **Tags**: Organize snippets with custom tags
- **Web UI**: Clean, modern interface for managing your collection
- **RESTful API**: Full API for programmatic access
- **Built-in Swift Library**: Ships with 29 production-ready Swift snippets

## Built-in Swift Snippet Library

Rookery comes pre-loaded with a curated library of Swift code snippets covering modern patterns and best practices:

### Async/Await & Concurrency (8 snippets)
- Basic async functions
- TaskGroup for concurrent fetches
- Actor-based thread-safe cache
- AsyncSequence for pagination
- Continuations for bridging callbacks
- Task timeout patterns
- AsyncStream for events
- MainActor ViewModels

### Data Structures (7 snippets)
- Generic Stack with Sequence conformance
- Queue with O(1) amortized operations
- Doubly Linked List
- Binary Heap / Priority Queue
- LRU Cache
- Trie (Prefix Tree)
- Graph with BFS, DFS, and shortest path

### Error Handling (6 snippets)
- Custom errors with LocalizedError
- Result type with flatMap chaining
- Contextual error wrappers
- Retry with exponential backoff
- Multi-error validation
- Optional.orThrow extension

### Networking (7 snippets)
- Type-safe API client protocol
- Production HTTPClient implementation
- Type-safe endpoint definitions
- Download with progress reporting
- Multipart form data uploads
- WebSocket client (actor-based)
- Rookery API client example

### Utilities (1 snippet)
- AnyEncodable type erasure

## Tech Stack

- **Backend**: Swift 6.0 + Vapor 4
- **Database**: SQLite (via Fluent ORM)
- **Templating**: Leaf
- **Syntax Highlighting**: Splash
- **Image Generation**: freeze CLI

## Prerequisites

- Swift 6.0+ (macOS 15+)
- [freeze](https://github.com/charmbracelet/freeze) for image generation

Install freeze:

```bash
brew install charmbracelet/tap/freeze
```

## Installation

1. Clone the repository:

```bash
git clone <repository-url>
cd rookery
```

2. Build the project:

```bash
swift build
```

3. Run the application:

```bash
swift run
```

4. Open your browser to `http://localhost:8080`

## Usage

### Web Interface

- **Home Page**: View all snippets in a grid layout
- **Create Snippet**: Click "+ New Snippet" to add a code fragment
- **View Snippet**: Click on any snippet to see the full code with syntax highlighting
- **Generate Image**: Click the image button to create a freeze image
- **Search**: Use the search bar to filter snippets

### API Endpoints

#### Snippets

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/snippets` | List all snippets |
| `GET` | `/api/snippets/:id` | Get specific snippet |
| `POST` | `/api/snippets` | Create new snippet |
| `PUT` | `/api/snippets/:id` | Update snippet |
| `DELETE` | `/api/snippets/:id` | Delete snippet |

#### Search & Utilities

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/snippets/search?q=query` | Search snippets |
| `GET` | `/api/snippets/:id/freeze` | Generate freeze image |
| `GET` | `/api/snippets/tags` | List all unique tags |
| `GET` | `/api/snippets/languages` | List all unique languages |
| `GET` | `/health` | Health check |

#### Example: Create a Snippet

```bash
curl -X POST http://localhost:8080/api/snippets \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Quick Sort",
    "code": "func quickSort<T: Comparable>(_ array: [T]) -> [T] { ... }",
    "language": "swift",
    "description": "Efficient sorting algorithm",
    "tags": ["algorithm", "sorting"],
    "isFavorite": false
  }'
```

#### Example: Generate Freeze Image

```bash
curl "http://localhost:8080/api/snippets/{id}/freeze?theme=nord" > snippet.png
```

### Supported Languages

```
bash, c, clojure, cpp, csharp, css, elixir, go, haskell, html,
java, javascript, json, kotlin, lua, markdown, md, perl, php,
python, r, ruby, rust, scala, scss, sh, sql, swift, typescript,
xml, yaml
```

## Freeze Themes

Popular themes for image generation:

- `catppuccin-mocha` (default)
- `nord`
- `dracula`
- `tokyonight`
- `gruvbox`

See [freeze documentation](https://github.com/charmbracelet/freeze) for all available themes.

## Project Structure

```
rookery/
├── Package.swift                    # Swift package manifest
├── Sources/App/
│   ├── Controllers/
│   │   └── SnippetController.swift  # API routes
│   ├── Models/
│   │   └── Snippet.swift            # Database model + DTOs
│   ├── Migrations/
│   │   └── CreateSnippet.swift      # Database migration
│   ├── Services/
│   │   ├── FreezeService.swift      # Freeze integration
│   │   ├── SyntaxHighlighter.swift  # Syntax highlighting
│   │   └── RateLimitMiddleware.swift # Rate limiting
│   ├── configure.swift              # App configuration
│   ├── routes.swift                 # Route registration
│   └── entrypoint.swift             # Main entry point
├── Examples/                        # Swift example source files
│   ├── AsyncAwaitExamples.swift
│   ├── DataStructures.swift
│   ├── ErrorHandling.swift
│   ├── NetworkingExamples.swift
│   └── VaporAPIExamples.swift
├── Resources/Views/                 # Leaf templates
├── Public/                          # Static assets (CSS, JS)
├── Tests/AppTests/                  # Test suite
│   └── AppTests.swift               # 25 comprehensive tests
└── rookery.sqlite                   # SQLite database
```

## Development

### Running in Development

```bash
swift run App serve --hostname 0.0.0.0 --port 8080
```

### Running Tests

Tests require Xcode to be installed (for XCTest framework):

```bash
# If Xcode is installed but not selected as default
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# Or if Xcode is your default developer directory
swift test
```

### Test Coverage

The test suite includes 25 tests covering:

| Category | Tests |
|----------|-------|
| CRUD Operations | 6 tests |
| Search | 5 tests |
| Tags & Languages | 2 tests |
| Input Validation | 5 tests |
| Security | 3 tests |
| Syntax Highlighter | 2 tests |
| Health & Bulk | 2 tests |

### Database

The SQLite database is stored as `rookery.sqlite` in the project root. To reset:

```bash
rm rookery.sqlite
swift run  # Migrations will run automatically
```

## Security Features

- **Input Validation**: Title length, code size, language whitelist, tag limits
- **Rate Limiting**: 100 requests per minute per IP
- **SQL Injection Prevention**: Parameterized queries via Fluent ORM
- **XSS Prevention**: HTML escaping in syntax highlighter
- **Command Injection Prevention**: Validated theme and format parameters for freeze

## Future Enhancements

- [ ] User authentication and multi-user support
- [ ] Collections/folders for organizing snippets
- [ ] Import from GitHub Gists
- [ ] Export to various formats (markdown, JSON, etc.)
- [ ] CLI companion tool
- [ ] Snippet versioning
- [ ] Public sharing links
- [ ] Dark/light theme toggle
- [ ] Code execution (for safe languages)

## Inspiration

The name "Rookery" comes from the behavior of swifts (the birds), which build colonies of nests to hold their precious eggs—just like this app holds your precious code fragments.

## License

MIT License

---

**Built with Swift 6 + Vapor 4** | Powered by [freeze](https://github.com/charmbracelet/freeze)
