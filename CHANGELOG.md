## Subprocess

Subprocess is a Swift library for macOS providing interfaces for external process execution. 

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.1] - 2026-05-11

### Added
- `SubprocessMockObject` now provides a `setupMockBuilder()` static method (e.g. `Shell.setupMockBuilder()`, `Subprocess.setupMockBuilder()`) to wire up the mock dependency builder, replacing direct assignment to `SubprocessDependencyBuilder.shared`.

### Changed
- `SubprocessMockObject.reset()` now also restores `SubprocessDependencyBuilder.shared` to a real instance, so XCTest `tearDown` no longer needs to do it manually.
- `SubprocessMocks` imports `Subprocess` with `@testable` to expose internal APIs required for mocking.
- `.subprocessTesting` trait on `Trait where Self == SubprocessTrait` is deprecated and renamed to `.subprocess`.

## [4.0.0] - 2026-05-05

### Added
- New `SubprocessTesting` library target providing `SubprocessTrait` — a Swift Testing `TestTrait`/`SuiteTrait` that scopes subprocess mocking to individual tests via `@TaskLocal`, enabling safe parallel test execution.
- `SwiftTesting` test target with suite demonstrating parallel mock usage using Swift Testing.

### Changed
- `SubprocessDependencyFactory` now conforms to `Sendable`.
- `MockSubprocessDependencyBuilder` is now `public final` and `Sendable`; its `shared` instance is `@TaskLocal` instead of a `nonisolated(unsafe)` static, removing the need to manually reset it between tests.
- `MockSubprocessDependencyBuilder.makeProcess`, `makeInputFileHandle`, and `makeInputPipe` are now `public` to support the new `SubprocessTesting` target.
- `MockProcess.Context`, `MockProcess.Context.State`, `ExpectationError`, and `MockSubprocessError` now conform to `Sendable`.
- `MockProcess.Context.runStub` closure is now `@Sendable`.
- `MockProcess.Context` standard I/O properties marked `nonisolated(unsafe)` for `Sendable` conformance.
- All `Shell.expect` and `Subprocess.expect` overloads now use `#filePath` instead of `#file` for the default `file:` argument.
- Unit tests import `SubprocessMocks` publicly instead of `@testable`.
- `swift-tools-version` bumped to `5.10`.

## [3.0.5] - 2024-08-07

### Changed
- Non-breaking changes to public imports when compiling under Swift 6.

## [3.0.4] - 2024-07-01

### Changed
- Swift 6 compatibility updates.

## 3.0.3 - 2024-04-15

### Changed
- Correctly turned on `StrictConcurrency` in Swift 5.10 and earlier and added non-breaking conformance to `Sendable`.
- Updated documentation for closure based usage where `nonisolated(unsafe)` is required to avoid an error in projects that use `StrictConcurrency`.

## 3.0.2 - 2024-02-07

### Added
- Additional `Sendable` conformance where it can't be implicitly determined outside of this package.

### Removed
- `open` scope from `Subprocess` since none of its members were `open`.

## 3.0.1 - 2023-11-27

### Added
- Explicit `Sendable` conformance for some types which silences warnings in consuming projects where Xcode can't determine implicit conformance.

## 3.0.0 - 2023-10-13

### Added
- Methods to `Subprocess` that support Swift Concurrency.
- `Subprocess.run(standardInput:options:)` can run interactive commands.

### Changed 
- Breaking: `Subprocess.init` no longer accepts an argument for a dispatch queue's quality of service since the underlying implementation now uses Swift Concurrency and not GCD.
- Breaking: `Input`s `text` case no longer accepts an encoding as utf8 is overwhelmingly common. Instead convert the string to data explicitly if an alternate encoding is required.
- `Shell` and `SubprocessError` have been deprecated in favor of using new replacement methods that support Swift Concurrency and that no longer have a synchronized wait.
- Swift 5.9 (Xcode 15) is now the package minimum required to build.

## 2.0.0 - 2021-07-01

### Changed
- Breaking: added the output of the command to Shell's exception exitedWithNonZeroStatus error to better conform to objc interop and NSError
- Updated minimum deployment target to macOS 10.13.

## 1.1.0 - 2020-05-15

### Added
- Added dynamic library targets to SPM

### Fixed
- Fixed naming convention to match Jamf internal convention

## 1.0.1 - 2020-03-13

### Added
- Added Cocoapods support


## 1.0.0 - 2020-03-13

### Added
- All support for the initial release 
