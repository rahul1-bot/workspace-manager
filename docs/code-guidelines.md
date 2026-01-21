0. PYTHON VERSION AND TOOLING
    1. REQUIRED PYTHON VERSION: 3.14+
        1. All code MUST target Python 3.14 or later
        2. Leverage Python 3.14 features fully
    2. PYTHON 3.14 KEY FEATURES
        1. LAZY ANNOTATIONS (PEP 649): Forward references work natively without string quotes
        2. TYPE_CHECKING BUILT-IN (PEP 781): `TYPE_CHECKING` is a built-in constant
        3. Direct imports work for all type annotations - no special patterns needed
        4. EXAMPLE:
            ```python
            from core.models import Coordinate, Action
            from core.sensors import SensorModel

            class MyClass:
                def __init__(self) -> None:
                    self._sensor: SensorModel = SensorModel()

                def process(self, coord: Coordinate) -> Action:
                    return "stay"
            ```
    3. TOOLING STACK
        1. LINTER/FORMATTER: ruff (Astral) - fastest, replaces Flake8/Black/isort
        2. TYPE CHECKER: pyright (Microsoft) - gold standard for conformance
        3. PACKAGE MANAGER: uv (Astral) - fastest Python package manager
    4. PYC COMMAND
        1. Use `pyc <file.py>` or `pyc <directory>` to run linting and type checking
        2. pyc runs both ruff (linting) and pyright (type checking) in strict mode
        3. ALWAYS run pyc before committing code
        4. Fix ALL errors before committing

