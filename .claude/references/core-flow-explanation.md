# CoreFlow 아키텍처 명세

## 개요

CoreFlow는 iOS 애플리케이션의 기능을 **CoreFlow**라는 단위로 추상화하고, 각 기능 간의 유연한 결합을 이룰 수 있도록 설계된 아키텍처입니다.
세 가지 핵심 컴포넌트(Core, Screen, Flow)로 구성되며, RIBs의 구조적 장점과 ReactorKit/TCA의 상태 관리 패턴을 결합했습니다.

---

## 1. Core

### 역할
- **비즈니스 로직의 중심**: 상태 관리와 액션 처리를 담당
- **Reactor 패턴 구현**: Screen이 존재할 경우 Reactor 역할 수행 (단방향 데이터 흐름)
- **라우팅 요청**: Screen이 없는 경우에도 Flow에 라우팅 요청 가능

### Screen이 있는 경우 (Core)
- `Reactable` 프로토콜 채택: `state` Publisher와 `send(_:)` 메서드 제공
- `Activatable` 프로토콜 채택: `didBecomeActive()`, `willResignActive()` 라이프사이클 콜백
- Screen과 단방향 데이터 흐름으로 상호작용

### Screen이 없는 경우 (ScreenLessCore)
- `Activatable` 프로토콜만 채택
- 상태 관리 없이 라우팅/조정 역할만 수행
- 자식 Flow들의 조정자 역할

### 제네릭 파라미터
| 파라미터 | 역할 |
|---------|------|
| `Action` | 사용자 인터랙션 또는 비동기 작업 결과를 표현하는 이벤트 타입 |
| `State` | 현재 앱 상태를 나타내는 데이터 타입 |

### Effect 타입
```swift
public enum Effect<Action: Sendable>: @unchecked Sendable {
    case none
    case run(priority: TaskPriority? = nil, task: @Sendable (Send) async -> Void)
}
```

| 케이스 | 용도 |
|-------|------|
| `.none` | 부수 효과 없음, 상태 변경만 수행 |
| `.run` | 비동기 작업 실행 후 새로운 Action 발행 가능 |

### Core 생성 템플릿 예시

```swift
import CoreFlow

// Core의 이벤트를 외부로 전송할 수 있는 인터페이스입니다. 해당 프로토콜은 상위 CoreFlow가 구현합니다.
public protocol [Feature name]Listener: AnyObject {}

// CoreFlow계층 이동이 필요한 경우 필요한 요청에 대한 인터페이스입니다. 해당 프로토콜은 같은 CoreFlow내 Flow가 구현합니다.
public protocol [Feature name]Routing: AnyObject {}

// Screen으로 부터 수신 가능한 유저 액션입니다.
public enum [Feature name]Action {
    case viewDidLoad
}

// CoreFlow의 상태압니다. UI상태로 활용될 수 있습니다.
public struct [Feature name]State {}

public final class [Feature name]Core: Core<[Feature name]Action, [Feature name]State> {
    weak var listener: [Feature name]Listener?
    weak var router: [Feature name]Routing?

    public override func reduce(state: inout [Feature name]State, action: [Feature name]Action) -> Effect<[Feature name]Action> {
        switch action {
        case .viewDidLoad:
            return .none
        }
    }
}
```

---

## 2. Screen

### 역할
- **UI 레이어**: UIViewController 기반의 화면 표시
- **상태 구독**: Core의 State 변화를 관찰하여 UI 업데이트
- **액션 전달**: 사용자 인터랙션을 Core로 전달

### bind() 함수
Screen의 상태 관찰 및 액션 바인딩은 `bind()` 함수에서 구현합니다. Flow가 Screen을 생성할 때 `bind()`를 호출합니다.

```swift
override func bind() {
    // 상태 관찰: State 변화 시 UI 업데이트
    observeDistinctState(\.titleText) { [weak self] title in
        self?.label.text = title
    }

    // 액션 바인딩: Publisher 이벤트를 Action으로 변환하여 전송
    bind(onEmit: button.onTap, send: .buttonTapped)
}
```

| 메서드 | 용도 |
|-------|------|
| `observeState(_:sink:)` | 상태의 특정 프로퍼티 변화를 감지하여 sink 호출 |
| `observeDistinctState(_:sink:)` | 동일 값 중복 호출 방지 (Equatable 타입만) |
| `bind(onEmit:send:)` | Publisher 출력을 Action으로 변환하여 Core로 전송 |
| `send(_:)` | Action을 Core로 직접 전송 |

### Screen 생성 템플릿 예시
```swift
import CoreFlow
import UIKit

public final class [Feature name]Screen: Screen<[Feature name]Core> {
    private let label = UILabel()
    private let button = UIButton()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        send(.viewDidLoad)
    }

    // 상태 관찰 및 액션 바인딩 구현
    public override func bind() {
        observeDistinctState(\.title) { [weak self] title in
            self?.label.text = title
        }
    }
}
```

---

## 3. Flow

### 역할
- **Composition Root**: Core와 Screen을 생성하고 소유
- **트리 구조의 중심**: 자식 Flow를 소유하여 계층 구성
- **라이프사이클 관리**: Core의 활성화/비활성화 콜백 호출
- **메모리 관리**: 자식 Flow의 메모리 관리를 온전히 상위 Flow가 담당

