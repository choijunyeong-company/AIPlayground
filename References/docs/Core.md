Core의 예시 코드입니다. 주석을 통해 각 요소를 설명합니다.

```swift
import CoreFlow

// 상위 CoreFlow에 요청사항을 전송합니다. 이 경우 로그인이 끝났으니 해당 CoreFlow에 대한 종료를 암시합니다.
public protocol LoginListener: AnyObject {
    func loginFinished(user: User)
}

// 라우터(Flow)에 요청할 라우팅 액션을 선언합니다.
public protocol LoginRouting: AnyObject {}

// Screen으로부터 수신 가능한 유저 액션과 액션 처리 과정에서 발생하는 내부 파생 액션을 정의합니다.
// 내부에서만 사용되는 액션의 경우 케이스명 앞에 언더바(_)를 붙입니다.
public enum LoginAction {
    case viewDidLoad
    case loginButtonTapped
    case _loginFinished(User)
}

// Screen의 상태 또는 Core 내부 상태를 정의합니다.
public struct LoginState {
    var isLoading = false
}

public final class LoginCore: Core<LoginAction, LoginState> {
    // 의존성을 주입받습니다.
    @Autowired private var service: LoginService

    weak var listener: LoginListener?
    weak var router: LoginRouting?

    // 수신받은 액션을 처리하는 함수입니다.
    // - 상태 변화를 유발할 수 있습니다.
    // - Effect를 반환하여 파생 액션을 생성할 수 있습니다.
    override public func reduce(state: inout LoginState, action: LoginAction) -> Effect<LoginAction> {
        switch action {
        case .viewDidLoad:
            return .none

        case .loginButtonTapped:
            state.isLoading = true
            return .run { [weak self] send in
                guard let self else { return }

                let user = await service.login()
                await send(._loginFinished(user))
            }

        case let ._loginFinished(user):
            state.isLoading = false
            listener?.loginFinished(user: user)
            return .none
        }
    }
}
```