// swift-tools-version: 5.6

// WARNING:
// This file is automatically generated.
// Do not edit it by hand because the contents will be replaced.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "HTML Editor",
    platforms: [
        .iOS("15.2")
    ],
    products: [
        .iOSApplication(
            name: "HTML Editor",
            targets: ["AppModule"],
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .paper),
            accentColor: .presetColor(.purple),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .fileAccess(.userSelectedFiles, mode: .readWrite),
                .outgoingNetworkConnections()
            ],
            appCategory: .developerTools
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
