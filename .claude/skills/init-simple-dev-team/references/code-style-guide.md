# Code Style Guide

## 네이밍 규칙

### 파일명
- PascalCase 사용: `MiddleEffectMainCore.swift`, `ConsumerPriceIndexService.swift`
- 역할에 따른 접미사: `*Core`, `*Screen`, `*Flow`, `*Provider`, `*Service`, `*Entity`, `*DTO`

### 타입
- 클래스, 구조체, 열거형, 프로토콜: PascalCase
- 프로토콜 접미사: `*Listener`, `*Routing`, `*Service`
- CommonUI 컴포넌트: `IV` 접두사 사용 (`IVTabView`, `IVLabelButton`)

### 프로퍼티 / 함수
- camelCase 사용
- 프로퍼티는 기본적으로 `private` 접근 제한
- Boolean 프로퍼티: `is*` 접두사 (`isSelected`, `isHighlighted`)

### 열거형 케이스
- camelCase 사용: `case economy`, `case inflation`
- 매직 넘버 그룹핑용 열거형: `private enum Layout { static let padding = 20 }`

## Import 순서

```swift
import UIKit          // 1. 시스템 프레임워크
import CoreFlow       // 2. 아키텍처 프레임워크
import CommonUI       // 3. 앱 내부 프레임워크
import SnapKit        // 4. 서드파티 라이브러리
import Resource       // 5. 앱 리소스
```

## 아키텍처 패턴 (CoreFlow)

### 레이어 구조

```
Flow → Core + Screen
       Core: 비즈니스 로직 (reduce)
       Screen: UI 바인딩 (bind, observeState)
```

### Core 작성 규칙
- `Core<Action, State>`를 상속
- Action은 열거형으로 정의하며, 사용자 액션과 내부 액션을 구분
- `reduce(state:action:)` 메서드에서 순수 함수 형태로 상태 변경
- 비동기 작업은 `Effect`로 반환 (`Effect.run`, `Effect.none`)
- 서비스 의존성은 `@Autowired`로 주입

```swift
@Autowired private var service: ConsumerPriceIndexService

func reduce(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .viewDidLoad:
        return .run { send in
            let data = try await service.fetch()
            await send(.setData(data))
        }
    case .setData(let data):
        state.items = data
        return .none
    }
}
```

### Screen 작성 규칙
- `Screen<Core>`를 상속
- `viewDidLoad()`에서 UI 구성
- `bind()`에서 액션 전달 및 상태 구독 설정
- 상태 구독: `observeDistinctState(\.keyPath, receiver:)`
- 액션 전달: `forward(actions:)`, `map(publisher) { action }`

```swift
override func bind() {
    forward(actions: [
        map(tabView.selectedTab) { .tabSelected(index: $0) }
    ])

    observeDistinctState(\.title, receiver: headerView) { receiver, title in
        receiver.configure(title: title)
    }
}
```

### Flow 작성 규칙
- `Flow<Core, Screen>`을 상속
- `createCore()`, `createScreen()` 구현
- 라우팅 로직 포함

## UI 작성 규칙

### 뷰 구성
- Storyboard 사용하지 않음 (프로그래매틱 UIKit)
- SnapKit으로 Auto Layout 설정
- UI 구성은 extension으로 분리

```swift
// MARK: - UI Setup
private extension MyScreen {
    func setupView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }

    func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
```

### 매직 넘버 관리
- 레이아웃 상수는 `private enum Layout`에 정의

```swift
private enum Layout {
    static let horizontalPadding: CGFloat = 20
    static let itemSpacing: CGFloat = 12
}
```

### Configuration 패턴
- 컴포넌트 설정은 `configure()` 메서드로 체이닝
- `@discardableResult`를 붙여 반환값 무시 허용

```swift
@discardableResult
func configure(texts: [String]) -> Self {
    self.texts = texts
    return self
}
```

### ComponentView 작성 규칙
- CoreFlow의 `ComponentView`를 상속
- `initialize()`에서 UI 초기화
- 이벤트 발행: `PassthroughSubject` → `AnyPublisher`로 노출

```swift
private let _selectedTab = PassthroughSubject<Int, Never>()
var selectedTab: AnyPublisher<Int, Never> { _selectedTab.eraseToAnyPublisher() }
```

## 서비스 레이어

### 프로토콜 기반 설계
- 서비스는 프로토콜로 정의하고, 구현체는 `*Impl` 접미사

```swift
protocol ConsumerPriceIndexService {
    func fetchTotalCPIIndex() async throws -> [ConsumerPriceIndexEntity]
}

final class ConsumerPriceIndexServiceImpl: ConsumerPriceIndexService { ... }
```

### Actor Repository 패턴
- 스레드 안전한 데이터 캐싱에는 `actor` 사용
- 중복 요청 방지 로직 포함

```swift
final actor MyRepository {
    private var cached: [MyDTO] = []
    private var ongoingTask: Task<[MyDTO], Never>?

    func getData() async -> [MyDTO] {
        if !cached.isEmpty { return cached }
        if let task = ongoingTask { return await task.value }
        // fetch and cache...
    }
}
```

### 의존성 등록
- `Assembly` 프로토콜을 구현한 `*Provider`에서 서비스 등록
- AppDelegate에서 `ServiceLocator.shared.assemble()`로 등록

## 클로저 규칙

- 단일 표현식 / 파라미터 1~2회 사용: `$0` 축약형
- 파라미터 3회 이상 사용: 명시적 파라미터명

```swift
// $0 축약형
items.map { SelectableItem(value: $0, isSelected: false) }

// 명시적 파라미터
items.forEach { item in
    item.configure()
    item.validate()
    item.save()
}
```

## Guard 패턴

- `guard let ... else { return }` 형태 사용
- guard 문 다음에 빈 줄 삽입

```swift
guard let dataSource else { return }

dataSource.reload()
```

## MARK 주석

- 코드 영역 구분에 `// MARK: - 섹션명` 사용

```swift
// MARK: - UI Setup
// MARK: - Binding
// MARK: - Data Mapping
```

## 타입 시스템

- 원시값보다 열거형 선호
- 프로토콜 지향 설계
- 상태 관리에 `@Published` 사용
- 옵셔널 상태에는 `compactScope` 사용

## 폰트 시스템

- `UIFont` extension의 정적 프로퍼티 사용
- 스케일: Display, Title, Heading, Body, Label, Caption
- 무게: Bold, Semibold, Medium, Regular
- 예시: `UIFont.body1Medium`, `UIFont.caption2Regular`
