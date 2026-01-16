//
//  OnboardingFlow.swift
//  Retriever
//

import CoreFlow

public struct OnboardingArgument {
    public init() {}
}

public final class OnboardingFlow: Flow<OnboardingCore, OnboardingScreen> {
    private weak var listener: OnboardingListener?
    private let argument: OnboardingArgument

    public init(
        listener: OnboardingListener,
        argument: OnboardingArgument = .init()
    ) {
        self.listener = listener
        self.argument = argument
        super.init()
    }

    public override func createCore() -> OnboardingCore {
        let core = OnboardingCore(initialState: .init())
        core.listener = listener
        core.router = self
        return core
    }

    public override func createScreen() -> OnboardingScreen {
        let screen = OnboardingScreen(reactor: core)
        screen.bind()
        return screen
    }
}

// MARK: - Routing
extension OnboardingFlow: OnboardingRouting {}
