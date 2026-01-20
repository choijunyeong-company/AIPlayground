//
//  LoginCore.swift
//  Retriever
//

import CoreFlow

public protocol LoginListener: AnyObject {
    func loginDidFinish()
}

public protocol LoginRouting: AnyObject {}

public enum LoginAction {
    case viewDidLoad
    case loginButtonTapped
}

public struct LoginState {}

public final class LoginCore: Core<LoginAction, LoginState> {
    weak var listener: LoginListener?
    weak var router: LoginRouting?

    public override func reduce(state: inout LoginState, action: LoginAction) -> Effect<LoginAction> {
        switch action {
        case .viewDidLoad:
            return .none

        case .loginButtonTapped:
            listener?.loginDidFinish()
            return .none
        }
    }
}
