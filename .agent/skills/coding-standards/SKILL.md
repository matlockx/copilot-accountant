---
name: coding-standards
description: Use this skill when writing Swift code. Provides coding standards, naming conventions, error handling, and best practices.
---

# Swift Coding Standards & Best Practices

Comprehensive coding standards for Swift projects — applicable to iOS, macOS, server-side Swift, and CLI tools.

---

## 1. Formatting & Linting

### Recommended Tools

| Tool | Purpose | Command |
|------|---------|---------|
| `swift-format` | Official Apple formatter | `swift-format format --in-place --recursive Sources/` |
| `SwiftLint` | Linter with 200+ rules | `swiftlint lint --strict` |
| `swiftlint --fix` | Auto-correct safe violations | `swiftlint --fix` |

### Configuration

**.swift-format** (project root):
```json
{
  "indentation": { "spaces": 4 },
  "lineLength": 120,
  "respectsExistingLineBreaks": true,
  "blankLineBetweenMembers": { "insertBlankLine": true }
}
```

**.swiftlint.yml** (project root):
```yaml
disabled_rules:
  - trailing_whitespace
opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
  - closure_spacing
  - empty_count
line_length: 120
```

### Pre-commit Hook

```sh
#!/bin/sh
swift-format lint --recursive Sources/ && swiftlint lint --strict
```

---

## 2. Naming Conventions

### Types & Protocols

```swift
// ✅ UpperCamelCase for types, enums, structs, protocols
struct UserProfile { }
enum NetworkError { }
class AuthenticationManager { }
protocol DataFetchable { }     // Protocol names as adjectives/nouns ending in -able, -ing, or descriptive noun

// ❌ Never snake_case or lowercase for types
struct user_profile { }        // wrong
class authManager { }          // wrong
```

### Variables, Properties & Parameters

```swift
// ✅ lowerCamelCase for variables, properties, parameters, functions
var isLoading: Bool = false
let maximumRetryCount = 3
func fetchUser(withID id: String) -> User { }

// ✅ Boolean names should read as assertions
var isAuthenticated: Bool
var hasCompletedOnboarding: Bool
var canRefresh: Bool

// ❌ Avoid single-letter names outside of trivial closures/loops
var x = user         // wrong (non-trivial context)
for i in 0..<10 { } // fine (trivial index)
```

### Constants & Enums

```swift
// ✅ lowerCamelCase enum cases (Swift 3+ convention)
enum Direction {
    case north, south, east, west
}

enum HTTPStatusCode: Int {
    case ok = 200
    case notFound = 404
    case internalServerError = 500
}

// ✅ Static constants in a type or enum namespace
enum API {
    static let baseURL = "https://api.example.com"
    static let timeout: TimeInterval = 30
}

// ❌ Global constants with k-prefix (Objective-C legacy)
let kBaseURL = "..."  // outdated
```

### Functions & Methods

```swift
// ✅ Verb-first, describe the action clearly
func fetchUserProfile(id: String) async throws -> UserProfile
func validateEmail(_ email: String) -> Bool
func presentAlert(title: String, message: String)

// ✅ Use argument labels to read as English phrases
user.move(from: startPoint, to: endPoint)
list.insert(item, at: 0)

// ❌ Redundant type names in method names
func getUserUser() -> User   // "User" repeated
func fetchStringData() -> String  // redundant "String"
```

---

## 3. Error Handling

### Idiomatic Swift Error Patterns

