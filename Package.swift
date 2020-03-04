// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Subprocess",
    platforms: [ .macOS(.v10_13) ],
    products: [
        .library(name: "Subprocess", targets: ["Subprocess"]),
        .library(name: "SubprocessMocks", targets: ["Subprocess"])
    ],
    dependencies: [],
    targets: [
        .target( name: "Subprocess",  dependencies: []),
        .target( name: "SubprocessMocks",  dependencies: ["Subprocess"]),
        .testTarget(name: "UnitTests", dependencies: ["Subprocess", "SubprocessMocks"]),
        .testTarget(name: "SystemTests", dependencies: ["Subprocess", "SubprocessMocks"])
    ]
)
