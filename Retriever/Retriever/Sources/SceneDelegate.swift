//
//  SceneDelegate.swift
//  Retriever
//

import UIKit
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var rootFlow: RootFlow?
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let navigationController = UINavigationController()
        navigationController.setNavigationBarHidden(true, animated: false)

        let rootFlow = RootFlow(
            listener: nil,
            argument: .init(),
            navigationController: navigationController
        )
        self.rootFlow = rootFlow

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        startLaunchProcedure()
    }

    /// 앱 시작 Procedure: Onboarding -> Login -> Main
    private func startLaunchProcedure() {
        guard let core = rootFlow?.core else { return }

        LaunchProcedure()
            .start(core) { [weak self] in
                self?.startLogoutThenLoginProcedure()
            }
    }

    /// 로그아웃 후 로그인 순환 Procedure: Logout 대기 -> Login -> Main (반복)
    private func startLogoutThenLoginProcedure() {
        guard let core = rootFlow?.core else { return }

        // 이전 Procedure 취소 (새 값 할당 시 자동 취소)
        LogoutThenLoginProcedure()
            .start(core, onProcedureFinish: { [weak self] in
                self?.startLogoutThenLoginProcedure()
            })
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}
}
