## Subprocess

Subprocess is a Swift library for macOS providing interfaces for external process execution. 

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 3.0.0 - 2023-10-13

### Added
- Methods to `Subprocess` that support Swift Concurrency.
- `Subprocess.run(standardInput:options:)` can run interactive commands.

### Changed 
- Breaking: `Subprocess.init` no longer accepts an argument for a dispatch queue's quality of service since the underlying implementation now uses Swift Concurrency and not GCD.
- Breaking: `Input`s `text` case no longer accepts an encoding as utf8 is overwhelmingly common. Instead convert the string to data explicitly if an alternate encoding is required.
- `Shell` and `SubprocessError` have been deprecated in favor of using new replacement methods that support Swift Concurrency and no longer for a synchronized wait.

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
