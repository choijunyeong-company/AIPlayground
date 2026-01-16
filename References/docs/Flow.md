Flow의 예시 코드입니다. 주석을 통해 각 요소를 설명합니다.

```swift
import CoreFlow

extension LoginFlow {
    public struct Argument {}    
}

public final class LoginFlow: Flow<LoginCore, LoginScreen> {
    private weak var listener: LoginListener?
    private let argument: Argument

    // Core에 전달할 리스너와 외부로부터 전달받을 Argument를 초기화 시 주입받습니다.
    public init(listener: LoginListener, argument: Argument) {
        self.listener = listener
        self.argument = argument
        super.init()
    }

    // Core 생성 메서드입니다. 필요한 의존성을 설정하기도 합니다.
    public override func createCore() -> LoginCore {
        let core = LoginCore(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    // Screen 생성 메서드입니다.
    public override func createScreen() -> LoginScreen {
        let screen = LoginScreen(reactor: core)
        screen.bind()
        return screen
    }
}

// MARK: - Routing
extension LoginFlow: LoginRouting {
    // Routing 프로토콜에 선언된 메서드를 구현합니다.
}
```