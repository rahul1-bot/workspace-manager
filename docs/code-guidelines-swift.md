0. SWIFT VERSION AND TOOLING
    1. REQUIRED SWIFT VERSION
        1. All code MUST compile under Swift 6 language mode (strict concurrency safety is non-negotiable)
        2. Minimum supported: Swift 5.9 (only when a dependency forces it; document the reason)
        3. Treat ALL compiler warnings as build failures in CI
    2. REQUIRED APPLE PLATFORM BASELINES
        1. Projects MUST explicitly declare target platforms (iOS / iPadOS / macOS) and minimum OS versions
        2. Pick the newest viable OS baseline (lower targets increase complexity, testing surface, and bugs)
        3. If older baselines are required, document the exact reason and the specific APIs that force it
    3. TOOLING STACK
        1. FORMATTER: SwiftFormat — formatting is not a debate
        2. LINTER: SwiftLint — enforce consistency and catch foot-guns
        3. BUILDS/TESTS: Xcode build system + `xcodebuild test` in CI
        4. DEPENDENCIES: Swift Package Manager (SPM) first; avoid CocoaPods unless forced by a dependency
        5. PROFILING: Instruments (Time Profiler, Allocations, Leaks) and signposts where needed
    4. SWIFT 6 KEY FEATURES YOU MUST USE
        1. STRICT CONCURRENCY: `async/await`, `Task`, `actor`, structured concurrency, `Sendable` enforcement
        2. VALUE SEMANTICS: `struct` + immutability by default for domain data
        3. TYPED THROWS: `throws(MyError)` for precise error typing (Swift 6)
        4. NONCOPYABLE TYPES: `~Copyable` for unique ownership semantics where needed
        5. CONSUMING/BORROWING: `consuming` and `borrowing` parameter ownership modifiers for performance-critical paths
        6. `Codable` for serialization boundaries (network, disk) with explicit `CodingKeys` where needed
        7. `Result` only when it improves ergonomics; prefer `throws` for error propagation
        8. Pattern matching and exhaustive `switch` for closed state machines