```swift
// ✅ Define rich, typed errors with associated values
enum NetworkError: Error, LocalizedError {
    case invalidURL(String)
    case httpError(statusCode: Int, body: Data?)
    case decodingFailed(underlying: Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code, _):
            return "HTTP error \(code)"
        case .decodingFailed(let error):
            return "Decoding failed: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        }
    }
}

// ✅ Propagate errors with throws / async throws
func fetchData(from url: URL) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NetworkError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, body: data)
    }
    return data
}

// ✅ Handle errors at the right layer with do/catch
do {
    let data = try await fetchData(from: endpoint)
    let user = try JSONDecoder().decode(User.self, from: data)
    await update(with: user)
} catch NetworkError.timeout {
    showRetryPrompt()
} catch let NetworkError.httpError(code, _) where code == 401 {
    navigateToLogin()
} catch {
    logger.error("Unexpected error: \(error)")
    showGenericError()
}

// ❌ Swallowing errors silently
do {
    let result = try riskyOperation()
} catch { }   // never swallow — at minimum log

// ❌ Force-try in production code
let data = try! JSONEncoder().encode(value)  // crashes on failure

// ✅ Result type for deferred/callback-based APIs
func loadImage(url: URL, completion: @escaping (Result<UIImage, ImageError>) -> Void) {
    // ...
}
```

### Optional Handling

```swift
// ✅ guard-let for early returns
func process(input: String?) {
    guard let value = input, !value.isEmpty else {
        return
    }
    // use `value` here
}

// ✅ if-let for single-branch optional use
if let user = currentUser {
    greet(user)
}

// ✅ nil-coalescing for defaults
let displayName = user.nickname ?? user.fullName

// ❌ Force-unwrap (!) in production logic
let name = user!.name   // crash waiting to happen

// ❌ Pyramid of doom
if let a = optA {
    if let b = optB {
        if let c = optC { }
    }
}
// ✅ Use multi-binding guard/if-let
guard let a = optA, let b = optB, let c = optC else { return }
```

---

## 4. Project Structure

### iOS / macOS App

```
MyApp/
├── App/
│   ├── MyApp.swift              # @main entry point
│   └── AppDelegate.swift
├── Features/
│   ├── Auth/
│   │   ├── AuthView.swift
│   │   ├── AuthViewModel.swift
│   │   └── AuthService.swift
│   └── Home/
│       ├── HomeView.swift
│       └── HomeViewModel.swift
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   └── Endpoint.swift
│   ├── Persistence/
│   │   └── Database.swift
│   └── Extensions/
│       ├── String+Extensions.swift
│       └── Date+Extensions.swift
├── Models/
│   ├── User.swift
│   └── Product.swift
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.strings
└── Tests/
    ├── Unit/
    └── Integration/
```

### Swift Package (Server / CLI)

```
MyPackage/
├── Package.swift
├── Sources/
│   └── MyPackage/
│       ├── main.swift            # CLI entry point (if executable)
│       ├── MyPackage.swift       # public API surface
│       └── Internal/
├── Tests/
│   └── MyPackageTests/
│       └── MyPackageTests.swift
└── README.md
```

---

## 5. Testing Patterns

### XCTest (Unit Tests)

```swift
import XCTest
@testable import MyApp

final class UserServiceTests: XCTestCase {

    // AIDEV-NOTE: setUp/tearDown ensure test isolation — don't share mutable state
    var sut: UserService!
    var mockRepository: MockUserRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = UserService(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // ✅ Test names: test_<method>_<condition>_<expectedResult>
    func test_fetchUser_withValidID_returnsUser() async throws {
        // Arrange
        let expected = User(id: "42", name: "Alice")
        mockRepository.stubbedUser = expected

        // Act
        let result = try await sut.fetchUser(id: "42")

        // Assert
        XCTAssertEqual(result, expected)
    }

    func test_fetchUser_whenRepositoryThrows_propagatesError() async {
        // Arrange
        mockRepository.stubbedError = NetworkError.timeout

        // Act / Assert
        do {
            _ = try await sut.fetchUser(id: "99")
            XCTFail("Expected error to be thrown")
        } catch NetworkError.timeout {
            // ✅ expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

### Swift Testing (Swift 5.9+)

```swift
import Testing
@testable import MyApp

@Suite("UserService")
struct UserServiceTests {

