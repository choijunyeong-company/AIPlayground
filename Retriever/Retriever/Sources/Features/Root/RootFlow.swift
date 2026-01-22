//
//  RootFlow.swift
//  Retriever
//

import CoreFlow
import UIKit

public struct RootArgument {
    public init() {}
}

public final class RootFlow: ScreenLessFlow<RootCore> {
    private weak var listener: RootListener?
    private let argument: RootArgument

    private var loginFlow: LoginFlow?
    private var onboardingFlow: OnboardingFlow?
    private var mainFlow: MainFlow?

    private weak var navigationController: UINavigationController?

    public init(
        listener: RootListener? = nil,
        argument: RootArgument = .init(),
        navigationController: UINavigationController
    ) {
        self.listener = listener
        self.argument = argument
        self.navigationController = navigationController
        super.init()
    }

    public override func createCore() -> RootCore {
        let core = RootCore()
        core.listener = listener
        core.router = self
        return core
    }
}

// MARK: - Routing
extension RootFlow: RootRouting {
    public func routeToLogin() {
        let loginFlow = LoginFlow(
            listener: core,
            argument: .init()
        )
        self.loginFlow = loginFlow
        navigationController?.setViewControllers([loginFlow.screen], animated: false)
    }

    public func routeToOnboarding() {
        let onboardingFlow = OnboardingFlow(
            listener: core,
            argument: .init()
        )
        self.onboardingFlow = onboardingFlow
        navigationController?.setViewControllers([onboardingFlow.screen], animated: true)
    }

    public func detachLogin() {
        loginFlow = nil
    }

    public func detachOnboarding() {
        onboardingFlow = nil
    }

    public func routeToMain() {
        let mainFlow = MainFlow(
            listener: self,
            argument: .init()
        )
        self.mainFlow = mainFlow
        navigationController?.setViewControllers([mainFlow.screen], animated: true)
    }
}

// MARK: - MainListener
extension RootFlow: MainListener {}
