//___FILEHEADER___

import CoreFlow

public struct ___VARIABLE_productName___Argument {
    public init() {}
}

public final class ___VARIABLE_productName___Flow: ScreenLessFlow<___VARIABLE_productName___Core> {
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
        let core = ___VARIABLE_productName___Core()
        core.listener = listener
        core.router = self
        return core
    }
}

// MARK: - Routing
extension ___VARIABLE_productName___Flow: ___VARIABLE_productName___Routing {}