    @Test("returns user for valid ID")
    func fetchUserWithValidID() async throws {
        let mock = MockUserRepository(stubbedUser: User(id: "1", name: "Bob"))
        let service = UserService(repository: mock)
        let user = try await service.fetchUser(id: "1")
        #expect(user.name == "Bob")
    }

    @Test("propagates timeout error", .tags(.networking))
    func fetchUserTimeout() async throws {
        let mock = MockUserRepository(stubbedError: NetworkError.timeout)
        let service = UserService(repository: mock)
        await #expect(throws: NetworkError.timeout) {
            try await service.fetchUser(id: "x")
        }
    }
}
```

### Mocking Pattern (Protocol-based)

```swift
// ✅ Define dependencies as protocols for easy mocking
protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> User
}

final class MockUserRepository: UserRepositoryProtocol {
    var stubbedUser: User?
    var stubbedError: Error?
    var fetchCallCount = 0

    func fetchUser(id: String) async throws -> User {
        fetchCallCount += 1
        if let error = stubbedError { throw error }
        return stubbedUser!
    }
}
```

---

## 6. Async / Concurrency

### async/await (Swift 5.5+)

```swift
// ✅ Prefer async/await over callbacks
func loadProfile() async throws -> Profile {
    let data = try await apiClient.get("/profile")
    return try JSONDecoder().decode(Profile.self, from: data)
}

// ✅ Parallel async work with async let
async let user = fetchUser(id: userId)
async let posts = fetchPosts(for: userId)
let (resolvedUser, resolvedPosts) = try await (user, posts)

// ✅ TaskGroup for dynamic parallelism
let results = try await withThrowingTaskGroup(of: Post.self) { group in
    for id in postIDs {
        group.addTask { try await fetchPost(id: id) }
    }
    return try await group.reduce(into: []) { $0.append($1) }
}
```

### Actors

```swift
// ✅ Use actors to protect shared mutable state
actor Cache {
    private var storage: [String: Data] = [:]

    func value(for key: String) -> Data? {
        storage[key]
    }

    func store(_ data: Data, for key: String) {
        storage[key] = data
    }
}

// ✅ @MainActor for UI updates
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load() async {
        let fetched = try? await service.fetchItems()
        items = fetched ?? []
    }
}
```

### Sendable & Data Races

```swift
// ✅ Mark types Sendable when they are safe to share across concurrency domains
struct UserProfile: Sendable {
    let id: String
    let name: String
}

// ✅ Use @Sendable closures in async contexts
func processItems(_ handler: @Sendable @escaping (Item) -> Void) { }

// ❌ Don't capture mutable state in concurrent closures
var count = 0
Task { count += 1 }   // data race — use actor or Atomic
```

---

## 7. Type Safety

### Value vs Reference Types

```swift
// ✅ Prefer structs (value semantics) for data models
struct Point { var x: Double; var y: Double }
struct User: Codable, Identifiable { var id: UUID; var name: String }

// ✅ Use classes when you need reference semantics / inheritance / ObjC interop
class ViewController: UIViewController { }

// ✅ Use enums with associated values instead of stringly-typed flags
enum AuthState {
    case unauthenticated
    case authenticating(progress: Double)
    case authenticated(User)
    case failed(AuthError)
}
```

### Generics & Protocols

```swift
// ✅ Protocol + generic > class hierarchy for reusability
protocol Repository<T> {
    associatedtype T
    func findAll() async throws -> [T]
    func findByID(_ id: String) async throws -> T?
}

// ✅ some / any for existentials (Swift 5.7+)
func makeStorage() -> some Storage { FileStorage() }   // opaque, preferred
func process(storage: any Storage) { }                  // existential, when type is unknown at compile time
```

### Codable

```swift
// ✅ Use CodingKeys only when JSON keys differ from Swift names
struct Product: Codable {
    let id: UUID
    let displayName: String
    let priceInCents: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case priceInCents = "price_in_cents"
    }
}

