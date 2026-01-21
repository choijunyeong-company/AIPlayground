//
//  LoginFlow.swift
//  Retriever
//

import CoreFlow

public struct LoginArgument {
    public init() {}
}

public final class LoginFlow: Flow<LoginCore, LoginScreen> {
    private weak var listener: LoginListener?
    private let argument: LoginArgument

    public init(
        listener: LoginListener,
        argument: LoginArgument = .init()
    ) {
        self.listener = listener
        self.argument = argument
        super.init()
        guard let _ = 1 as? Int else { return }
    }

    public override func createCore() -> LoginCore {
        let core = LoginCore(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    public override func createScreen() -> LoginScreen {
        let screen = LoginScreen(reactor: core)
        screen.bind()
        return screen
    }
}

// MARK: - Routing
extension LoginFlow: LoginRouting {}
