// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Subprocess",
    platforms: [ .macOS(.v10_13) ],
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
            name: "libSubprocess",
            type: .dynamic,
            targets: [ "Subprocess" ]
        ),
        .library(
            name: "libSubprocessMocks",
            type: .dynamic,
            targets: [ "SubprocessMocks" ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
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