1. WARNING: PYTHON STANDARDS - ABSOLUTE COMPLIANCE REQUIRED
    1. FILE STRUCTURE
        1. Use direct imports for all types (Python 3.14 lazy annotations handle forward references)
        2. ALL code MUST be in classes
        3. Exception: Callbacks, hooks, and pure utility functions may be standalone if architecturally appropriate
        4. NEVER use module-level constants - use class properties instead
        5. All code MUST follow proper OOP design with composition over inheritance
        6. MUST have `if __name__ == '__main__':` block (NOT generic `def main()`)
        7. CORRECT FILE STRUCTURE EXAMPLE:
            ```python
            import sys
            from pathlib import Path

            from pydantic import BaseModel, field_validator

            class ApplicationCore:
                def run(self) -> None:
                    processor: DataProcessor = DataProcessor()
                    result: ProcessingResult = processor.process_data()
                    print(result.summary)

            if __name__ == '__main__':
                app: ApplicationCore = ApplicationCore()
                app.run()
            ```
    2. CLASS DESIGN
        1. Prefer composition over inheritance
        2. Keep inheritance shallow (max 2 levels)
        3. Use composition for complex behavior
        4. Place related classes in the same file
        5. Follow SOLID principles, especially Single Responsibility
        6. Classes should be cohesive - all methods should work with the same data
        7. Avoid god classes that do everything
        8. Keep classes under 200 lines unless absolutely necessary
        9. Prefer many small classes over few large ones
        10. FLAT > NESTED: Prefer flat composition over deep inheritance chains
        11. Use concrete classes - only add abstractions when you have multiple implementations that need to be swappable
        12. COMPOSITION EXAMPLE:
            ```python
            from pydantic import BaseModel, ConfigDict

            class AttentionBlock:
                def forward(self, x: torch.Tensor) -> torch.Tensor:
                    pass

            class FFNBlock:
                def forward(self, x: torch.Tensor) -> torch.Tensor:
                    pass

            class TransformerLayer:
                def __init__(self) -> None:
                    self._attention: AttentionBlock = AttentionBlock()
                    self._ffn: FFNBlock = FFNBlock()

                def forward(self, x: torch.Tensor) -> torch.Tensor:
                    x = self._attention.forward(x)
                    x = self._ffn.forward(x)
                    return x
            ```
    3. DATA MODELING WITH PYDANTIC (EXTREMELY IMPORTANT)
        1. Use Pydantic `BaseModel` (NOT @dataclass) for all data structures
        2. Pydantic provides runtime type validation - crashes immediately on type errors
        3. Use `model_config = ConfigDict(frozen=True)` for immutable data (value objects)
        4. Model data hierarchies with proper composition
        5. Create clear boundaries between data and behavior
        6. NEVER use plain dicts/tuples where a proper Pydantic model would work
        7. Type all fields in models
        8. Use `Field()` for default values and validation
        9. Use `@field_validator` for field-level validation
        10. VALUE OBJECTS vs ENTITIES:
            1. Value Objects: Identity by value, immutable, use `frozen=True`
            2. Entities: Identity by ID, mutable, don't use frozen
            3. EXAMPLE:
                ```python
                from pydantic import BaseModel, ConfigDict

                class Point2D(BaseModel):
                    x: float
                    y: float
                    model_config = ConfigDict(frozen=True)

                class Experiment(BaseModel):
                    id: str
                    status: str
                    results: list[float]
                ```
        11. PYDANTIC vs TYPEDDICT - CRUCIAL DISTINCTION
        12. Use Pydantic `BaseModel` for DOMAIN OBJECTS (objects you control and can add behavior to):
            ```python
            from pydantic import BaseModel, ConfigDict, field_validator
            import numpy as np

            class BayerPattern(BaseModel):
                pattern: str
                offset_x: int
                offset_y: int
                model_config = ConfigDict(frozen=True)

                @field_validator('pattern')
                @classmethod
                def validate_pattern(cls, v: str) -> str:
                    if v not in {'RGGB', 'GRBG', 'GBRG', 'BGGR'}:
                        raise ValueError(f"Invalid pattern: {v}")
                    return v

                @field_validator('offset_x', 'offset_y')
                @classmethod
                def validate_offset(cls, v: int) -> int:
                    if v not in (0, 1):
                        raise ValueError(f"Offset must be 0 or 1, got {v}")
                    return v

                def extract_channel_mask(self, image_shape: tuple[int, int], channel: int) -> np.ndarray:
                    pass
            ```
        13. Use `TypedDict` for EXTERNAL DATA (dicts you don't control but need typing):
            ```python
            from typing import TypedDict

            class APIResponseDict(TypedDict):
                status: str
                data: dict[str, Any]
                timestamp: int

            class ConfigFileDict(TypedDict):
                host: str
                port: int
                debug: bool

            response: APIResponseDict = json.loads(api_response)
            config: ConfigFileDict = yaml.load(config_file)
            ```
        14. NEVER use TypedDict when you can use Pydantic BaseModel
        15. Key Trade-offs:
            1. TypedDict: Dict convenience + type hints, but NO runtime validation
            2. Pydantic: Runtime validation, better error messages, proper architecture
        16. When to use TypedDict:
            1. API responses (JSON you don't control)
            2. Configuration files (loaded as dict)
            3. Database rows (ORM returns dict format)
            4. Legacy interop (existing code expects dict)
        17. When to use Pydantic BaseModel (99% of cases):
            1. Domain objects (your business logic)
            2. Data that needs validation
            3. Objects that can have behavior
            4. Anything you architect yourself
        18. PYDANTIC INTELLIGENCE PRINCIPLES
            1. The Core Problem: Most models are just DUMB WRAPPERS without validation
            2. When to Make Models Smart:
                1. Has validation rules? → MUST be smart
                2. Has business logic? → MUST be smart
                3. Has domain behavior? → MUST be smart
                4. Just holds data with no rules? → Can stay simple
                5. Used in collections/comparisons? → Add appropriate dunders
            3. Domain Logic MUST Live in Domain Objects:
                1. Validation in `@field_validator`
                2. Business rules as methods
                3. Invariants enforced at creation
                4. Behavior related to the data domain
            4. Dunder Method Guidelines - USE WHEN ARCHITECTURALLY APPROPRIATE:
                1. `__str__`/`__repr__`: ALWAYS implement for debugging
                2. `__eq__`/`__hash__`: When used in sets/dicts or need comparison
                3. `__call__`: ONLY if "calling" the object has ONE OBVIOUS meaning
                4. `__getitem__`/`__setitem__`: ONLY for container-like objects
                5. `__len__`/`__contains__`: ONLY for collection-like objects
                6. `__iter__`/`__next__`: ONLY for iterable objects
                7. `__bool__`: When object has natural truthiness
                8. `__lt__`/`__le__`/`__gt__`/`__ge__`: For natural ordering
                9. DON'T use dunders as gimmicks - they must make ARCHITECTURAL sense!
            5. CRITICAL ARCHITECTURAL QUESTIONS:
                1. What IS this object conceptually?
                2. What operations make INTUITIVE sense?
                3. Then implement appropriate dunders
            6. The Rule: If you can't explain WHY the dunder makes sense in ONE sentence, don't use it!
        19. SMART vs SIMPLE PYDANTIC MODEL EXAMPLES:
            1. SIMPLE - Legitimately simple data holder:
                ```python
                from pydantic import BaseModel, ConfigDict

                class Point2D(BaseModel):
                    x: float
                    y: float
                    model_config = ConfigDict(frozen=True)

                    def distance_to(self, other: Point2D) -> float:
                        dx: float = self.x - other.x
                        dy: float = self.y - other.y
                        return (dx ** 2 + dy ** 2) ** 0.5
                ```
            2. SMART - Full validation and domain logic:
                ```python
                from pydantic import BaseModel, ConfigDict, field_validator
                import numpy as np

                class BayerPattern(BaseModel):
                    pattern: str
                    offset_x: int
                    offset_y: int
                    confidence: float
                    model_config = ConfigDict(frozen=True)

                    @field_validator('pattern')
                    @classmethod
                    def validate_pattern(cls, v: str) -> str:
                        valid_patterns: set[str] = {'RGGB', 'GRBG', 'GBRG', 'BGGR'}
                        if v not in valid_patterns:
                            raise ValueError(f"Invalid pattern: {v}. Must be one of {valid_patterns}")
                        return v

                    @field_validator('offset_x', 'offset_y')
                    @classmethod
                    def validate_offset(cls, v: int) -> int:
                        if v not in (0, 1):
                            raise ValueError(f"Offset must be 0 or 1, got {v}")
                        return v

                    @field_validator('confidence')
                    @classmethod
                    def validate_confidence(cls, v: float) -> float:
                        if not 0.0 <= v <= 1.0:
                            raise ValueError(f"Confidence must be in [0, 1], got {v}")
                        return v

                    def __str__(self) -> str:
                        return f"{self.pattern}@({self.offset_x},{self.offset_y})"

                    @property
                    def pattern_matrix(self) -> np.ndarray:
                        patterns: dict[str, np.ndarray] = {
                            'RGGB': np.array([[0, 1], [1, 2]]),
                            'GRBG': np.array([[1, 0], [2, 1]]),
                            'GBRG': np.array([[1, 2], [0, 1]]),
                            'BGGR': np.array([[2, 1], [1, 0]])
                        }
                        return patterns[self.pattern]

                    def extract_channel_mask(self, image_shape: tuple[int, int], channel: int) -> np.ndarray:
                        height, width = image_shape
                        mask: np.ndarray = np.zeros((height, width), dtype=bool)
                        pattern_matrix: np.ndarray = self.pattern_matrix

                        for y in range(height):
                            for x in range(width):
                                pattern_y: int = (y - self.offset_y) % 2
                                pattern_x: int = (x - self.offset_x) % 2
                                if pattern_matrix[pattern_y, pattern_x] == channel:
                                    mask[y, x] = True

                        return mask
                ```
    4. MATCH/CASE PATTERN MATCHING
        1. Modern Python's most powerful feature - USE IT!
        2. WHEN TO USE MATCH/CASE:
            1. Complex branching logic - replacing ugly if/elif chains
            2. Type-based dispatch - different behavior for different types
            3. Value extraction - extracting values while matching patterns
            4. Exhaustive checking - ensuring all cases are covered
        3. WHEN NOT TO USE MATCH/CASE:
            1. Simple 2-case if/else - overkill for basic conditions
            2. Boolean logic - if/elif with `and`/`or` is clearer
            3. Range checks - `if value < 10:` is clearer than match
            4. Single pattern - just use if statement
        4. BASIC PATTERN MATCHING:
            1. BAD - Ugly if/elif chains:
                ```python
                def get_pattern_matrix(self, pattern: str) -> np.ndarray:
                    if pattern == 'RGGB':
                        return np.array([[0, 1], [1, 2]])
                    elif pattern == 'GRBG':
                        return np.array([[1, 0], [2, 1]])
                    elif pattern == 'GBRG':
                        return np.array([[1, 2], [0, 1]])
                    elif pattern == 'BGGR':
                        return np.array([[2, 1], [1, 0]])
                    else:
                        raise ValueError(f"Unknown pattern: {pattern}")
                ```
            2. GOOD - Clean match/case:
                ```python
                def get_pattern_matrix(self, pattern: str) -> np.ndarray:
                    match pattern:
                        case 'RGGB':
                            return np.array([[0, 1], [1, 2]])
                        case 'GRBG':
                            return np.array([[1, 0], [2, 1]])
                        case 'GBRG':
                            return np.array([[1, 2], [0, 1]])
                        case 'BGGR':
                            return np.array([[2, 1], [1, 0]])
                        case _:
                            raise ValueError(f"Unknown pattern: {pattern}")
                ```
    5. TYPE ANNOTATIONS (CRITICAL REQUIREMENT)
        1. EVERY SINGLE VARIABLE must have a type annotation
        2. This includes local variables, loop variables, list comprehensions, etc.
        3. Use modern syntax: `list[str]`, NOT `List[str]`
        4. Use pipe operator for unions: `str | None`, NOT `Optional[str]` or `Union[str, None]`
        5. Every function/method MUST have parameter and return types
        6. `__init__` methods MUST have `-> None` return type
        7. ALL methods returning nothing MUST have `-> None` annotation
        8. Type all lambda functions
        9. Type all comprehensions
        10. NEVER use `Any` and NEVER import it; derive precise types from the actual parameter/return structures instead
        11. Use Literal types instead of Enum for categorical values:
            ```python
            from typing import Literal

            BayerPatternType = Literal["RGGB", "GRBG", "GBRG", "BGGR"]

            def process_pattern(pattern: BayerPatternType) -> None:
                match pattern:
                    case "RGGB":
                        pass
            ```
        12. NEVER import these from typing:
            1. ❌ List - use `list` instead
            2. ❌ Dict - use `dict` instead
            3. ❌ Tuple - use `tuple` instead
            4. ❌ Set - use `set` instead
            5. ❌ Optional - use `| None` instead
            6. ❌ Union - use `|` instead
        13. DO import these from typing:
            1. ✓ TypeVar (for generics)
            2. ✓ Callable (for function types)
            3. ✓ Generic (for generic classes)
            4. ✓ ClassVar (for class variables)
            5. ✓ Final (for constants)
            6. ✓ Literal (for literal types)
            7. ✓ TypeAlias (for type aliases)
            8. ✓ cast (for type casting)
            9. ✓ overload (for overloaded methods)
            10. NOTE: TYPE_CHECKING is a built-in in Python 3.14 (no import needed, but rarely required due to lazy annotations)
        14. COMPREHENSIVE TYPE ANNOTATION EXAMPLE:
        ❌ **BAD - Missing types everywhere:**
        ```python
        class Calculator:
            def __init__(self):
                self.history = []

            def add(self, a, b):
                result = a + b
                self.history.append(result)
                return result

            def get_history(self):
                return [x for x in self.history if x > 0]
        ```
        ✓ **GOOD - Everything typed:**
        ```python
        from typing import TypeVar, Generic
        T = TypeVar('T', bound=float)

        class Calculator(Generic[T]):
            def __init__(self) -> None:
                self._history: list[T] = []

            def add(self, a: T, b: T) -> T:
                result: T = a + b
                self._history.append(result)
                return result

            def get_positive_history(self) -> list[T]:
                return [value for value in self._history if value > 0]

            def process_items(self, items: list[T]) -> dict[str, T]:
                results: dict[str, T] = {}
                for index, item in enumerate(items):
                    key: str = f"item_{index}"
                    processed: T = self.add(item, item)
                    results[key] = processed
                return results
        ```
    6. METHOD DESIGN
        1. Methods MUST have a SINGLE RESPONSIBILITY
        2. AVOID methods longer than 50-100 lines
        3. EXCEPTION: Mathematical algorithms or complex ML architectures may exceed 100 lines if they represent a single conceptual operation
        4. Break complex logic into smaller, well-named helper methods
        5. Helper methods MUST be prefixed with underscore `_`
        6. If a method does more than one thing, split it
        7. Methods should be named with verb phrases
        8. Method names should describe EXACTLY what they do
        9. Use guard clauses for early returns (invert conditions)
        10. Avoid deep nesting (max 3 levels)
        11. Extract complex logic into helper methods
        12. Merge related conditionals when readable
        13. Each method should have clear input/output contract
        14. PROPERTY vs METHOD:
            1. Use `@property` for cheap, pure computations (no side effects)
            2. Use methods for expensive operations or side effects
            3. EXAMPLE:
                ```python
                class ImageProcessor:
                    @property
                    def image_dimensions(self) -> tuple[int, int]:
                        return self._image.shape[:2]

                    def compute_histogram(self) -> np.ndarray:
                        return np.histogram(self._image, bins=256)
                ```
        15. COMMAND-QUERY SEPARATION:
            1. Methods should either return a value (query) OR have side effects (command), not both
            2. EXAMPLE:
                ```python
                class Stack:
                    def top(self) -> int:
                        return self._items[-1]

                    def pop(self) -> None:
                        self._items.pop()
                ```
        16. @classmethod vs @staticmethod vs instance method (CRITICAL FOR 2026 PYTHON):
            1. Use instance methods as default (operates on self)
            2. Use @classmethod for factories and alternative constructors (modern pattern)
            3. AVOID @staticmethod - it's a code smell suggesting Single Responsibility violation
            4. If you need @staticmethod, create a separate class instead
            5. @staticmethod suggests the function doesn't belong in that class
            6. EXAMPLE:
            ✓ **GOOD - Factory pattern with @classmethod:**
            ```python
            from pydantic import BaseModel, ConfigDict
            from pathlib import Path
            import torch

            class Model(BaseModel):
                weights: dict[str, torch.Tensor]
                config: ModelConfig
                model_config = ConfigDict(frozen=True)

                @classmethod
                def from_pretrained(cls, path: Path) -> Model:
                    weights = torch.load(path / "weights.pt")
                    config = ModelConfig.load(path / "config.json")
                    return cls(weights=weights, config=config)

                @classmethod
                def from_config(cls, config: ModelConfig) -> Model:
                    weights = cls._initialize_weights(config)
                    return cls(weights=weights, config=config)

                @classmethod
                def _initialize_weights(cls, config: ModelConfig) -> dict[str, torch.Tensor]:
                    pass
            ```
            ❌ **BAD - @staticmethod code smell:**
            ```python
            class ImageProcessor:
                def process(self, image: np.ndarray) -> np.ndarray:
                    if not self._validate_dimensions(image):
                        raise ValueError("Invalid dimensions")
                    return self._transform(image)

                @staticmethod
                def _validate_dimensions(image: np.ndarray) -> bool:
                    return image.ndim == 3 and image.shape[2] == 3
            ```
            ✓ **GOOD - Separate validator class (Single Responsibility):**
            ```python
            class ImageValidator:
                def validate_dimensions(self, image: np.ndarray) -> None:
                    if image.ndim != 3:
                        raise ValueError(f"Expected 3D image, got {image.ndim}D")
                    if image.shape[2] != 3:
                        raise ValueError(f"Expected 3 channels, got {image.shape[2]}")

            class ImageProcessor:
                def __init__(self) -> None:
                    self._validator: ImageValidator = ImageValidator()

                def process(self, image: np.ndarray) -> np.ndarray:
                    self._validator.validate_dimensions(image)
                    return self._transform(image)
            ```
        17. EXAMPLE:
        ❌ **BAD - Method doing too many things:**
        ```python
        class UserService:
            def process_user(self, user_data: dict[str, Any]) -> str:
                if 'email' not in user_data:
                    return "Error: No email"

                email = user_data['email']
                if '@' not in email:
                    return "Error: Invalid email"

                name = user_data.get('name', 'Unknown')
                age = user_data.get('age', 0)

                if age < 18:
                    return "Error: Too young"

                user_id = hash(email) % 1000000

                print(f"Creating user: {name}")
                print(f"Email: {email}")
                print(f"Age: {age}")
                print(f"ID: {user_id}")

                return f"User {user_id} created"
        ```
        ✓ **GOOD - Single responsibility methods:**
        ```python
        from pydantic import BaseModel, ConfigDict

        class UserData(BaseModel):
            email: str
            name: str
            age: int
            model_config = ConfigDict(frozen=True)

        class UserValidator:
            def validate(self, user_data: UserData) -> ValidationResult:
                email_result: ValidationResult = self._validate_email(user_data.email)
                if not email_result.is_valid:
                    return email_result

                age_result: ValidationResult = self._validate_age(user_data.age)
                if not age_result.is_valid:
                    return age_result

                return ValidationResult(is_valid=True, message="Valid")

            def _validate_email(self, email: str) -> ValidationResult:
                if '@' not in email:
                    return ValidationResult(is_valid=False, message=f"Invalid email format: {email}")
                return ValidationResult(is_valid=True, message="Email valid")

            def _validate_age(self, age: int) -> ValidationResult:
                if age < 18:
                    return ValidationResult(is_valid=False, message=f"User must be 18 or older, got {age}")
                return ValidationResult(is_valid=True, message="Age valid")


        class UserService:
            def __init__(self) -> None:
                self._validator: UserValidator = UserValidator()
                self._id_generator: UserIdGenerator = UserIdGenerator()

            def create_user(self, user_data: UserData) -> UserCreationResult:
                validation_result: ValidationResult = self._validator.validate(user_data)
                if not validation_result.is_valid:
                    return UserCreationResult(success=False, message=validation_result.message)

                user_id: int = self._id_generator.generate_id(user_data.email)
                self._log_user_creation(user_data, user_id)

                return UserCreationResult(success=True, user_id=user_id, message="User created")

            def _log_user_creation(self, user_data: UserData, user_id: int) -> None:
                logger: UserLogger = UserLogger()
                logger.log_creation(user_data, user_id)
        ```
    7. NEVER NEST CODE
        1. Maximum 3 levels of nesting
        2. Use GUARD CLAUSES (invert conditions) for early returns
        3. Use EXTRACTION to pull complex logic into helper methods
        4. Merge related conditionals when possible
        5. GUARD CLAUSES EXAMPLE:
        ❌ **BAD - Nested hell:**
        ```python
        def process_image(self, image: np.ndarray) -> np.ndarray:
            if image is not None:
                if image.shape[0] > 0:
                    if image.dtype == np.float32:
                        if not np.isnan(image).any():
                            result = self._transform(image)
                            return result
                        else:
                            raise ValueError("NaN in image")
                    else:
                        raise ValueError("Wrong dtype")
                else:
                    raise ValueError("Empty image")
            else:
                raise ValueError("Image is None")
        ```
        ✓ **GOOD - Flat with guards:**
        ```python
        def process_image(self, image: np.ndarray) -> np.ndarray:
            if image is None:
                raise ValueError("Image cannot be None")
            if image.shape[0] == 0:
                raise ValueError(f"Image cannot be empty, got shape {image.shape}")
            if image.dtype != np.float32:
                raise ValueError(f"Expected float32, got {image.dtype}")
            if np.isnan(image).any():
                raise ValueError("Image contains NaN values. Check preprocessing step.")

            return self._transform(image)
        ```
        6. EXTRACTION EXAMPLE:
        ❌ **BAD - 200 line method:**
        ```python
        def train_epoch(self):
            pass
        ```
        ✓ **GOOD - Extracted:**
        ```python
        def train_epoch(self) -> None:
            batch: Batch = self._load_batch()
            output: torch.Tensor = self._forward_pass(batch)
            loss: torch.Tensor = self._compute_loss(output, batch.target)
            self._optimize(loss)
        ```
        7. MERGE CONDITIONALS:
        ❌ **BAD:**
        ```python
        if x > 0:
            if x < 100:
                process(x)
        ```
        ✓ **GOOD:**
        ```python
        if 0 < x < 100:
            process(x)
        ```
    8. VARIABLE NAMING
        1. NEVER use ALL_CAPS variables - EVER
        2. DO NOT CREATE `ENUM` - use Literal types instead
        3. Use snake_case for all variables and methods
        4. Be descriptive but concise
        5. Avoid abbreviations unless universally understood
        6. NO SINGLE LETTER VARIABLES except simple loop indices
        7. Variables should be named with noun phrases
        8. Boolean variables should be prefaced with is_, has_, should_, etc.
        9. Collections should be plural
        10. Avoid mental mapping (don't make readers translate names)
        11. EXAMPLE:
        ❌ **BAD naming:**
        ```python
        class DataProc:
            MAX_ITEMS = 100

            def proc(self, d):
                r = []
                for i in d:
                    if self.chk(i):
                        r.append(i)
                return r

            def chk(self, v):
                return v > 0
        ```
        ✓ **GOOD naming:**
        ```python
        class DataProcessor:
            @property
            def maximum_items(self) -> int:
                return 100

            def process_values(self, raw_values: list[float]) -> list[float]:
                valid_values: list[float] = []
                for value in raw_values:
                    if self._is_valid_value(value):
                        valid_values.append(value)
                return valid_values

            def _is_valid_value(self, value: float) -> bool:
                return value > 0
        ```
    9. NO COMMENTS WHATSOEVER
        0. WARNING: NO COMMENTS: WARNING
        1. NO DOCSTRINGS - never use triple quotes (`"""`)
        2. NO LINE COMMENTS - never use hash (`#`)
        3. NO MULTILINE COMMENTS - never
        4. NO TODO COMMENTS - never
        5. Let the code be self-documenting through proper naming
        6. If you feel the need to comment, refactor the code instead
        7. Use method and variable names that explain intent
        8. Break complex logic into well-named methods
    10. STRING FORMATTING AND RESOURCES
        1. ALWAYS use f-strings for string formatting (most readable and performant)
        2. NEVER use .format() or % formatting
        3. ALWAYS use context managers for resource management
        4. EXAMPLE:
        ❌ **BAD:**
        ```python
        name = "Rahul"
        age = 23
        message = "{} is {} years old".format(name, age)

        file = open('data.txt')
        data = file.read()
        file.close()
        ```
        ✓ **GOOD:**
        ```python
        name: str = "Rahul"
        age: int = 23
        message: str = f"{name} is {age} years old"

        with open('data.txt') as file:
            data: str = file.read()
        ```
    11. NO FLAG ARGUMENTS
        1. NEVER use boolean flag arguments
        2. Use separate methods or configuration objects
        3. EXAMPLE:
        ❌ **BAD:**
        ```python
        def process(self, data: np.ndarray, normalize: bool = False, augment: bool = False) -> np.ndarray:
            if normalize:
                data = self._normalize(data)
            if augment:
                data = self._augment(data)
            return data
        ```
        ✓ **GOOD:**
        ```python
        from pydantic import BaseModel

        class ProcessingConfig(BaseModel):
            normalize: bool
            augment: bool

        def process(self, data: np.ndarray, config: ProcessingConfig) -> np.ndarray:
            if config.normalize:
                data = self._normalize(data)
            if config.augment:
                data = self._augment(data)
            return data
        ```
    12. PATH HANDLING (CRITICAL FOR AI RESEARCH)
        1. ALWAYS use `pathlib.Path` for file and directory paths, NEVER strings
        2. Path objects are safer, cross-platform, and more expressive
        3. Use Path methods: `.exists()`, `.mkdir()`, `.glob()`, `.read_text()`, etc.
        4. Type all path parameters as `Path`, not `str`
        5. Convert string paths to Path immediately at boundaries
        6. EXAMPLE:
        ❌ **BAD - String paths:**
        ```python
        import os

        def load_data(data_dir: str) -> Data:
            if not os.path.exists(data_dir):
                os.makedirs(data_dir)

            config_path = os.path.join(data_dir, "config.json")
            with open(config_path) as f:
                config = json.load(f)

            return Data(config=config)
        ```
        ✓ **GOOD - pathlib.Path:**
        ```python
        from pathlib import Path

        def load_data(data_dir: Path) -> Data:
            if not data_dir.exists():
                data_dir.mkdir(parents=True, exist_ok=True)

            config_path: Path = data_dir / "config.json"
            config: dict[str, Any] = json.loads(config_path.read_text())

            return Data(config=config)
        ```
        6. Path operations are method calls, not function calls:
            ```python
            from pathlib import Path

            class DataLoader:
                def __init__(self, root: Path) -> None:
                    self._root: Path = root
                    self._data_dir: Path = root / "data"
                    self._model_dir: Path = root / "models"

                def load_dataset(self, name: str) -> Dataset:
                    dataset_path: Path = self._data_dir / f"{name}.pkl"

                    if not dataset_path.exists():
                        raise FileNotFoundError(
                            f"Dataset not found: {dataset_path}. "
                            f"Available: {list(self._data_dir.glob('*.pkl'))}"
                        )

                    return Dataset.load(dataset_path)
            ```
    13. MULTIPLE RETURN VALUES
        1. For multiple return values, ALWAYS use Pydantic model, NEVER tuple
        2. Tuple unpacking is fragile and loses type safety
        3. Pydantic models are self-documenting and validated
        4. EXAMPLE:
        ❌ **BAD - Tuple unpacking (fragile):**
        ```python
        def compute_stats(data: np.ndarray) -> tuple[float, float, float]:
            return data.mean(), data.std(), np.median(data)

        mean, std, median = compute_stats(data)
        ```
        ✓ **GOOD - Pydantic model (self-documenting):**
        ```python
        from pydantic import BaseModel, ConfigDict

        class Statistics(BaseModel):
            mean: float
            std: float
            median: float
            model_config = ConfigDict(frozen=True)

        def compute_stats(data: np.ndarray) -> Statistics:
            return Statistics(
                mean=float(data.mean()),
                std=float(data.std()),
                median=float(np.median(data))
            )

        stats: Statistics = compute_stats(data)
        print(f"Mean: {stats.mean}, Std: {stats.std}")
        ```
        5. Benefits of Pydantic over tuples:
            1. Self-documenting - field names make intent clear
            2. Type-safe - can't accidentally swap order
            3. Validated - Pydantic validates types at runtime
            4. Extensible - can add fields without breaking existing code
            5. IDE support - autocomplete on field names
    14. CLEAN CODE PRINCIPLES
        1. Classes and methods should be small and focused
        2. Code should be DRY (Don't Repeat Yourself)
        3. Methods should do one thing and do it well
        4. Proper separation of concerns
        5. Proper encapsulation of behavior
        6. Avoid deep nesting of control structures
        7. Early returns for guard clauses
        8. Clear and consistent error handling
        9. Fail fast - validate inputs early with assertions
        10. Make the happy path obvious
        11. Handle edge cases explicitly
1. PROPER CODE ARCHITECTURE PRINCIPLES
    1. SOLID PRINCIPLES
        1. Single Responsibility: Classes should have only one reason to change
        2. Open/Closed: Open for extension, closed for modification
        3. Liskov Substitution: Subtypes must be substitutable for their base types
        4. Interface Segregation: Many small interfaces are better than one large one
        5. Dependency Inversion: Depend on abstractions, not concretions
        6. EXAMPLE:
        **Single Responsibility:**
        ```python
        ❌ BAD:
        class User:
            def save_to_database(self) -> None: ...
            def send_email(self) -> None: ...
            def validate_password(self) -> None: ...

        ✓ GOOD:
        class User:
            pass

        class UserRepository:
            def save(self, user: User) -> None: ...

        class EmailService:
            def send_welcome_email(self, user: User) -> None: ...

        class PasswordValidator:
            def validate(self, password: str) -> bool: ...
        ```
    2. LAYERED ARCHITECTURE
        1. Separate concerns into layers: Data, Domain, Service
        2. Data layer: Pydantic models, database access
        3. Domain layer: Business logic, domain rules
        4. Service layer: Orchestration, coordination
        5. Dependencies flow inward: outer layers depend on inner layers
        6. EXAMPLE:
        ```python
        class ImageData(BaseModel):
            pixels: np.ndarray
            metadata: dict[str, Any]

        class ImageProcessor:
            def denoise(self, image: ImageData) -> ImageData:
                pass

        class ImageService:
            def __init__(self, processor: ImageProcessor) -> None:
                self._processor: ImageProcessor = processor

            def process_pipeline(self, image: ImageData) -> ImageData:
                return self._processor.denoise(image)
        ```
    3. COMPOSITION OVER INHERITANCE
        1. Prefer composition for HAS-A relationships
        2. Keep inheritance shallow (max 2 levels)
        3. Use composition for complex behavior
        4. Create clear boundaries between components
        5. Use dependency injection for flexible composition
        6. EXAMPLE:
        ```python
        from pydantic import BaseModel, ConfigDict

        class Engine(BaseModel):
            horsepower: int
            fuel_type: str
            model_config = ConfigDict(frozen=True)

            def start(self) -> None:
                print(f"Starting {self.horsepower}hp {self.fuel_type} engine")

        class Transmission(BaseModel):
            gear_count: int
            transmission_type: str
            model_config = ConfigDict(frozen=True)

            def shift(self, gear: int) -> None:
                if 1 <= gear <= self.gear_count:
                    print(f"Shifting to gear {gear}")

        class Car:
            def __init__(self, engine: Engine, transmission: Transmission) -> None:
                self._engine: Engine = engine
                self._transmission: Transmission = transmission

            def start_and_drive(self) -> None:
                self._engine.start()
                self._transmission.shift(1)
        ```
2. ADDITIONAL CRITICAL STANDARDS
    1. ERROR HANDLING AND FAIL FAST
        1. Use specific exception types, never bare `except:`
        2. Create custom exceptions for domain-specific errors
        3. Fail fast with clear error messages that include context
        4. Use assertions for invariants and post-conditions
        5. Error messages MUST include: what went wrong, expected value, received value, debugging hint
        6. Always type exception variables
        7. Clean up resources in finally blocks or use context managers
        8. ERROR HANDLING EXAMPLES:
        ```python
        class ValidationError(Exception):
            pass

        class InsufficientFundsError(Exception):
            def __init__(self, balance: float, amount: float) -> None:
                super().__init__(
                    f"Insufficient funds: balance={balance:.2f}, "
                    f"attempted withdrawal={amount:.2f}. "
                    f"Check account balance before withdrawal."
                )
                self.balance: float = balance
                self.amount: float = amount

        class BankAccount:
            def __init__(self, initial_balance: float) -> None:
                if initial_balance < 0:
                    raise ValidationError(
                        f"Initial balance cannot be negative, got {initial_balance:.2f}"
                    )
                self._balance: float = initial_balance

            def withdraw(self, amount: float) -> None:
                if amount <= 0:
                    raise ValidationError(
                        f"Withdrawal amount must be positive, got {amount:.2f}"
                    )

                if amount > self._balance:
                    raise InsufficientFundsError(self._balance, amount)

                self._balance -= amount

                assert self._balance >= 0, f"Balance went negative: {self._balance}"
        ```
        9. ASSERTIONS FOR INVARIANTS:
        ```python
        class MultiHeadAttention:
            def forward(self, x: torch.Tensor) -> torch.Tensor:
                assert x.dim() == 3, f"Expected 3D tensor, got {x.dim()}D with shape {x.shape}"
                assert not torch.isnan(x).any(), "Input contains NaN values. Check previous layer."

                output: torch.Tensor = self._compute_attention(x)

                assert output.shape == x.shape, (
                    f"Shape mismatch: expected {x.shape}, got {output.shape}. "
                    f"Check attention projection dimensions."
                )

                return output
        ```
    2. TESTING WITH HEREDOC AND ASSERTIONS
        1. Use heredoc for quick sanity checks (no file pollution)
        2. Use assertions in code for invariants and post-conditions
        3. Fail fast - crash immediately on invalid state
        4. No comprehensive unit test files for research code
        5. HEREDOC TESTING PATTERN:
        ```bash
        python3 <<'EOF'
        from model import MultiHeadAttention
        import torch

        attention = MultiHeadAttention()
        x = torch.randn(2, 10, 512)
        output = attention.forward(x)

        assert output.shape == x.shape, f"Shape mismatch: {output.shape} != {x.shape}"
        assert not torch.isnan(output).any(), "Output contains NaN"

        print(f"✓ Shape: {output.shape}")
        print(f"✓ No NaN values")
        print("✓ Forward pass successful")
        EOF
        ```
    3. PERFORMANCE CONSIDERATIONS
        1. Use generators for large datasets
        2. Cache expensive computations with `@lru_cache`
        3. Use appropriate data structures (set for membership, deque for queues)
        4. Profile before optimizing
        5. Prefer list comprehensions over loops for simple transformations
        6. PERFORMANCE EXAMPLES:
        ```python
        from functools import lru_cache
        from collections import deque
        from typing import Iterator

        class DataProcessor:
            def __init__(self) -> None:
                self._cache: dict[str, Any] = {}
                self._queue: deque[Task] = deque()

            def process_large_file(self, filepath: Path) -> Iterator[ProcessedLine]:
                with open(filepath, 'r') as file:
                    for line_number, line in enumerate(file, 1):
                        if self._should_process_line(line):
                            yield ProcessedLine(line_number, line.strip())

            @lru_cache(maxsize=128)
            def _calculate_expensive_metric(self, value: str) -> float:
                return sum(ord(char) for char in value) / len(value)

            def _should_process_line(self, line: str) -> bool:
                return line.strip() and not line.startswith('#')
        ```
    4. SECURITY CONSIDERATIONS
        1. Never store sensitive data in plain text
        2. Validate all inputs with Pydantic
        3. Use parameterized queries for databases
        4. Implement proper authentication and authorization
        5. Log security events
        6. Use secure random for security-critical randomness
        7. SECURITY EXAMPLES:
        ```python
        import secrets
        import hashlib
        from pydantic import BaseModel, ConfigDict

        class HashedPassword(BaseModel):
            hash: str
            salt: str
            model_config = ConfigDict(frozen=True)

            @classmethod
            def from_plain_password(cls, password: str) -> HashedPassword:
                salt: str = secrets.token_hex(32)
                hash_value: str = cls._hash_with_salt(password, salt)
                return cls(hash=hash_value, salt=salt)

            @staticmethod
            def _hash_with_salt(password: str, salt: str) -> str:
                combined: bytes = (password + salt).encode('utf-8')
                return hashlib.sha256(combined).hexdigest()

            def verify(self, password: str) -> bool:
                expected_hash: str = self._hash_with_salt(password, self.salt)
                return secrets.compare_digest(self.hash, expected_hash)
        ```
    5. DEPENDENCY INJECTION
        1. Constructor injection is preferred
        2. Keep dependencies explicit
        3. Use factories for complex construction
        4. DEPENDENCY INJECTION EXAMPLE:
        ```python
        class EmailSender:
            def send(self, to: str, subject: str, body: str) -> None:
                pass

        class SmtpEmailSender(EmailSender):
            def __init__(self, host: str, port: int) -> None:
                self._host: str = host
                self._port: int = port

            def send(self, to: str, subject: str, body: str) -> None:
                print(f"Sending email via SMTP to {to}")

        class NotificationService:
            def __init__(self, email_sender: EmailSender) -> None:
                self._email_sender: EmailSender = email_sender

            def notify_user(self, user: User, message: str) -> None:
                self._email_sender.send(
                    to=user.email,
                    subject="Notification",
                    body=message
                )
        ```
    6. CONFIGURATION MANAGEMENT
        1. Use Pydantic models for configuration
        2. Validate configuration on load
        3. Use environment variables for secrets
        4. Provide sensible defaults
        5. Make configuration immutable
        6. CONFIGURATION EXAMPLE:
        ```python
        import os
        from pydantic import BaseModel, ConfigDict, field_validator

        class DatabaseConfig(BaseModel):
            host: str
            port: int
            username: str
            password: str
            database: str
            model_config = ConfigDict(frozen=True)

            @classmethod
            def from_environment(cls) -> DatabaseConfig:
                return cls(
                    host=os.getenv('DB_HOST', 'localhost'),
                    port=int(os.getenv('DB_PORT', '5432')),
                    username=os.getenv('DB_USER', 'postgres'),
                    password=os.getenv('DB_PASSWORD', ''),
                    database=os.getenv('DB_NAME', 'myapp')
                )

            @property
            def connection_string(self) -> str:
                return f"postgresql://{self.username}:{self.password}@{self.host}:{self.port}/{self.database}"

        class AppConfig(BaseModel):
            database: DatabaseConfig
            debug_mode: bool = False
            max_workers: int = 4
            model_config = ConfigDict(frozen=True)

            @field_validator('max_workers')
            @classmethod
            def validate_max_workers(cls, v: int) -> int:
                if v < 1:
                    raise ValueError(f"max_workers must be at least 1, got {v}")
                return v
        ```
3. CRITICAL: ENFORCEMENT CHECKLIST
    1. Before submitting ANY Python code, verify:
        1. [ ] Python 3.14+ targeted (no `from __future__ import annotations`)
        2. [ ] ALL code is in classes (exception: callbacks/hooks if appropriate)
        3. [ ] Every variable has a type annotation
        4. [ ] Every method has return type annotation
        5. [ ] All `__init__` methods have `-> None`
        6. [ ] No comments or docstrings exist
        7. [ ] All data structures use Pydantic `BaseModel`
        8. [ ] No ALL_CAPS variables
        9. [ ] No Enum - use Literal types instead
        10. [ ] Methods are under 50-100 lines (exception: mathematical algorithms)
        11. [ ] Classes follow single responsibility
        12. [ ] Composition over inheritance (max 2 levels)
        13. [ ] No old-style type imports (List, Dict, etc.)
        14. [ ] All helper methods prefixed with `_`
        15. [ ] Proper error handling with contextual messages
        16. [ ] Clean separation of concerns
        17. [ ] No bare `except:` blocks
        18. [ ] Immutable data (frozen=True) for value objects
        19. [ ] Proper use of composition
        20. [ ] Self-documenting code through naming
        21. [ ] Guard clauses for early returns
        22. [ ] No deep nesting (max 3 levels)
        23. [ ] Dependencies injected, not hardcoded
        24. [ ] Configuration properly managed with Pydantic
        25. [ ] Assertions for invariants and post-conditions
        26. [ ] f-strings for all formatting
        27. [ ] Context managers for resources
        28. [ ] No flag arguments
        29. [ ] Use pathlib.Path for all file/directory paths, not strings
        30. [ ] Use @classmethod for factories, avoid @staticmethod
        31. [ ] Multiple return values use Pydantic models, not tuples
        32. [ ] No `Any` imports or annotations; define precise types that reflect actual parameters and return shapes
        33. [ ] Run `pyc` before committing - fix all errors
