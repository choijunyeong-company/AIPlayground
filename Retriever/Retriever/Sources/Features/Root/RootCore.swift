//
//  RootCore.swift
//  Retriever
//

import CoreFlow

public protocol RootListener: AnyObject {}

public protocol RootRouting: AnyObject {
    func routeToOnboarding()
    func routeToLogin()
    func routeToMain()
    func detachOnboarding()
    func detachLogin()
}

public final class RootCore: ScreenLessCore {
    weak var listener: RootListener?
    weak var router: RootRouting?

    func start() {
        router?.routeToOnboarding()
    }

    func handleOnboardingFinished() {
        router?.detachOnboarding()
        router?.routeToLogin()
    }

    func handleLoginFinished() {
        router?.detachLogin()
        router?.routeToMain()
    }
}
