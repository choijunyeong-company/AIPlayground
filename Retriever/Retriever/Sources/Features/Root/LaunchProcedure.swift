//
//  LaunchProcedure.swift
//  Retriever
//

import CoreFlow
import Combine

/// 앱 런칭 시 워크플로우를 정의하는 Procedure
/// 플로우: Onboarding -> Login -> Main
final class LaunchProcedure: Procedure<RootProcedureStep>, @unchecked Sendable {
    override init() {
        super.init()
        onStep { step in step.waitForOnboarding() }
            .onStep { step, _ in step.waitForLogin() }
            .finalStep { step, _ in step.routeToMain() }
    }
}
