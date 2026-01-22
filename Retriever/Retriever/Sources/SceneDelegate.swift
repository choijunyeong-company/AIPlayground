//
//  SceneDelegate.swift
//  Retriever
//

import UIKit
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var rootFlow: RootFlow?
    private var store: Set<AnyCancellable> = []

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

        LaunchProcedure()
            .start(rootFlow.core)
            .store(in: &store)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}
}
