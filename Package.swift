// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Subprocess",
    platforms: [ .macOS(.v10_12) ],
    products: [
        .library(name: "Subprocess", targets: [ "Subprocess" ]),
        .library(name: "SubprocessMocks", targets: [ "SubprocessMocks" ])
    ],
    targets: [
        .target( name: "Subprocess", dependencies: []),
        .target( name: "SubprocessMocks", dependencies: [ "Subprocess" ]),
        .testTarget(name: "UnitTests", dependencies: [ "Subprocess", "SubprocessMocks" ]),
        .testTarget(name: "SystemTests", dependencies: [ "Subprocess" ])
    ]
)
