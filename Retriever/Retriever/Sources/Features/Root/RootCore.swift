//
//  RootCore.swift
//  Retriever
//

import CoreFlow
import Combine

/// Procedure의 각 단계에서 수행할 작업을 정의하는 Step 프로토콜입니다.
/// Core가 이 프로토콜을 채택하여 각 Step의 실제 동작을 구현합니다.
protocol RootProcedureStep {
    /// Onboarding 완료를 기다리는 Step
    func waitForOnboarding() -> AnyPublisher<(RootProcedureStep, Void), Never>

    /// Login 완료를 기다리는 Step
    func waitForLogin() -> AnyPublisher<(RootProcedureStep, Void), Never>

    /// Main 화면으로 라우팅하는 마지막 Step
    func routeToMain()
}

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

    /// Step 완료를 알리기 위한 Subject입니다.
    private let onboardingStepFinished = CurrentValueSubject<Bool, Never>(false)
    private let loginStepFinished = CurrentValueSubject<Bool, Never>(false)
}

// MARK: - OnboardingListener
extension RootCore: OnboardingListener {
    public func onboardingDidFinish() {
        router?.detachOnboarding()
        onboardingStepFinished.send(true)
    }
}

// MARK: - LoginListener
extension RootCore: LoginListener {
    public func loginDidFinish() {
        router?.detachLogin()
        loginStepFinished.send(true)
    }
}

// MARK: - RootProcedureStep
extension RootCore: RootProcedureStep {
    func waitForOnboarding() -> AnyPublisher<(RootProcedureStep, Void), Never> {
        router?.routeToOnboarding()
        return onboardingStepFinished
            .filter { $0 }
            .map { _ in (self, ()) }
            .eraseToAnyPublisher()
    }

    func waitForLogin() -> AnyPublisher<(RootProcedureStep, Void), Never> {
        router?.routeToLogin()
        return loginStepFinished
            .filter { $0 }
            .map { _ in (self, ()) }
            .eraseToAnyPublisher()
    }

    func routeToMain() {
        router?.routeToMain()
    }
}
