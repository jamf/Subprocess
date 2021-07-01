## Subprocess

Subprocess is a Swift library for macOS providing interfaces for both synchronous and asynchronous process execution. 

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