1. WARNING: SWIFT STANDARDS - ABSOLUTE COMPLIANCE REQUIRED
    1. FILE STRUCTURE
        1. No top-level executable code in production modules (no "script mode" Swift)
        2. Entry points MUST be explicit:
            1. SwiftUI apps: `@main struct MyApp: App`
            2. UIKit apps: `@main` + `UIApplicationMain` / AppDelegate as required
            3. macOS AppKit apps: `@main` + `NSApplicationMain` / AppDelegate as required
        3. File layout must be predictable
            1. One primary type per file
            2. Small supporting types may live beside the primary type if they are tightly coupled
            3. Put protocol conformances in extensions (one conformance per extension)
        4. ALL code MUST be in types (struct, class, enum, actor)
            1. Exception: Top-level free functions ONLY for callbacks, SwiftUI view helpers, or pure utility functions where architecturally appropriate
            2. NEVER use module-level mutable state
        5. Imports must be minimal
            1. Do not import `Foundation`/`UIKit`/`AppKit` by reflex
            2. Import only what you use; prefer per-file imports
        6. CORRECT FILE STRUCTURE EXAMPLE:
            ```swift
            import Foundation

            struct ImageProcessor {
                private let validator: ImageValidator

                init(validator: ImageValidator) {
                    self.validator = validator
                }

                func process(_ image: RawImage) throws -> ProcessedImage {
                    try validator.validate(image)
                    return transform(image)
                }

                private func transform(_ image: RawImage) -> ProcessedImage {
                    ProcessedImage(pixels: image.pixels, metadata: image.metadata)
                }
            }
            ```
    2. ACCESS CONTROL (SWIFT'S `__all__`)
        1. Default to `internal` (Swift's default)
        2. Mark only the true public surface as `public`
        3. Avoid `open` unless subclassing outside the module is an explicit requirement
        4. Use `private` aggressively — every stored property should be `private` unless there is a reason
        5. Use `fileprivate` only when extension in the same file needs access
        6. Access control IS your public API definition — treat it with the same care as Python's `__all__`
    3. TYPE DESIGN
        1. Prefer `struct` for domain data and pure value objects
        2. Prefer `final class` for identity/lifecycle objects (coordinators, controllers, services)
        3. Prefer `actor` for shared mutable state accessed across concurrency domains
        4. Prefer `enum` with associated values for closed state machines and algebraic data types
        5. Prefer composition over inheritance
            1. Keep inheritance shallow (max 2 levels)
            2. If you are reaching for inheritance, ask: "Is this really an IS-A, or am I being lazy?"
        6. FLAT > NESTED: Prefer flat composition over deep inheritance chains
        7. Use concrete types — only add protocol abstractions when you have multiple implementations or need a test seam
        8. Protocols are for seams, not for ego
            1. Create a protocol only when you need a second implementation, a test seam, or a stable boundary
            2. Keep protocols small and cohesive (Interface Segregation)
            3. Prefer protocol composition over one god-protocol
            4. EXAMPLE:
                ```swift
                protocol Predicting: Sendable {
                    func predict(_ input: Tensor) async throws -> Tensor
                }

                protocol Evaluating: Sendable {
                    func evaluate(_ predictions: [Tensor], against targets: [Tensor]) -> Metrics
                }

                struct ModelPipeline {
                    private let predictor: Predicting
                    private let evaluator: Evaluating

                    init(predictor: Predicting, evaluator: Evaluating) {
                        self.predictor = predictor
                        self.evaluator = evaluator
                    }
                }
                ```
        9. METHOD ORDERING INSIDE TYPES (mandatory convention):
            1. `init` / `deinit`
            2. Factory constructors (`static func make…`, convenience inits)
            3. Public methods (the API)
            4. Computed properties
            5. Private helpers (prefixed with nothing extra — Swift uses `private` keyword)
            6. Protocol conformances in extensions (one conformance per extension)
        10. `override` IS COMPILER-ENFORCED:
            1. Swift requires `override` keyword for all method overrides — the compiler catches orphaned overrides automatically
            2. This is equivalent to Python's `@override` decorator but mandatory by language design
    4. DATA MODELING (SWIFT'S PYDANTIC — THE LANGUAGE ITSELF)
        1. Swift does NOT need a third-party library like Pydantic — the language IS the validation framework:
            1. `struct` with `let` properties = `BaseModel` with `frozen=True`
            2. Throwing `init` = `@field_validator`
            3. `Codable` = Pydantic's JSON serialization/deserialization
            4. Compile-time type checking = Pydantic's runtime type validation (but caught earlier)
            5. `Equatable`/`Hashable` = Pydantic's value semantics
        2. Domain data MUST be strongly typed — ban `Any` and `[String: Any]` at domain boundaries
        3. NEVER use untyped dictionaries (`[String: Any]`) where a proper struct would work
        4. Value Objects vs Entity Objects:
            1. Value Objects: Identity by value, immutable, all `let` properties
            2. Entity Objects: Identity by ID, may have `var` properties, use `class` or `actor`
            3. EXAMPLE:
                ```swift
                struct Point2D: Hashable, Sendable {
                    let x: Double
                    let y: Double

                    func distance(to other: Point2D) -> Double {
                        let dx: Double = x - other.x
                        let dy: Double = y - other.y
                        return (dx * dx + dy * dy).squareRoot()
                    }
                }

                final class Experiment: Identifiable {
                    let id: UUID
                    var status: ExperimentStatus
                    var results: [Double]

                    init(id: UUID = UUID(), status: ExperimentStatus = .pending, results: [Double] = []) {
                        self.id = id
                        self.status = status
                        self.results = results
                    }
                }
                ```
        5. Validate inputs at initialization time (fail fast):
            1. Use throwing initializers for data that comes from external sources
            2. Use `preconditionFailure` only for programmer errors (broken invariants), not user/data errors
            3. EXAMPLE — Smart model with full validation:
                ```swift
                struct BayerPattern: Codable, Hashable, Sendable {
                    let pattern: String
                    let offsetX: Int
                    let offsetY: Int
                    let confidence: Double

                    init(pattern: String, offsetX: Int, offsetY: Int, confidence: Double) throws {
                        let validPatterns: Set<String> = ["RGGB", "GRBG", "GBRG", "BGGR"]
                        guard validPatterns.contains(pattern) else {
                            throw ValidationError.invalidPattern(
                                received: pattern,
                                valid: validPatterns
                            )
                        }
                        guard offsetX == 0 || offsetX == 1 else {
                            throw ValidationError.invalidOffset(axis: "x", value: offsetX)
                        }
                        guard offsetY == 0 || offsetY == 1 else {
                            throw ValidationError.invalidOffset(axis: "y", value: offsetY)
                        }
                        guard (0.0...1.0).contains(confidence) else {
                            throw ValidationError.invalidConfidence(value: confidence)
                        }
                        self.pattern = pattern
                        self.offsetX = offsetX
                        self.offsetY = offsetY
                        self.confidence = confidence
                    }

                    var patternMatrix: [[Int]] {
                        switch pattern {
                        case "RGGB": return [[0, 1], [1, 2]]
                        case "GRBG": return [[1, 0], [2, 1]]
                        case "GBRG": return [[1, 2], [0, 1]]
                        case "BGGR": return [[2, 1], [1, 0]]
                        default: preconditionFailure("Invalid pattern passed validation: \(pattern)")
                        }
                    }
                }

                enum ValidationError: Error, Sendable {
                    case invalidPattern(received: String, valid: Set<String>)
                    case invalidOffset(axis: String, value: Int)
                    case invalidConfidence(value: Double)
                }
                ```
        6. SIMPLE vs SMART MODELS:
            1. SIMPLE — Legitimately simple data holder (no validation needed):
                ```swift
                struct Point2D: Hashable, Sendable {
                    let x: Double
                    let y: Double
                }
                ```
            2. SMART — Full validation, domain logic, computed properties:
                ```swift
                struct EmailAddress: Codable, Hashable, Sendable {
                    let value: String

                    init(_ value: String) throws {
                        let trimmed: String = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.contains("@"), trimmed.count <= 254 else {
                            throw ValidationError.invalidEmail(value: value)
                        }
                        self.value = trimmed
                    }

                    var domain: String {
                        value.split(separator: "@").last.map(String.init) ?? ""
                    }
                }
                ```
            3. When to make models smart:
                1. Has validation rules? → MUST be smart (throwing init)
                2. Has business logic? → MUST be smart (methods)
                3. Has domain behavior? → MUST be smart (computed properties + methods)
                4. Just holds data with no rules? → Can stay simple
                5. Used in collections/comparisons? → Add `Equatable`/`Hashable`
        7. CODABLE FOR EXTERNAL DATA (Swift's TypedDict equivalent):
            1. Use `Codable` with explicit `CodingKeys` for data you receive from external sources (APIs, files)
            2. Use domain structs for data you own and control
            3. NEVER let raw `Codable` DTOs leak into domain logic — map them to domain types at the boundary
            4. EXAMPLE:
                ```swift
                struct APIUserResponse: Codable, Sendable {
                    let userId: String
                    let displayName: String
                    let createdAt: String

                    private enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                        case displayName = "display_name"
                        case createdAt = "created_at"
                    }
                }

                struct User: Hashable, Sendable {
                    let id: String
                    let name: String
                    let createdAt: Date

                    init(from response: APIUserResponse) throws {
                        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
                        guard let date = formatter.date(from: response.createdAt) else {
                            throw MappingError.invalidDate(raw: response.createdAt)
                        }
                        self.id = response.userId
                        self.name = response.displayName
                        self.createdAt = date
                    }
                }
                ```
        8. DATA MODELING INTELLIGENCE PRINCIPLES:
            1. Domain logic MUST live in domain types:
                1. Validation in throwing `init`
                2. Business rules as methods
                3. Invariants enforced at creation
                4. Computed properties for derived data
            2. CustomStringConvertible / CustomDebugStringConvertible:
                1. ALWAYS implement `CustomStringConvertible` for debugging on domain types
                2. Implement `CustomDebugStringConvertible` when debug output needs more detail
            3. Comparable: Implement when natural ordering exists
            4. Sequence/Collection conformance: ONLY for container-like domain types
    5. EXHAUSTIVE SWITCH AND PATTERN MATCHING
        1. Swift's most powerful feature — USE IT
        2. WHEN TO USE SWITCH:
            1. Dispatching on enum cases with associated values
            2. Type-based branching (replacing ugly if/else chains)
            3. Complex conditional logic with multiple factors
            4. Exhaustive state machine transitions
        3. WHEN NOT TO USE SWITCH:
            1. Simple 2-case if/else — overkill
            2. Boolean logic — `if`/`else` is clearer
            3. Range checks — `if value < 10` is clearer
        4. EXHAUSTIVE MATCHING IS MANDATORY:
            1. For your OWN enums: NEVER use `default` — handle every case explicitly
            2. For EXTERNAL/framework enums: use `@unknown default` to catch future additions
            3. `default` on your own enums hides unhandled cases when you add new ones
            4. EXAMPLE:
                ```swift
                enum ProcessingState: Sendable {
                    case idle
                    case loading(progress: Double)
                    case loaded(data: ProcessedData)
                    case failed(error: ProcessingError)
                }

                func handle(_ state: ProcessingState) {
                    switch state {
                    case .idle:
                        showPlaceholder()
                    case .loading(let progress):
                        showProgress(progress)
                    case .loaded(let data):
                        display(data)
                    case .failed(let error):
                        showError(error)
                    }
                }
                ```
        5. PATTERN MATCHING WITH VALUE EXTRACTION:
            ```swift
            func classify(_ response: HTTPResponse) -> ResponseCategory {
                switch (response.statusCode, response.body.isEmpty) {
                case (200..<300, false):
                    return .success
                case (200..<300, true):
                    return .emptySuccess
                case (400..<500, _):
                    return .clientError
                case (500..<600, _):
                    return .serverError
                default:
                    return .unknown
                }
            }
            ```
    6. TYPE ANNOTATIONS AND GENERICS
        1. Swift infers types, but explicit annotations are REQUIRED when:
            1. The inferred type is not immediately obvious from the right-hand side
            2. Stored properties in types (always annotate)
            3. Function parameters and return types (always annotate)
            4. Complex closures
        2. Use modern syntax: `[String]` not `Array<String>`, `[String: Int]` not `Dictionary<String, Int>`
        3. Use `some` for opaque return types: `func makeView() -> some View`
        4. NEVER use `Any` — derive precise types from actual structures
        5. NEVER use `AnyObject` as a lazy escape hatch
        6. NEVER use `[String: Any]` in domain code — create a proper struct
        7. Use `any` protocol existentials explicitly when needed: `any Sendable`, `any Error`
        8. GENERICS (Swift's PEP 695 equivalent — but native since day one):
            1. Use generic parameters for reusable containers and algorithms
            2. Use `where` clauses for complex constraints
            3. Prefer protocol constraints over concrete type constraints
            4. EXAMPLE:
                ```swift
                struct DataPipeline<Input: Sendable, Output: Sendable> {
                    private let stages: [any PipelineStage<Input, Output>]

                    func execute(_ input: Input) async throws -> Output {
                        var current: Any = input
                        for stage in stages {
                            current = try await stage.process(current)
                        }
                        guard let result = current as? Output else {
                            throw PipelineError.typeMismatch
                        }
                        return result
                    }
                }

                func firstElement<T>(of collection: some Collection<T>) -> T? {
                    collection.first
                }
                ```
        9. TYPE ALIASES FOR CLARITY:
            ```swift
            typealias Vector = [Double]
            typealias Matrix = [[Double]]
            typealias ModelOutput<T> = [String: T]
            typealias Callback<T> = (T) -> Void
            ```
    7. METHOD DESIGN
        1. Methods MUST have a SINGLE RESPONSIBILITY
        2. AVOID methods longer than 50-100 lines
        3. EXCEPTION: Complex algorithms or UI layout code may exceed 100 lines if they represent a single conceptual operation
        4. Break complex logic into smaller, well-named helper methods
        5. Helper methods MUST be marked `private`
        6. If a method does more than one thing, split it
        7. Methods should be named with verb phrases following Apple's API Design Guidelines
        8. Use guard clauses for early returns (invert conditions)
        9. Avoid deep nesting (max 3 levels)
        10. COMPUTED PROPERTY vs METHOD:
            1. Use computed property for cheap, pure computations (no side effects, O(1) expected)
            2. Use method for expensive operations, side effects, or anything that might throw
            3. EXAMPLE:
                ```swift
                struct ImageBuffer {
                    private let pixels: [UInt8]
                    private let width: Int
                    private let height: Int

                    var dimensions: (width: Int, height: Int) {
                        (width, height)
                    }

                    var pixelCount: Int {
                        width * height
                    }

                    func computeHistogram() -> [Int] {
                        var histogram: [Int] = Array(repeating: 0, count: 256)
                        for pixel in pixels {
                            histogram[Int(pixel)] += 1
                        }
                        return histogram
                    }
                }
                ```
        11. COMMAND-QUERY SEPARATION:
            1. Methods should either return a value (query) OR have side effects (command), not both
            2. EXAMPLE:
                ```swift
                struct Stack<Element> {
                    private var items: [Element] = []

                    func top() -> Element? {
                        items.last
                    }

                    mutating func pop() {
                        items.removeLast()
                    }
                }
                ```
        12. FACTORY METHODS:
            1. Use `static func` factories for alternative constructors (Swift's `@classmethod`)
            2. AVOID static methods that do not construct — if it does not use `Self`, it probably belongs in another type
            3. EXAMPLE:
                ```swift
                struct ModelConfig: Codable, Sendable {
                    let hiddenSize: Int
                    let numLayers: Int
                    let learningRate: Double

                    static func fromFile(_ path: URL) throws -> ModelConfig {
                        let data: Data = try Data(contentsOf: path)
                        return try JSONDecoder().decode(ModelConfig.self, from: data)
                    }

                    static func defaultConfig() -> ModelConfig {
                        ModelConfig(hiddenSize: 512, numLayers: 6, learningRate: 0.001)
                    }
                }
                ```
        13. EXAMPLE — Single responsibility methods:
            ```swift
            struct UserValidator {
                func validate(_ userData: UserData) throws {
                    try validateEmail(userData.email)
                    try validateAge(userData.age)
                }

                private func validateEmail(_ email: String) throws {
                    guard email.contains("@") else {
                        throw ValidationError.invalidEmail(value: email)
                    }
                }

                private func validateAge(_ age: Int) throws {
                    guard age >= 18 else {
                        throw ValidationError.tooYoung(age: age, minimum: 18)
                    }
                }
            }

            struct UserService {
                private let validator: UserValidator
                private let repository: UserRepository

                init(validator: UserValidator, repository: UserRepository) {
                    self.validator = validator
                    self.repository = repository
                }

                func createUser(from data: UserData) throws -> User {
                    try validator.validate(data)
                    let user: User = User(data: data)
                    try repository.save(user)
                    return user
                }
            }
            ```
    8. NEVER NEST CODE
        1. Maximum 3 levels of nesting
        2. Use GUARD CLAUSES for early exits (Swift's `guard` is purpose-built for this)
        3. Use EXTRACTION to pull complex logic into helper methods
        4. Merge related conditionals when readable
        5. GUARD CLAUSES EXAMPLE:
            BAD — Nested hell:
            ```swift
            func processImage(_ image: CGImage?) -> ProcessedImage {
                if let image = image {
                    if image.width > 0 {
                        if image.bitsPerPixel == 32 {
                            let result = transform(image)
                            return result
                        } else {
                            fatalError("Wrong bit depth")
                        }
                    } else {
                        fatalError("Empty image")
                    }
                } else {
                    fatalError("Image is nil")
                }
            }
            ```
            GOOD — Flat with guards:
            ```swift
            func processImage(_ image: CGImage?) throws -> ProcessedImage {
                guard let image else {
                    throw ImageError.nilImage
                }
                guard image.width > 0 else {
                    throw ImageError.emptyImage(width: image.width, height: image.height)
                }
                guard image.bitsPerPixel == 32 else {
                    throw ImageError.wrongBitDepth(expected: 32, received: image.bitsPerPixel)
                }
                return transform(image)
            }
            ```
        6. EXTRACTION EXAMPLE:
            BAD — 200 line method
            GOOD — Extracted:
            ```swift
            func trainEpoch() throws {
                let batch: Batch = try loadBatch()
                let output: Tensor = forwardPass(batch)
                let loss: Double = computeLoss(output, target: batch.target)
                optimize(loss)
            }
            ```
    9. VARIABLE NAMING
        1. Use camelCase for all variables, methods, and properties
        2. Use PascalCase for types (struct, class, enum, actor, protocol)
        3. Be descriptive but concise
        4. Avoid abbreviations unless universally understood (`URL`, `ID`, `HTTP`)
        5. NO SINGLE LETTER VARIABLES except simple loop indices
        6. Names must encode intent and units: `timeoutSeconds`, `maxRetries`, `cacheSizeBytes`
        7. Boolean variables should be prefixed with `is`, `has`, `should`, `can`, `will`
        8. Collections should be plural
        9. Follow Apple's API Design Guidelines:
            1. Prefer external parameter labels that read like English
            2. Omit needless words
            3. Compensate for weak type information with descriptive names
        10. EXAMPLE:
            BAD naming:
            ```swift
            struct DataProc {
                func proc(_ d: [Double]) -> [Double] {
                    var r: [Double] = []
                    for i in d {
                        if chk(i) { r.append(i) }
                    }
                    return r
                }

                func chk(_ v: Double) -> Bool { v > 0 }
            }
            ```
            GOOD naming:
            ```swift
            struct DataProcessor {
                var maximumItems: Int { 100 }

                func filterPositiveValues(from rawValues: [Double]) -> [Double] {
                    rawValues.filter { isValidValue($0) }
                }

                private func isValidValue(_ value: Double) -> Bool {
                    value > 0
                }
            }
            ```
    10. NO COMMENTS WHATSOEVER
        1. NO NARRATIVE COMMENTS explaining "what the code does"
        2. NO LINE COMMENTS — do not use `//` to explain logic
        3. NO MULTILINE COMMENTS — no `/* */`
        4. NO TODO COMMENTS — track tasks in the ledger, not in code
        5. NO MARK COMMENTS (`// MARK:`) — if your file needs section markers, the file is too large
        6. ONLY ALLOWED EXCEPTIONS:
            1. Legal/licensing headers when required by third-party code
            2. Platform bug workarounds (cite the radar/feedback number)
        7. If a function needs a paragraph to be understood, the function is the problem — refactor it
        8. Let the code be self-documenting through proper naming
    11. STRING FORMATTING AND RESOURCES
        1. ALWAYS use string interpolation `\()` for string formatting (Swift's f-string equivalent)
        2. Use context managers via `defer` for resource cleanup
        3. EXAMPLE:
            ```swift
            let name: String = "Rahul"
            let age: Int = 24
            let message: String = "\(name) is \(age) years old"

            func readConfig(from path: URL) throws -> Config {
                let handle: FileHandle = try FileHandle(forReadingFrom: path)
                defer { try? handle.close() }
                let data: Data = handle.readDataToEndOfFile()
                return try JSONDecoder().decode(Config.self, from: data)
            }
            ```
    12. NO FLAG ARGUMENTS
        1. NEVER use boolean flag arguments in public APIs
        2. Use enums or separate methods
        3. EXAMPLE:
            BAD:
            ```swift
            func loadImage(_ url: URL, useCache: Bool, applyFilter: Bool) async throws -> UIImage { }
            ```
            GOOD:
            ```swift
            enum CachePolicy: Sendable {
                case useCache
                case bypassCache
            }

            enum FilterMode: Sendable {
                case none
                case sharpen
                case denoise
            }

            struct ImageLoadConfig: Sendable {
                let cachePolicy: CachePolicy
                let filterMode: FilterMode
            }

            func loadImage(_ url: URL, config: ImageLoadConfig) async throws -> UIImage { }
            ```
    13. PATH AND RESOURCE HANDLING
        1. ALWAYS use `URL` for file and directory paths, NEVER raw strings
        2. Use `FileManager` for file system operations
        3. Type all path parameters as `URL`, not `String`
        4. Convert string paths to URL immediately at boundaries
        5. EXAMPLE:
            BAD — String paths:
            ```swift
            func loadData(_ dirPath: String) throws -> Data {
                let configPath: String = dirPath + "/config.json"
                return try Data(contentsOf: URL(fileURLWithPath: configPath))
            }
            ```
            GOOD — URL paths:
            ```swift
            struct DataLoader {
                private let rootDirectory: URL
                private let modelDirectory: URL

                init(root: URL) {
                    self.rootDirectory = root
                    self.modelDirectory = root.appendingPathComponent("models")
                }

                func loadDataset(named name: String) throws -> Dataset {
                    let datasetURL: URL = rootDirectory
                        .appendingPathComponent("data")
                        .appendingPathComponent("\(name).json")

                    guard FileManager.default.fileExists(atPath: datasetURL.path) else {
                        throw DataLoadError.missingFile(url: datasetURL)
                    }

                    let data: Data = try Data(contentsOf: datasetURL)
                    return try JSONDecoder().decode(Dataset.self, from: data)
                }
            }
            ```
    14. MULTIPLE RETURN VALUES
        1. For multiple return values, ALWAYS use a struct, NEVER a tuple
        2. Tuple unpacking is fragile and loses semantic meaning
        3. Structs are self-documenting and validated
        4. EXAMPLE:
            BAD — Tuple return (fragile):
            ```swift
            func computeStats(_ data: [Double]) -> (Double, Double, Double) {
                (data.mean(), data.std(), data.median())
            }

            let (mean, std, median) = computeStats(data)
            ```
            GOOD — Struct return (self-documenting):
            ```swift
            struct Statistics: Sendable {
                let mean: Double
                let standardDeviation: Double
                let median: Double
            }

            func computeStats(_ data: [Double]) -> Statistics {
                Statistics(
                    mean: data.mean(),
                    standardDeviation: data.std(),
                    median: data.median()
                )
            }

            let stats: Statistics = computeStats(data)
            ```
    15. CLEAN CODE PRINCIPLES
        1. Types and methods should be small and focused
        2. Code should be DRY (Don't Repeat Yourself)
        3. Methods should do one thing and do it well
        4. Proper separation of concerns
        5. Proper encapsulation of behavior
        6. Avoid deep nesting of control structures
        7. Early returns for guard clauses
        8. Clear and consistent error handling
        9. Fail fast — validate inputs early
        10. Make the happy path obvious
        11. Handle edge cases explicitly
    16. LOGGING (KILL `print()` IN PRODUCTION CODE)
        1. `print()` is acceptable in throwaway experiments — NEVER in shipped/submitted code
        2. Use `os.Logger` for unified logging with privacy annotations
        3. Use `os_signpost` for performance tracing
        4. EXAMPLE:
            ```swift
            import os

            struct AppLog {
                static let network: Logger = Logger(subsystem: "com.example.app", category: "network")
                static let model: Logger = Logger(subsystem: "com.example.app", category: "model")
            }

            struct APIClient {
                func fetchUser(id: String) async throws -> User {
                    AppLog.network.info("Fetching user id=\(id, privacy: .public)")
                    let response: APIUserResponse = try await request(endpoint: .user(id: id))
                    AppLog.network.debug("Response received for user id=\(id, privacy: .public)")
                    return try User(from: response)
                }
            }
            ```
    17. MUTABLE DEFAULT ARGUMENTS EQUIVALENT (DO NOT SMUGGLE SHARED STATE)
        1. Swift value types (Array, Dictionary, Set) are safe as defaults (value semantics)
        2. Reference-type defaults still bite:
            1. Never default-initialize shared reference helpers (e.g., `DateFormatter()`, `JSONDecoder()`)
            2. Prefer dependency injection or static factories
        3. EXAMPLE:
            ```swift
            struct DateParsingService {
                private let formatter: DateFormatter

                init(formatter: DateFormatter) {
                    self.formatter = formatter
                }

                static func iso8601() -> DateParsingService {
                    let formatter: DateFormatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    return DateParsingService(formatter: formatter)
                }
            }
            ```
    18. SWIFT IDIOMS
        1. Prefer `guard` for early exits and invariants (Swift's purpose-built guard clause)
        2. Prefer optional chaining and `map`/`flatMap`/`compactMap` where they improve clarity
        3. Ban force unwraps (`!`) in production code
        4. Ban `as!` and minimize `as?` by designing types properly
        5. Exhaustive `switch` on your own enums (NEVER use `default`)
        6. Use `@unknown default` only for external/framework enums
        7. Prefer `URL` over `String` for paths and endpoints
        8. Prefer `Measurement` / `DateComponents` / `TimeInterval` where units matter
        9. PREFER BUILT-IN HIGHER-ORDER FUNCTIONS OVER MANUAL LOOPS:
            1. Use `map`, `filter`, `reduce`, `compactMap`, `flatMap`, `contains`, `allSatisfy`, `first(where:)`
            2. These are declarative and more readable
            3. Prefer trailing closures for single-closure APIs
            ```swift
            let hasNaN: Bool = values.contains(where: \.isNaN)
            let total: Double = weights.reduce(0, +)
            let validPredictions: [Prediction] = predictions.filter { $0.confidence > 0.9 }
            let names: [String] = users.map(\.name)
            ```
        10. OPTIONAL BINDING PATTERNS:
            1. `if let` for conditional unwrap when both paths have work
            2. `guard let` for early exit on nil
            3. `??` for default values
            4. Optional chaining for safe property access
            ```swift
            guard let user = fetchedUser else {
                throw FetchError.userNotFound(id: userId)
            }

            let displayName: String = user.nickname ?? user.fullName
            let avatarSize: CGFloat = user.preferences?.avatarSize ?? 44.0
            ```
    19. CONCURRENCY (STRUCTURED OR NOTHING)
        1. Use Swift Concurrency as the default (NOT Grand Central Dispatch)
        2. UI code MUST run on the main actor
            1. ViewModels that mutate UI state should be `@MainActor`
        3. Shared mutable state MUST live in an `actor` (or be proven thread-confined)
        4. Mark all types that cross concurrency boundaries as `Sendable`
        5. Respect cancellation:
            1. Check `Task.isCancelled` for long loops
            2. Use `try Task.checkCancellation()` where appropriate
        6. Avoid detached tasks unless you can explain the lifetime and cancellation semantics
        7. Never block the main thread (no synchronous network, no heavy parsing, no image decoding in UI paths)
        8. EXAMPLE:
            ```swift
            @MainActor
            final class ImageViewModel: ObservableObject {
                @Published private(set) var processedImage: UIImage?
                @Published private(set) var isLoading: Bool = false

                private let processor: ImageProcessing

                init(processor: ImageProcessing) {
                    self.processor = processor
                }

                func loadAndProcess(from url: URL) async {
                    isLoading = true
                    defer { isLoading = false }

                    do {
                        let rawData: Data = try await URLSession.shared.data(from: url).0
                        let processed: UIImage = try await processor.process(rawData)
                        processedImage = processed
                    } catch {
                        AppLog.model.error("Image processing failed: \(error.localizedDescription)")
                    }
                }
            }
            ```
    20. DEFENSIVE COPYING
        1. Protect internal state from external mutation when dealing with reference types
        2. Copy mutable reference-type data received from outside
        3. Expose read-only views or copy into immutable representations
        4. `struct` (value types) handle this automatically — this rule is for `class`/reference-type boundaries
        5. EXAMPLE:
            ```swift
            final class DataBuffer {
                private var items: [Double]

                init(initialData: [Double]) {
                    self.items = initialData
                }

                var data: [Double] {
                    items
                }

                func append(_ value: Double) {
                    items.append(value)
                }
            }
            ```

1. PROPER APP ARCHITECTURE PRINCIPLES
    1. SOLID PRINCIPLES
        1. Single Responsibility: A type has one reason to change
        2. Open/Closed: Extend behavior via composition, not surgery
        3. Liskov Substitution: Protocol-based designs must remain substitutable
        4. Interface Segregation: Many small protocols beat one mega-protocol
        5. Dependency Inversion: High-level logic depends on abstractions, not concrete APIs
        6. EXAMPLE:
            BAD — Single type doing everything:
            ```swift
            struct User {
                func saveToDatabase() { }
                func sendEmail() { }
                func validatePassword() { }
            }
            ```
            GOOD — Separated responsibilities:
            ```swift
            struct User: Sendable {
                let id: String
                let email: String
                let name: String
            }

            struct UserRepository {
                func save(_ user: User) throws { }
            }

            struct EmailService {
                func sendWelcomeEmail(to user: User) async throws { }
            }

            struct PasswordValidator {
                func validate(_ password: String) throws { }
            }
            ```
        7. EXAMPLE (Service boundary via protocol):
            ```swift
            protocol UserFetching: Sendable {
                func fetchUser(id: String) async throws -> User
            }

            struct UserService: Sendable {
                private let client: UserFetching

                init(client: UserFetching) {
                    self.client = client
                }

                func loadProfile(id: String) async throws -> UserProfile {
                    let user: User = try await client.fetchUser(id: id)
                    return UserProfile(user: user)
                }
            }
            ```
    2. LAYERED ARCHITECTURE (I/O AT THE EDGES, PURE LOGIC IN THE CORE)
        1. UI Layer: SwiftUI views / ViewControllers
        2. App Layer: ViewModels, Coordinators, Orchestration
        3. Domain Layer: Pure business rules, validation, domain models
        4. Data Layer: API clients, persistence, cache, DTO mapping
        5. Dependencies flow inward
        6. Domain layer MUST NOT import UIKit/AppKit/SwiftUI
        7. Network/file/database I/O happens at boundaries (data layer), not inside domain rules
        8. Pure core = trivially testable; I/O-mixed core = mock nightmare
        9. EXAMPLE:
            ```swift
            struct Evaluator {
                func evaluate(model: Model, data: [Sample]) -> Double {
                    computeMetric(model: model, data: data)
                }

                private func computeMetric(model: Model, data: [Sample]) -> Double { 0.0 }
            }

            struct EvaluationPipeline {
                private let modelLoader: ModelLoader
                private let dataLoader: DataLoader
                private let evaluator: Evaluator

                func run(modelPath: URL, dataPath: URL) async throws -> Double {
                    let model: Model = try modelLoader.load(from: modelPath)
                    let data: [Sample] = try dataLoader.load(from: dataPath)
                    return evaluator.evaluate(model: model, data: data)
                }
            }
            ```
    3. COMPOSITION OVER INHERITANCE
        1. Compose services and behaviors via stored properties and protocols
        2. Prefer small, testable components over giant "Manager" god-objects
        3. Prefer `struct` composition for pure logic; `class`/`actor` only where identity/lifecycle is required
        4. EXAMPLE:
            ```swift
            struct Engine: Sendable {
                let horsepower: Int
                let fuelType: String

                func start() { }
            }

            struct Transmission: Sendable {
                let gearCount: Int

                func shift(to gear: Int) {
                    precondition((1...gearCount).contains(gear))
                }
            }

            struct Car {
                private let engine: Engine
                private let transmission: Transmission

                init(engine: Engine, transmission: Transmission) {
                    self.engine = engine
                    self.transmission = transmission
                }

                func startAndDrive() {
                    engine.start()
                    transmission.shift(to: 1)
                }
            }
            ```
    4. UI ARCHITECTURE (SWIFTUI / UIKIT / APPKIT)
        1. SwiftUI (default for new Apple-platform UI unless blocked)
            1. Views are pure functions of state
            2. Side effects live in ViewModels/services, triggered via `.task`, `onAppear`, or explicit user actions
            3. Keep `body` small; extract subviews and view-specific components
            4. State ownership rules:
                1. `@State` for local view state
                2. `@StateObject` for owned reference models
                3. `@ObservedObject` for injected reference models
                4. `@Environment` / `@EnvironmentObject` only for truly global concerns
            5. iPadOS requirements (when targeting iPad):
                1. Support dynamic type, split view/multitasking, and variable window sizes
                2. Keyboard shortcuts and focus must work for power users
                3. Avoid phone-only assumptions
        2. UIKit (when necessary)
            1. No business logic in ViewControllers
            2. Prefer diffable data sources and compositional layouts for collection views
            3. Auto Layout over manual frame math
        3. AppKit (macOS)
            1. Prefer SwiftUI where it fits; bridge via `NSHostingView` when needed
            2. Respect macOS conventions: menu commands, windowing, keyboard shortcuts, focus handling
            3. Avoid iOS-isms in macOS UI

2. ADDITIONAL CRITICAL STANDARDS
    1. ERROR HANDLING AND FAIL FAST
        1. Prefer `throws` over "return nil and pray"
        2. Error messages MUST include: what failed, expected vs received, and a debugging hint
        3. Never use `try!` in production code
        4. Never swallow errors with empty `catch`
        5. Define project-level error domains with a base error protocol/enum
        6. Use `defer` for cleanup (Swift's `finally`)
        7. Use domain-specific error types with associated values for context
        8. Always type exception variables
        9. ERROR HIERARCHY EXAMPLE:
            ```swift
            protocol AppError: Error, Sendable { }

            enum DataLoadError: AppError {
                case missingFile(url: URL)
                case decodingFailed(url: URL, underlying: Error)
                case invalidFormat(expected: String, received: String)
            }

            enum ModelError: AppError {
                case architectureMismatch(expected: String, loaded: String)
                case weightsMissing(layer: String)
            }
            ```
        10. ERROR WRAPPING WITH CONTEXT:
            ```swift
            struct DatasetLoader {
                func load(from url: URL) throws -> Dataset {
                    do {
                        let data: Data = try Data(contentsOf: url)
                        return try JSONDecoder().decode(Dataset.self, from: data)
                    } catch let error as CocoaError where error.code == .fileNoSuchFile {
                        throw DataLoadError.missingFile(url: url)
                    } catch {
                        throw DataLoadError.decodingFailed(url: url, underlying: error)
                    }
                }
            }
            ```
        11. ASSERTIONS FOR INVARIANTS:
            ```swift
            struct MultiHeadAttention {
                func forward(_ input: Tensor) -> Tensor {
                    assert(input.rank == 3, "Expected 3D tensor, got \(input.rank)D with shape \(input.shape)")

                    let output: Tensor = computeAttention(input)

                    assert(
                        output.shape == input.shape,
                        "Shape mismatch: expected \(input.shape), got \(output.shape)"
                    )

                    return output
                }
            }
            ```
    2. TESTING
        1. Prefer XCTest for production code unit tests
        2. Use UI tests for critical flows (login, purchase, onboarding) if applicable
        3. For quick sanity checks, use a heredoc Swift run (no file pollution):
            ```bash
            swift - <<'EOF'
            import Foundation

            struct Point: Equatable { let x: Int; let y: Int }
            func add(_ a: Point, _ b: Point) -> Point { Point(x: a.x + b.x, y: a.y + b.y) }

            let output = add(Point(x: 1, y: 2), Point(x: 3, y: 4))
            precondition(output == Point(x: 4, y: 6))
            print("ok: \(output)")
            EOF
            ```
    3. PERFORMANCE CONSIDERATIONS
        1. Profile before optimizing (Instruments, not vibes)
        2. Keep heavy work off the main thread (parsing, image decoding, compression)
        3. Avoid excessive SwiftUI view invalidations:
            1. Keep observed state minimal
            2. Prefer immutable models and stable identity (`id`) for lists
        4. Avoid unnecessary allocations in hot paths
        5. Prefer streaming APIs (`AsyncSequence`, incremental decoding) for large data
        6. Cache expensive computations where correct
        7. Use `__slots__` equivalent: `struct` (value types) are already stack-allocated and optimized
        8. Use `nonisolated` and `Sendable` deliberately to avoid unnecessary actor hops
    4. SECURITY CONSIDERATIONS
        1. Secrets must never ship in source control
        2. Sensitive user data belongs in:
            1. Keychain (credentials, tokens)
            2. App sandbox-protected storage with appropriate data protection classes
        3. Do not store secrets in `UserDefaults`
        4. Use TLS for all network traffic; respect App Transport Security (ATS)
        5. Minimize entitlements; every entitlement is an attack surface
        6. Validate and sanitize inputs from deep links, clipboard, drag-and-drop, file imports
        7. Avoid logging sensitive data (use privacy annotations in `Logger`)
    5. ACCESSIBILITY AND LOCALIZATION
        1. Accessibility is a functional requirement, not an afterthought
        2. SwiftUI views must expose meaningful accessibility labels/values
        3. Support Dynamic Type (do not hardcode sizes)
        4. Avoid hardcoded user-facing strings:
            1. SwiftUI: `LocalizedStringKey`
            2. UIKit/AppKit: `NSLocalizedString` or typed localization layer
        5. Verify critical flows with VoiceOver before shipping
    6. DEPENDENCY INJECTION
        1. Constructor injection is preferred
        2. Keep dependencies explicit (no hidden singletons)
        3. Use factories for complex wiring
        4. Use protocols at boundaries (API clients, persistence) to enable testing
        5. EXAMPLE:
            ```swift
            protocol EmailSending: Sendable {
                func send(to: String, subject: String, body: String) async throws
            }

            struct SMTPEmailSender: EmailSending {
                private let host: String
                private let port: Int

                init(host: String, port: Int) {
                    self.host = host
                    self.port = port
                }

                func send(to: String, subject: String, body: String) async throws { }
            }

            struct NotificationService {
                private let emailSender: EmailSending

                init(emailSender: EmailSending) {
                    self.emailSender = emailSender
                }

                func notifyUser(_ user: User, message: String) async throws {
                    try await emailSender.send(
                        to: user.email,
                        subject: "Notification",
                        body: message
                    )
                }
            }
            ```
    7. CONFIGURATION MANAGEMENT
        1. Configuration must be typed, validated, and immutable at runtime
        2. Use Info.plist / build settings only for non-secret configuration
        3. Environment-based config (Debug/Staging/Prod) must be explicit and auditable
        4. Store secrets outside the repo (CI secrets, local `.xcconfig` ignored by git, keychain)
        5. EXAMPLE:
            ```swift
            struct DatabaseConfig: Sendable {
                let host: String
                let port: Int
                let username: String
                let databaseName: String

                static func fromEnvironment() -> DatabaseConfig {
                    DatabaseConfig(
                        host: ProcessInfo.processInfo.environment["DB_HOST"] ?? "localhost",
                        port: Int(ProcessInfo.processInfo.environment["DB_PORT"] ?? "5432") ?? 5432,
                        username: ProcessInfo.processInfo.environment["DB_USER"] ?? "postgres",
                        databaseName: ProcessInfo.processInfo.environment["DB_NAME"] ?? "myapp"
                    )
                }

                var connectionString: String {
                    "postgresql://\(username)@\(host):\(port)/\(databaseName)"
                }
            }

            struct AppConfig: Sendable {
                let database: DatabaseConfig
                let isDebugMode: Bool
                let maxWorkers: Int

                init(database: DatabaseConfig, isDebugMode: Bool = false, maxWorkers: Int = 4) {
                    precondition(maxWorkers >= 1, "maxWorkers must be at least 1, got \(maxWorkers)")
                    self.database = database
                    self.isDebugMode = isDebugMode
                    self.maxWorkers = maxWorkers
                }
            }
            ```

3. CRITICAL: ENFORCEMENT CHECKLIST
    1. Before submitting ANY Swift code, verify:
        1. [ ] Swift 6 language mode (minimum Swift 5.9) and project settings are explicit
        2. [ ] Format and lint pass (SwiftFormat + SwiftLint or project equivalents)
        3. [ ] `xcodebuild test` passes for affected schemes/targets
        4. [ ] ALL code is in types (struct, class, enum, actor) — no loose functions
        5. [ ] No `print()` in shipped/submitted code (use `os.Logger`)
        6. [ ] No force unwrap (`!`), `try!`, or `as!` in production code
        7. [ ] No `Any`, `AnyObject`, or `[String: Any]` in domain code
        8. [ ] No comments or documentation comments in code (code is self-documenting)
        9. [ ] All data structures use proper structs with validation (Swift's Pydantic)
        10. [ ] Value objects are immutable (all `let` properties)
        11. [ ] External data mapped to domain types at boundaries (Codable DTOs do not leak)
        12. [ ] UI mutations happen on the main actor (`@MainActor`)
        13. [ ] Shared mutable state is isolated (actor or proven thread confinement)
        14. [ ] All types crossing concurrency boundaries are `Sendable`
        15. [ ] No global mutable state; no hidden singletons
        16. [ ] Access control is minimal and intentional (`public` surface is small)
        17. [ ] All stored properties are `private` unless justified
        18. [ ] Domain layer is UIKit/AppKit/SwiftUI-free (pure logic)
        19. [ ] Inputs validated at boundaries; errors carry context and debugging hints
        20. [ ] Project-level error hierarchy with base error type
        21. [ ] Exhaustive `switch` for domain enums (no `default` for "shut up compiler")
        22. [ ] Composition over inheritance (inheritance shallow and justified, max 2 levels)
        23. [ ] Dependency injection used for services/clients; components are testable
        24. [ ] File paths and resources use `URL` (not raw strings)
        25. [ ] Sensitive data not stored in `UserDefaults` and not logged
        26. [ ] No blocking work on the main thread (network, decoding, heavy compute)
        27. [ ] No boolean flag arguments in public APIs (use enums or separate methods)
        28. [ ] No deep nesting in core logic (guard clauses used, max 3 levels)
        29. [ ] Methods under 50-100 lines (exception: complex algorithms)
        30. [ ] Single responsibility per type and per method
        31. [ ] Multiple return values use struct, not tuple
        32. [ ] Factory methods use `static func`, not standalone functions
        33. [ ] Command-query separation (methods return OR mutate, not both)
        34. [ ] Computed properties for cheap pure derivations; methods for expensive/effectful operations
        35. [ ] Guard clauses for early exits (use `guard`, not nested `if`)
        36. [ ] Higher-order functions (`map`, `filter`, `reduce`, `compactMap`) over manual loops
        37. [ ] Optional binding (`guard let`, `if let`) — no force unwraps
        38. [ ] String interpolation for all formatting (no manual concatenation)
        39. [ ] `defer` for cleanup (Swift's context manager)
        40. [ ] Defensive copies for reference types crossing class boundaries
        41. [ ] Configuration typed, validated, and immutable at runtime
        42. [ ] No hardcoded user-facing strings; accessibility and Dynamic Type supported
        43. [ ] Method ordering convention followed (init → factory → public → computed → private → extensions)
        44. [ ] Protocols are small, cohesive, and only created when needed (seam, test, boundary)
        45. [ ] Generics used for reusable containers/algorithms with proper constraints
