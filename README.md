# Subprocess
![Build](https://github.com/jamf/Subprocess/workflows/Build%20&%20Test/badge.svg)
[![License](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](http://mit-license.org)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg?style=flat)](https://developer.apple.com/macos)
[![Language](http://img.shields.io/badge/language-Swift-lightgrey.svg?style=flat)](https://developer.apple.com/swift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
[![Documentation](docs/badge.svg)](./docs/index.html)

- [Usage](#usage)
    - [Shell](#shell-class)
        - [Input](#command-input) - [Data](#input-for-data), [Text](#input-for-text), [File](#input-for-file-url)
        - [Output](#command-output) - [Data](#output-as-data), [Text](#output-as-string), [JSON](#output-as-json), [Decodable JSON object](#output-as-decodable-object-from-json), [Property list](#output-as-property-list), [Decodable property list object](#output-as-decodable-object-from-property-list)
    - [Subprocess](#subprocess-class)
- [Installation](#installation)
    - [SwiftPM](#swiftpm)
    - [Cocoapods](#cocoapods)
    - [Carthage](#carthage)
		
[Full Documentation](./docs/index.html)

# Usage
### Shell Class
The Shell class can be used for synchronous command execution.

#### Command Input

###### Input for data
```swift
let inputData: Data = ...
let data = try Shell(["/usr/bin/grep", "Hello"]).exec(input: .data(inputData))
```
###### Input for text
```swift
let data = try Shell(["/usr/bin/grep", "Hello"]).exec(input: .text("Hello world"))
```
###### Input for file URL
```swift
let url = URL(fileURLWithPath: "/path/to/input/file")
let data = try Shell(["/usr/bin/grep", "foo"]).exec(input: .file(url: url))
```
###### Input for file path
```swift
let data = try Shell(["/usr/bin/grep", "foo"]).exec(input: .file(path: "/path/to/input/file"))
```

#### Command Output

###### Output as Data
```swift
let data = try Shell(["/usr/bin/sw_vers"]).exec()
```
###### Output as String
```swift
let text = try Shell(["/usr/bin/sw_vers"]).exec(encoding: .utf8)
```
###### Output as JSON (Array or Dictionary)
```swift
let command = ["/usr/bin/log", "show", "--style", "json", "--last", "5m"]
let logs: [[String: Any]] = try Shell(command).execJSON())
```
###### Output as decodable object from JSON
```swift
struct LogMessage: Codable {
    var subsystem: String
    var category: String
    var machTimestamp: UInt64
}
let command = ["/usr/bin/log", "show", "--style", "json", "--last", "5m"]
let logs: [LogMessage] = try Shell(command).exec(decoder: JSONDecoder())
```
###### Output as Property List (Array or Dictionary)
```swift
let command = ["/bin/cat", "/System/Library/CoreServices/SystemVersion.plist"]
let dictionary: [String: Any] = try Shell(command).execPropertyList())
```
###### Output as decodable object from Property List
```swift
struct SystemVersion: Codable {
    enum CodingKeys: String, CodingKey {
        case version = "ProductVersion"
    }
    var version: String
}
let command = ["/bin/cat", "/System/Library/CoreServices/SystemVersion.plist"]
let result: SystemVersion = try Shell(command).exec(decoder: PropertyListDecoder())
```
###### Output mapped to other type 
```swift
let enabled = try Shell(["csrutil", "status"]).exec(encoding: .utf8) { _, txt in txt.contains("enabled") }
```

###### Output options
```swift
let command: [String] = ...
let errorText = try Shell(command).exec(options: .stderr, encoding: .utf8)
let outputText = try Shell(command).exec(options: .stdout, encoding: .utf8)
let combinedData = try Shell(command).exec(options: .combined)
```
### Subprocess Class
The Subprocess class can be used for asynchronous command execution.

###### Handling output as it is read
```swift
let command: [String] = ...
let process = Subprocess(command)

// The outputHandler and errorHandler are invoked serially
try process.launch(outputHandler: { data in
    // Handle new data read from stdout
}, errorHandler: { data in
    // Handle new data read from stderr
}, terminationHandler: { process in
    // Handle process termination, all scheduled calls to
    // the outputHandler and errorHandler are guaranteed to
    // have completed.
})
```
###### Handling output on termination
```swift
let command: [String] = ...
let process = Subprocess(command)

try process.launch { (process, outputData, errorData) in
    if process.exitCode == 0 {
        // Do something with output data
    } else {
        // Handle failure
    }
}
```

## Installation
### SwiftPM
```swift
dependencies: [
	.package(url: "https://github.com/jamf/Subprocess.git", from: "1.0.0")
]
```
### Cocoapods
```ruby
pod 'Subprocess'
```
### Carthage
```ruby
github 'jamf/Subprocess'
```