// ✅ Custom decoder for complex JSON shapes
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    // ...
}
```

---

## 8. Common Pitfalls

### Retain Cycles

```swift
// ❌ Strong capture of self in closures causes retain cycle
class ViewModel {
    var onUpdate: (() -> Void)?

    func setup() {
        onUpdate = {
            self.refresh()   // retain cycle: ViewModel → closure → ViewModel
        }
    }
}

// ✅ Capture self weakly
onUpdate = { [weak self] in
    self?.refresh()
}

// ✅ Or unowned when self is guaranteed to outlive the closure
onUpdate = { [unowned self] in
    self.refresh()
}
```

### Implicit Main Thread Assumptions

```swift
// ❌ Updating UI from background thread
Task.detached {
    let data = try await fetch()
    self.label.text = data.title  // ❌ UI on background thread — crash
}

// ✅ Hop to main actor for UI work
Task.detached {
    let data = try await fetch()
    await MainActor.run {
        self.label.text = data.title
    }
}
```

### Over-using `any` Existentials

```swift
// ❌ Existential box loses static dispatch optimization
func process(items: [any Hashable]) { }

// ✅ Generic function keeps static dispatch
func process<T: Hashable>(items: [T]) { }
```

### String-based APIs

```swift
// ❌ Stringly-typed keys
UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")

// ✅ Type-safe key wrapper or enum
extension UserDefaults {
    enum Key: String {
        case hasSeenOnboarding
    }
    var hasSeenOnboarding: Bool {
        get { bool(forKey: Key.hasSeenOnboarding.rawValue) }
        set { set(newValue, forKey: Key.hasSeenOnboarding.rawValue) }
    }
}
```

---

## 9. Performance

### Value Types & Copy-on-Write

```swift
// ✅ Swift arrays/dicts/sets use CoW — no need to defensively copy
let snapshot = largeArray   // O(1) until mutation

// ✅ For custom CoW, check uniqueness before mutating
mutating func append(_ element: Element) {
    if !isKnownUniquelyReferenced(&_storage) {
        _storage = _storage.copy()
    }
    _storage.append(element)
}
```

### Lazy Collections

```swift
// ✅ Use lazy to avoid intermediate allocations
let firstActive = users.lazy
    .filter { $0.isActive }
    .first(where: { $0.role == .admin })
```

### Prefer `let` Over `var`

```swift
// ✅ Compiler can optimize immutable values more aggressively
let computedTotal = items.reduce(0) { $0 + $1.price }
```

### Avoid Repeated Dynamic Dispatch

```swift
// ✅ Mark leaf classes final to eliminate vtable overhead
final class ImageCache { }

// ✅ Use Whole Module Optimization (WMO) in release builds
// Xcode: Build Settings → Compilation Mode = Whole Module
```

### Strings & Collections

```swift
// ✅ Use reserveCapacity when final size is known
var ids: [String] = []
ids.reserveCapacity(expectedCount)

// ✅ CharacterView is O(n) — cache count if needed
let count = text.count   // O(n) for Swift Strings — assign to variable

// ✅ Prefer Data over [UInt8] for binary buffers
var buffer = Data(capacity: 4096)
```

---

## Quick Reference Checklist

- [ ] All types use UpperCamelCase; all values/functions use lowerCamelCase
- [ ] No force-unwrap (`!`) or force-try (`try!`) in production paths
- [ ] Errors are typed (`enum … : Error`) and handled at the appropriate layer
- [ ] Async code uses `async/await`; shared mutable state protected by `actor`
- [ ] UI mutations run on `@MainActor`
- [ ] Closures capturing `self` use `[weak self]` unless lifetime is guaranteed
- [ ] Protocol-based dependencies to enable unit-testing with mocks
- [ ] `swift-format` and `SwiftLint` pass cleanly
- [ ] `struct` for data models; `class` only when reference semantics required
- [ ] `final` on leaf classes; `let` by default
