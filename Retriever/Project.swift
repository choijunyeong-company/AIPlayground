import ProjectDescription

let project = Project(
    name: "Retriever",
    targets: [
        .target(
            name: "Retriever",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.Retriever",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "UIApplicationSceneManifest": .dictionary([
                        "UIApplicationSupportsMultipleScenes": .boolean(false),
                        "UISceneConfigurations": .dictionary([
                            "UIWindowSceneSessionRoleApplication": .array([
                                .dictionary([
                                    "UISceneConfigurationName": .string("Default Configuration"),
                                    "UISceneDelegateClassName": .string(
                                        "$(PRODUCT_MODULE_NAME).SceneDelegate",
                                    ),
                                ]),
                            ]),
                        ]),
                    ]),
                ]
            ),
            buildableFolders: [
                "Retriever/Sources",
                "Retriever/Resources",
            ],
            dependencies: [
                .external(name: "CoreFlow")
            ]
        ),
        .target(
            name: "RetrieverTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.RetrieverTests",
            infoPlist: .default,
            buildableFolders: [
                "Retriever/Tests"
            ],
            dependencies: [.target(name: "Retriever")]
        ),
    ]
)