### Flow 생성 템플릿 예시
```swift
import CoreFlow

public final class [Feature name]Flow: Flow<[Feature name]Core, [Feature name]Screen> {
    private weak var listener: [Feature name]Listener?

    public init(listener: [Feature name]Listener) {
        self.listener = listener
        super.init()
    }

    // core 프로퍼티 접근시 최초 한번 호출되는 매서드입니다. Core의 의존성은 해당 시점에 모두 결정됩니다.
    public override func createCore() -> [Feature name]Core {
        let core = [Feature name]Core(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    // screen 프로퍼티 접근시 최초 한번 호출되는 매서드입니다. Screen의 의존성은 해당 시점에 모두 결정됩니다.
    public override func createScreen() -> [Feature name]Screen {
        let screen = [Feature name]Screen(reactor: core)
        screen.bind()
        return screen
    }
}

// Core로 부터 전달받은 라우팅 요청을 처리하는 매서드 구현체를 구현합니다.
extension [Feature name]Flow: [Feature name]Routing {}
```

### 주의: 상속된 프로퍼티 접근 시 import 필요

Flow, Screen, Core는 CoreFlow 패키지의 클래스를 상속합니다. Swift의 모듈 시스템 특성상, **상속된 프로퍼티(`core`, `screen`, `reactor` 등)에 접근하려면 해당 파일에서 CoreFlow를 import해야 합니다.**

```swift
// ❌ CoreFlow import 없이는 상속된 프로퍼티 접근 불가
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootFlow: RootFlow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        let rootFlow = RootFlow()
        self.rootFlow = rootFlow

        window.rootViewController = rootFlow.screen  // 컴파일 에러: 'screen' 프로퍼티를 찾을 수 없음
        window.makeKeyAndVisible()
        self.window = window
    }
}
```

---

## 4. Flow 라우팅

### CoreFlow 계층 구조

CoreFlow는 트리 구조로 계층을 형성합니다. 상위 Flow가 하위 Flow를 소유하며, 메모리 관리를 담당합니다.

```
[Feature name]Flow (상위 Flow)
├── [Child A]Flow (자식 - 네비게이션 스택)
├── [Child B]Flow (자식 - 네비게이션 스택)
└── [Child C]Flow (자식 - 모달 프레젠테이션)
```

### 라우팅 아키텍처

Core는 구체적인 Flow가 아닌 **Routing 프로토콜**을 통해 라우팅을 요청합니다. Flow가 해당 프로토콜을 구현하여 실제 화면 전환을 수행합니다.

```swift
// Core 파일에서 Routing 프로토콜 정의
protocol [Feature name]Routing: AnyObject {
    func routeTo[Child name]()
    func detach[Child name]()
}
```

### 자식 Flow Attach (생성 및 표시)

```swift
extension [Feature name]Flow: [Feature name]Routing {
    func routeTo[Child name]() {
        // 1. 자식 Flow 생성 (현재 Core를 listener로 전달)
        let flow = [Child name]Flow(listener: core)

        // 2. 강한 참조로 자식 Flow 보관 (메모리 관리)
        self.[child name]Flow = flow

        // 3. 자식의 Screen을 UIKit으로 표시
        screen.navigationController?.pushViewController(flow.screen, animated: true)
    }
}
```

### 자식 Flow Detach (해제 및 제거)

```swift
extension [Feature name]Flow: [Feature name]Routing {
    func detach[Child name]() {
        guard let flow = [child name]Flow else { return }

        // 1. 강한 참조 해제 → Flow 메모리 해제 시작
        self.[child name]Flow = nil

        // 2. UIKit에서 Screen 제거
        screen.navigationController?.popViewController(animated: true)
    }
}
```

### Listener를 통한 자식 → 부모 통신

자식 Core는 작업 완료 시 Listener 프로토콜을 통해 부모 Core에 알립니다.

```swift
// 자식 Core 파일에서 Listener 프로토콜 정의
protocol [Child name]Listener: AnyObject {
    func [child name]DidFinish(result: [Result type])
}

// 부모 Core가 Listener 구현
extension [Feature name]Core: [Child name]Listener {
    func [child name]DidFinish(result: [Result type]) {
        // 라우팅 해제 요청
        router?.detachChild()
    }
}
```

### 라우팅 흐름 다이어그램

```
User Interaction ([Child name]Screen)
       ↓
[Child name]Screen.send(.completeButtonTapped)
       ↓
[Child name]Core.reduce() → listener?.[child name]DidFinish(result:)
       ↓
[Feature name]Core (listener) → router?.detach[Child name]()
       ↓
[Feature name]Flow (router) → self.[child name]Flow = nil → Flow 해제
       ↓
[Child name]Flow.deinit → core.willResignActive()
```

---

## 소유 관계 다이어그램

```
Flow (소유자)
├── Core (강한 참조)
│   ├── State (@Published)
│   ├── reduce(action) → Effect
│   └── didBecomeActive / willResignActive
│
└── Screen (강한 참조)
    ├── reactor: Core (약한 참조)
    ├── observeState() → State 구독
    └── send(action) → Core로 전달
```

---

## 데이터 흐름

```
User Interaction
       ↓
Screen.send(action)
       ↓
Core.reduce(state, action) → Effect
       ↓
State 변경 (@Published)
       ↓
Screen.observeState() → UI 업데이트
```
