// swift-tools-version: 5.10

import PackageDescription
 
let package = Package(
    name: "Subprocess",
    platforms: [ .macOS("10.15.4") ],
    products: [
        .library(
            name: "Subprocess",
            targets: [ "Subprocess" ]
        ),
        .library(
            name: "SubprocessMocks",
            targets: [ "SubprocessMocks" ]
        ),
        .library(
            name: "libSubprocess",
            targets: [ "Subprocess" ]
        ),
        .library(
            name: "libSubprocessMocks",
            targets: [ "SubprocessMocks" ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.0.0"))
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
    ],
    swiftLanguageVersions: [.v5, .version("6")]
)

for target in package.targets {
    var swiftSettings = target.swiftSettings ?? []
    
    // According to Swift's piecemeal adoption plan features that were
    // upcoming features that become language defaults and are still enabled
    // as upcoming features will result in a compiler error. Currently in the
    // latest 5.10 compiler this doesn't happen, the compiler ignores it.
    //
    // The Swift 6 compiler on the other hand does emit errors when features
    // are enabled. Unfortunately it appears that the preprocessor
    // !hasFeature(xxx) cannot be used to test for this situation nor does
    // #if swift(<6) guard against this. There must be some sort of magic
    // used that is special for compiling the Package.swift manifest.
    // Instead a versioned Package.swift can be used (e.g. Package@swift-5.10.swift)
    // and the implemented now default features can be removed in Package.swift.
    //
    // Or you can just delete the Swift 6 features that are enabled instead of
    // creating another manifest file and test to see if building under Swift 5
    // still works (it should almost always work).
    //
    // It's still safe to enable features that don't exist in older compiler
    // versions as the compiler will ignore features it doesn't have implemented.

    // swift 7
    swiftSettings.append(.enableUpcomingFeature("ExistentialAny"))
    swiftSettings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    
    target.swiftSettings = swiftSettings
}
