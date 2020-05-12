// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Subprocess",
    platforms: [ .macOS(.v10_12) ],
    products: [
        .library(
            name: "Subprocess",
            type: .static,
            targets: [ "Subprocess" ]
        ),
        .library(
            name: "SubprocessMocks",
            type: .static,
            targets: [ "SubprocessMocks" ]
        ),
        .library(
            name: "SubprocessDylib",
            type: .dynamic,
            targets: [ "Subprocess" ]
        ),
        .library(
            name: "SubprocessMocksDylib",
            type: .dynamic,
            targets: [ "SubprocessMocks" ]
        )
    ],
    targets: [
        .target(
            name: "Subprocess",
            dependencies: []
        ),
        .target(
            name: "SubprocessMocks",
            dependencies: [
                .target(name: "Subprocess")
            ]
        ),
        .testTarget(
            name: "UnitTests",
            dependencies: [
                .target(name: "Subprocess"),
                .target(name: "SubprocessMocks")
            ]
        ),
        .testTarget(
            name: "SystemTests",
            dependencies: [
                .target(name: "Subprocess")
            ]
        )
    ]
)
