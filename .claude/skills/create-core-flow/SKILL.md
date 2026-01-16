---
name: create-core-flow
description: Use this skill when you need to create CoreFlow components to add a new feature or screen.
---

CoreFlow is an architecture designed to abstract iOS application features into units called **CoreFlow**, enabling flexible coupling between features.
It consists of three core components (Core, Screen, Flow) and combines the structural advantages of RIBs with state management patterns from ReactorKit/TCA.

## Quick Start Guide

When creating a new CoreFlow feature, generate the following 3 files:

### File Structure
```
{ModulePath}/
├── {FeatureName}Core.swift    # Business logic & state management
├── {FeatureName}Screen.swift  # UI layer (UIViewController)
└── {FeatureName}Flow.swift    # Composition root & routing
```

### Naming Conventions
| Component | Naming Pattern | Example |
|-----------|---------------|---------|
| Core class | `{FeatureName}Core` | `LoginCore` |
| Screen class | `{FeatureName}Screen` | `LoginScreen` |
| Flow class | `{FeatureName}Flow` | `LoginFlow` |
| Action enum | `{FeatureName}Action` | `LoginAction` |
| State struct | `{FeatureName}State` | `LoginState` |
| Routing protocol | `{FeatureName}Routing` | `LoginRouting` |
| Listener protocol | `{FeatureName}Listener` | `LoginListener` |

### Variant Selection Guide
```
Does this feature need a UI screen?
├── YES → Use Core + Screen + Flow
│         (Standard CoreFlow with full state management)
│
└── NO → Does it need state management?
         ├── YES → Use Core + ScreenLessFlow
         │         (Coordinator with state but no UI)
         │
         └── NO → Use ScreenLessCore + ScreenLessFlow
                  (Pure coordinator, e.g., AppCoordinator, DeepLinkHandler)
```

## 1. Core

### Responsibilities
- **Business Logic Center**: Handles state management and action processing
- **Reactor Pattern Implementation**: Acts as a Reactor when a Screen exists (unidirectional data flow)
- **Routing Requests**: Can request routing to Flow even without a Screen

### When Screen Exists (Core)
- Adopts `Reactable` protocol: Provides `state` Publisher and `send(_:)` method
- Adopts `Activatable` protocol: Lifecycle callbacks `didBecomeActive()`, `willResignActive()`
- Interacts with Screen via unidirectional data flow

### When Screen Does Not Exist (ScreenLessCore)
- Adopts only `Activatable` protocol
- Performs only routing/coordination role without state management
- Acts as coordinator for child Flows

## 2. Screen

### Responsibilities
- **UI Layer**: Displays screens based on UIViewController
- **State Subscription**: Observes Core's State changes to update UI
- **Action Forwarding**: Forwards user interactions to Core

---

## 3. Flow

### Responsibilities
- **Composition Root**: Creates and owns Core and Screen
- **Tree Structure Center**: Owns child Flows to form hierarchy
- **Lifecycle Management**: Calls Core's activation/deactivation callbacks
- **Memory Management**: Parent Flow is fully responsible for child Flow memory management

### Note: Import Required for Inherited Property Access

Flow, Screen, and Core inherit from classes in the CoreFlow package. Due to Swift's module system characteristics, **you must import CoreFlow in the file to access inherited properties (`core`, `screen`, `reactor`, etc.).**

---

### Routing Flow Diagram

```
User Interaction ([Child name]Screen)
       ↓
[Child name]Screen.send(.completeButtonTapped)
       ↓
[Child name]Core.reduce() → listener?.[child name]DidFinish(result:)
       ↓
[Feature name]Core (listener) → router?.detach[Child name]()
       ↓
[Feature name]Flow (router) → self.[child name]Flow = nil → Flow deallocated
       ↓
[Child name]Flow.deinit → core.willResignActive()
```

---

## Ownership Diagram

```
Flow (Owner)
├── Core (strong reference)
│   ├── State (@Published)
│   ├── reduce(action) → Effect
│   └── didBecomeActive / willResignActive
│
└── Screen (strong reference)
    ├── reactor: Core (weak reference)
    ├── observeState() → Subscribe to State
    └── send(action) → Forward to Core
```

---

## Data Flow

```
User Interaction
       ↓
Screen.send(action)
       ↓
Core.reduce(state, action) → Effect
       ↓
State changed (@Published)
       ↓
Screen.observeState() → UI Update
```

---

## Code Templates

### Template 1: Core (with Screen)

