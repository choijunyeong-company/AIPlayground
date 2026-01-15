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
                ]
            ),
            buildableFolders: [
                "Retriever/Sources",
                "Retriever/Resources",
            ],
            dependencies: []
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
