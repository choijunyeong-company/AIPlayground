//
//  OnboardingCore.swift
//  Retriever
//

import CoreFlow

public protocol OnboardingListener: AnyObject {
    func onboardingDidFinish()
}

public protocol OnboardingRouting: AnyObject {}

public enum OnboardingAction {
    case viewDidLoad
    case startButtonTapped
}

public struct OnboardingState {}

public final class OnboardingCore: Core<OnboardingAction, OnboardingState> {
    weak var listener: OnboardingListener?
    weak var router: OnboardingRouting?

    public override func reduce(state: inout OnboardingState, action: OnboardingAction) -> Effect<OnboardingAction> {
        switch action {
        case .viewDidLoad:
            return .none
        case .startButtonTapped:
            listener?.onboardingDidFinish()
            return .none
        }
    }
}
