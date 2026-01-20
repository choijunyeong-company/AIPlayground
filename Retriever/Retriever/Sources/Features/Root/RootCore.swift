//
//  RootCore.swift
//  Retriever
//

import CoreFlow

public protocol RootListener: AnyObject {}

public protocol RootRouting: AnyObject {
    func routeToOnboarding()
    func routeToLogin()
    func detachOnboarding()
    func detachLogin()
}

public final class RootCore: ScreenLessCore {
    weak var listener: RootListener?
    weak var router: RootRouting?

    func start() {
        router?.routeToLogin()
    }

    func handleLoginFinished() {
        router?.detachLogin()
        router?.routeToOnboarding()
    }

    func handleOnboardingFinished() {
        router?.detachOnboarding()
    }
}
