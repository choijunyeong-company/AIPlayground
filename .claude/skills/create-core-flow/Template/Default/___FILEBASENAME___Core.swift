//___FILEHEADER___

import CoreFlow

public protocol ___VARIABLE_productName___Listener: AnyObject {}

public protocol ___VARIABLE_productName___Routing: AnyObject {}

public enum ___VARIABLE_productName___Action {
    case viewDidLoad
}

public struct ___VARIABLE_productName___State {}

public final class ___VARIABLE_productName___Core: Core<___VARIABLE_productName___Action, ___VARIABLE_productName___State> {
    weak var listener: ___VARIABLE_productName___Listener?
    weak var router: ___VARIABLE_productName___Routing?

    public override func reduce(state: inout ___VARIABLE_productName___State, action: ___VARIABLE_productName___Action) -> Effect<___VARIABLE_productName___Action> {
        switch action {
        case .viewDidLoad:
            return .none
        }
    }
}
