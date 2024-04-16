## Subprocess

Subprocess is a Swift library for macOS providing interfaces for external process execution. 

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
