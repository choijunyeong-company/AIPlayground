import CoreFlow

public struct MainArgument {
    public init() {}
}

public final class MainFlow: Flow<MainCore, MainScreen> {
    private weak var listener: MainListener?
    private let argument: MainArgument

    public init(
        listener: MainListener?,
        argument: MainArgument = .init()
    ) {
        self.listener = listener
        self.argument = argument
        super.init()
    }

    public override func createCore() -> MainCore {
        let core = MainCore(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    public override func createScreen() -> MainScreen {
        let screen = MainScreen(reactor: core)
        screen.bind()
        return screen
    }
}

// MARK: - Routing
extension MainFlow: MainRouting {}