```swift
// {FeatureName}Core.swift
import CoreFlow
import Combine

// MARK: - Action
enum {FeatureName}Action: Sendable {
    // User actions
    case viewDidLoad
    case someButtonTapped

    // Internal mutations
    case _setLoading(Bool)
    case _setData(SomeData)
}

// MARK: - State
struct {FeatureName}State {
    var isLoading: Bool = false
    var data: SomeData?
}

// MARK: - Routing Protocol
protocol {FeatureName}Routing: AnyObject {
    func routeToDetail(with data: SomeData)
    func detachChild()
}

// MARK: - Listener Protocol (for parent communication)
protocol {FeatureName}Listener: AnyObject {
    func {featureName}DidFinish(result: SomeResult)
}

// MARK: - Core
final class {FeatureName}Core: Core<{FeatureName}Action, {FeatureName}State> {
    weak var router: {FeatureName}Routing?
    weak var listener: {FeatureName}Listener?

    // MARK: - Dependencies
    private let someService: SomeServiceProtocol

    init(
        initialState: {FeatureName}State,
        someService: SomeServiceProtocol
    ) {
        self.someService = someService
        super.init(initialState: initialState)
    }

    // MARK: - Lifecycle
    override func didBecomeActive() {
        // Called when Core becomes active
    }

    override func willResignActive() {
        // Called when Core will deactivate
    }

    // MARK: - Reduce
    override func reduce(
        state: inout {FeatureName}State,
        action: {FeatureName}Action
    ) -> Effect<{FeatureName}Action> {
        switch action {
        case .viewDidLoad:
            return .run { [weak self] send in
                await send(._setLoading(true))
                guard let data = await self?.someService.fetchData() else { return }
                await send(._setData(data))
                await send(._setLoading(false))
            }

        case .someButtonTapped:
            guard let data = state.data else { return .none }
            router?.routeToDetail(with: data)
            return .none

        case ._setLoading(let isLoading):
            state.isLoading = isLoading
            return .none

        case ._setData(let data):
            state.data = data
            return .none
        }
    }
}
```

### Template 2: Screen

```swift
// {FeatureName}Screen.swift
import CoreFlow
import UIKit
import Combine

final class {FeatureName}Screen: Screen<{FeatureName}Core> {

    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Action", for: .normal)
        return button
    }()

    // MARK: - Lifecycle
    override func initialize() {
        // Called once during init - setup UI hierarchy here
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
        send(.viewDidLoad)
    }

    // MARK: - Bind
    override func bind() {
        // Observe state changes
        observeDistinctState(\.isLoading) { [weak self] isLoading in
            self?.actionButton.isEnabled = !isLoading
        }

        observeDistinctState(\.data) { [weak self] data in
            self?.titleLabel.text = data?.title
        }
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Add subviews and constraints
        view.addSubview(titleLabel)
        view.addSubview(actionButton)

        // Setup constraints...

        // Button action
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }

    // MARK: - Actions
    @objc private func actionButtonTapped() {
        send(.someButtonTapped)
    }
}
```

### Template 3: Flow

```swift
// {FeatureName}Flow.swift
import CoreFlow
import UIKit

public final class {FeatureName}Flow: Flow<{FeatureName}Core, {FeatureName}Screen> {

    // MARK: - Child Flows
    private var childFlow: ChildFlow?

    // MARK: - Dependencies
    private weak var listener: {FeatureName}Listener?

    // MARK: - Init
    public init(listener: {FeatureName}Listener?) {
        self.listener = listener
        super.init()
    }

    // MARK: - Factory Methods
    public override func createCore() -> {FeatureName}Core {
        let core = {FeatureName}Core(
            initialState: .init(),
            someService: someService
        )
        core.listener = listener
        core.router = self
        return core
    }

    public override func createScreen() -> {FeatureName}Screen {
        let screen = {FeatureName}Screen(reactor: core)
        return screen
    }
}

// MARK: - Routing
extension {FeatureName}Flow: {FeatureName}Routing {
    func routeToDetail(with data: SomeData) {
        let flow = ChildFlow(listener: core, data: data)
        childFlow = flow
        screen.navigationController?.pushViewController(flow.screen, animated: true)
    }

    func detachChild() {
        childFlow = nil
        screen.navigationController?.popViewController(animated: true)
    }
}
```

### Template 4: ScreenLessCore (Coordinator without UI)

```swift
// {FeatureName}Core.swift
import CoreFlow

protocol {FeatureName}Routing: AnyObject {
    func routeToFeatureA()
    func routeToFeatureB()
}

protocol {FeatureName}Listener: AnyObject {}

final class {FeatureName}Core: ScreenLessCore {
    weak var router: {FeatureName}Routing?
    weak var listener: {FeatureName}Listener?

    override func didBecomeActive() {
        // Initial routing decision
        if someCondition {
            router?.routeToFeatureA()
        } else {
            router?.routeToFeatureB()
        }
    }
}
```

### Template 5: ScreenLessFlow (Coordinator without UI)

```swift
// {FeatureName}Flow.swift
import CoreFlow
import UIKit

final class {FeatureName}Flow: ScreenLessFlow<{FeatureName}Core> {
    private weak var listener: {FeatureName}Listener?

    // MARK: - Child Flows
    private var featureAFlow: FeatureAFlow?
    private var featureBFlow: FeatureBFlow?

    init(listener: {FeatureName}Listener) {
        self.listener = listener
        super.init()
    }

    override func createCore() -> {FeatureName}Core {
        let core = {FeatureName}Core()
        core.listener = listener
        core.router = self
        return core
    }
}

extension {FeatureName}Flow: {FeatureName}Routing {
    func routeToFeatureA() {
        let flow = FeatureAFlow(listener: core)
        featureAFlow = flow
        window?.rootViewController = UINavigationController(rootViewController: flow.screen)
    }

    func routeToFeatureB() {
        let flow = FeatureBFlow(listener: core)
        featureBFlow = flow
        featureAFlow = nil
        window?.rootViewController = UINavigationController(rootViewController: flow.screen)
    }
}
```

---

## Checklist Before Creating CoreFlow

1. [ ] Determine variant: Standard (Core+Screen+Flow) or ScreenLess
2. [ ] Define Action enum with all user interactions and internal mutations
3. [ ] Define State struct with all UI-bindable properties
4. [ ] Define Routing protocol for navigation within this feature
5. [ ] Define Listener protocol if parent needs to receive events