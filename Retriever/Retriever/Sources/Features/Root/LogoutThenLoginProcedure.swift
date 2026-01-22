//
//  LogoutThenLoginProcedure.swift
//  Retriever
//

import CoreFlow
import Combine

/// 로그아웃 후 로그인 → 메인 화면 순환을 처리하는 Procedure
/// 플로우: Logout 대기 -> Login -> Main -> (반복)
final class LogoutThenLoginProcedure: Procedure<RootProcedureStep>, @unchecked Sendable {
    override init() {
        super.init()
        onStep { step in step.waitForLogout() }
            .onStep { step, _ in step.waitForLogin() }
            .finalStep { step, _ in step.routeToMain() }
    }
}
