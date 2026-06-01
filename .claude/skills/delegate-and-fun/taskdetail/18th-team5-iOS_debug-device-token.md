# 작업개요

빌드세팅의 ENV값이 Dev인 경우 디바이스 토큰을 커스텀으로 설정할 수 있는 디버그 기능을 구현합니다. Domain 레이어에 디버그 전용 토큰 세팅 메서드를 추가하고, Presentation 레이어에 토큰 입력 UI를 구현한 뒤, RootFeature에 이를 통합하고 테스트 코드를 작성합니다.

# Task1: Domain - TokenRepository에 디버그 토큰 세팅 메서드 추가

## 수정 파일
- `Projects/Domain/Sources/Repository/TokenRepository.swift`

## 상세 명세

`TokenRepository` 구조체에 `setDebugDeviceToken` 클로저 프로퍼티를 추가합니다.

```swift
public var setDebugDeviceToken: @Sendable (_ token: String) -> Void
```

- `TestDependencyKey`의 `testValue`에서는 빈 구현(`{ _ in }`) 제공
- `DependencyValues` 확장은 기존 그대로 유지

Data 레이어의 `TokenRepositoryImpl` (`Projects/Data/Sources/Repository/TokenRepositoryImpl.swift`)에서 `liveValue` 구현 시:
- `DeviceIDClient`의 캐시를 덮어쓸 수 없으므로, `KeychainHelper`를 통해 `deviceID` 키값을 직접 저장하는 방식으로 구현
- `TokenRepository`의 `setDebugDeviceToken` 클로저에서 `KeychainHelper.save(data:forKey: .deviceID)` 호출
- **preconditionFailure 가드**: 클로저 내부에서 ENV값이 "Dev"가 아니면 `preconditionFailure("setDebugDeviceToken is only available in Dev environment")` 발생
  - ENV값은 `Bundle.main.infoDictionary?["ENV"]` 로 확인하거나, Domain에서는 ENV값을 직접 알 수 없으므로 `isDebug: Bool` 파라미터를 `TokenRepository` 생성 시 주입받는 방식 사용
  - **대안**: `TokenRepositoryImpl.live()`에서 ENV 값을 읽어 `setDebugDeviceToken` 클로저 내부에서 가드

## 패턴
- 기존 `TokenRepository`는 `struct-of-closures` 패턴 (수동 init). `@DependencyClient`가 아님.
- 새 프로퍼티 추가 시 `init` 파라미터도 함께 수정 필요
- `TokenRepository`의 init에 `setDebugDeviceToken` 파라미터 추가

# Task2: Presentation - DebugTokenSetting Feature 및 View 구현

## 신규 파일
- `Projects/Presentation/Sources/Debug/DebugTokenSettingFeature.swift`
- `Projects/Presentation/Sources/Debug/DebugTokenSettingView.swift`

## 상세 명세

### DebugTokenSettingFeature

```swift
@Reducer
struct DebugTokenSettingFeature {
    @ObservableState
    struct State: Equatable {
        var tokenText: String = ""
        var isDismissRequested: Bool = false
    }

    enum Action {
        case tokenTextChanged(String)
        case useCommonTokenButtonTapped  // "공통값사용" 버튼
        case confirmButtonTapped         // "입력완료" 버튼
        case delegate(Delegate)
    }

    enum Delegate {
        case completed(String)  // 토큰 설정 완료 → 부모에게 전달
    }
}
```

**로직:**
- `useCommonTokenButtonTapped`: 공통 디바이스 ID `"AAAA-AAAA-AAAA-AAAA"` 를 `tokenText`에 설정하고 즉시 토큰 저장 후 delegate 전달
- `confirmButtonTapped`: `tokenText.count >= 5` 인 경우 토큰 저장 후 delegate 전달
- 토큰 저장은 `@Dependency(\.tokenRepository)`의 `setDebugDeviceToken` 호출
- delegate `.completed(String)` 발생 시 부모(RootFeature)가 이를 수신

### DebugTokenSettingView

```swift
struct DebugTokenSettingView: View {
    let store: StoreOf<DebugTokenSettingFeature>
}
```

**UI 구성:**
- 상단에 "공통값 사용" 버튼
- 텍스트 필드 (토큰 입력)
- "입력완료" 버튼
- 심플한 형태의 디버그 전용 화면

# Task3: RootFeature에 DebugTokenSetting 통합

## 수정 파일
- `Projects/Presentation/Sources/Root/RootFeature.swift`
- `Projects/Presentation/Sources/Root/RootView.swift`
- `Projects/App/Sources/App.swift`

## 상세 명세

### RootFeature 수정

1. **State에 `isDebug` 추가:**
```swift
public struct State: Equatable {
    let isDebug: Bool
    // ... 기존 필드

    public init(currentAppVersion: AppVersion = .current, isDebug: Bool = false) {
        self.currentAppVersion = currentAppVersion
        self.isDebug = isDebug
    }
}
```

2. **State에 `debugTokenSetting` 추가 (Sheet presentation):**
```swift
@Presents var debugTokenSetting: DebugTokenSettingFeature.State?
```

3. **Action에 디버그 관련 케이스 추가:**
```swift
case debugTokenSetting(PresentationAction<DebugTokenSettingFeature.Action>)
case showDebugTokenSetting  // 런치플로우 완료 후 isDebug면 호출
```

4. **런치플로우 수정 (`handleLaunchConfig` 및 `navigateAfterAuth`):**
- `navigateAfterAuth`에서 `isDebug == true`이고 `debugTokenSetting == nil`인 경우, 기존 네비게이션 대신 디버그 토큰 설정 sheet를 present
- 디버그 토큰 설정 완료(delegate `.completed`) 후, `debugTokenSetting = nil` 로 dismiss 하고 원래 네비게이션 진행

### RootView 수정

- `.sheet(item: $store.scope(state: \.debugTokenSetting, action: \.debugTokenSetting))` 추가
- 내부에 `DebugTokenSettingView(store:)` 표시

### App.swift 수정

- `RootFeature.State(isDebug: true)` 로 주입 (ENV값이 Dev인 경우)
- ENV값 확인: `Bundle.main.infoDictionary?["ENV"] as? String == "Dev"`

# Task4: 테스트 코드 작성 및 실행

## 수정 파일
- `Projects/Presentation/Tests/RootFeatureTests.swift`

## 상세 명세

### 테스트 케이스: 런치플로우 정상 완료후, isDebug가 참이면 디버그 화면이 present됩니다.

```swift
@Test
func 런치플로우_정상완료_isDebug_참이면_디버그화면_present() async {
    // Given
    let sut = TestStore(initialState: .init(isDebug: true)) {
        RootFeature()
    } withDependencies: {
        $0.launchConfigRepository = .init(fetch: {
            .init(
                maintenance: false,
                isForceUpdateEnabled: false,
                minimumAppVersion: .init(major: 0, minor: 0, patch: 0),
                appStoreLink: ""
            )
        })
        $0.onboardingRepository.isOnboardingCompleted = { true }
    }
    sut.exhaustivity = .off

    // When
    await sut.send(.onAppear)
    await sut.receive(\.launchConfigLoaded) {
        // Then
        $0.debugTokenSetting = DebugTokenSettingFeature.State()
    }
}
```

## 검증
- `swift test` 또는 Tuist 생성 후 Xcode 테스트 실행으로 검증
