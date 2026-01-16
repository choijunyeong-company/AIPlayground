//___FILEHEADER___

import CoreFlow

public struct ___VARIABLE_productName___Argument {
    public init() {}
}

public final class ___VARIABLE_productName___Flow: Flow<___VARIABLE_productName___Core, ___VARIABLE_productName___Screen> {
    private weak var listener: ___VARIABLE_productName___Listener?
    private let argument: ___VARIABLE_productName___Argument

    public init(
        listener: ___VARIABLE_productName___Listener,
        argument: ___VARIABLE_productName___Argument = .init()
    ) {
        self.listener = listener
        self.argument = argument
        super.init()
    }

    public override func createCore() -> ___VARIABLE_productName___Core {
        let core = ___VARIABLE_productName___Core(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    public override func createScreen() -> ___VARIABLE_productName___Screen {
        let screen = ___VARIABLE_productName___Screen(reactor: core)
        screen.bind()
        return screen
    }
}

// MARK: - Routing
extension ___VARIABLE_productName___Flow: ___VARIABLE_productName___Routing {}
