import CoreFlow

public protocol MainListener: AnyObject {
    func mainDidRequestLogout()
}

public protocol MainRouting: AnyObject {}

public enum MainAction {
    case viewDidLoad
    case logoutButtonTapped
}

public struct MainState {}

public final class MainCore: Core<MainAction, MainState> {
    weak var listener: MainListener?
    weak var router: MainRouting?

    public override func reduce(state: inout MainState, action: MainAction) -> Effect<MainAction> {
        switch action {
        case .viewDidLoad:
            return .none
        case .logoutButtonTapped:
            listener?.mainDidRequestLogout()
            return .none
        }
    }
}
