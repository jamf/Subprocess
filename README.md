# Subprocess
[![License](http://img.shields.io/badge/license-MIT-informational.svg?style=flat)](http://mit-license.org)
![Build](https://github.com/jamf/Subprocess/workflows/Build%20&%20Test/badge.svg)
[![CocoaPods](https://img.shields.io/cocoapods/v/Subprocess.svg)](https://cocoapods.org/pods/Subprocess)
[![Platform](https://img.shields.io/badge/platform-macOS-success.svg?style=flat)](https://developer.apple.com/macos)
[![Language](http://img.shields.io/badge/language-Swift-success.svg?style=flat)](https://developer.apple.com/swift)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-success.svg?style=flat)](https://swift.org/package-manager)
[![Documentation](https://img.shields.io/badge/documentation-100%25-green)](https://engineering.jamf.com/Subprocess/documentation/subprocess/)

Subprocess is a Swift library for macOS providing interfaces for both synchronous and asynchronous process execution. 
SubprocessMocks can be used in unit tests for quick and highly customizable mocking and verification of Subprocess usage. 

- [Usage](#usage)
    - [Subprocess Class](#subprocess-class)
        - [Command Input](#command-input) - [Data](#input-for-data), [Text](#input-for-text), [File](#input-for-file-url)
        - [Command Output](#command-output) - [Data](#output-as-data), [Text](#output-as-string), [Decodable JSON object](#output-as-decodable-object-from-json), [Decodable property list object](#output-as-decodable-object-from-property-list)
- [Installation](#installation)
    - [SwiftPM](#swiftpm)
    - [Cocoapods](#cocoapods)
    - [Carthage](#carthage)

[Full Documentation](./docs/index.html)

# Usage
### Subprocess Class
The `Subprocess` class can be used for command execution.

#### Command Input

###### Input for data
```swift
let inputData = Data("hello world".utf8)
let data = try await Subprocess.data(for: ["/usr/bin/grep", "hello"], standardInput: inputData)
```
###### Input for text
```swift
let data = try await Subprocess.data(for: ["/usr/bin/grep", "hello"], standardInput: "hello world")
```
###### Input for file URL
```swift
let data = try await Subprocess.data(for: ["/usr/bin/grep", "foo"], standardInput: URL(filePath: "/path/to/input/file"))
```

#### Command Output

###### Output as Data
```swift
let data = try await Subprocess.data(for: ["/usr/bin/sw_vers"])
```
###### Output as String
```swift
let string = try await Subprocess.string(for: ["/usr/bin/sw_vers"])
```
###### Output as decodable object from JSON
```swift
struct LogMessage: Codable {
    var subsystem: String
    var category: String
    var machTimestamp: UInt64
}

let result: [LogMessage] = try await Subprocess.value(for: ["/usr/bin/log", "show", "--style", "json", "--last", "30s"], decoder: JSONDecoder())
```
###### Output as decodable object from Property List
```swift
struct SystemVersion: Codable {
    enum CodingKeys: String, CodingKey {
        case version = "ProductVersion"
    }
    var version: String
}

let result: SystemVersion = try await Subprocess.value(for: ["/bin/cat", "/System/Library/CoreServices/SystemVersion.plist"], decoder: PropertyListDecoder())
```
###### Output mapped to other type 
```swift
let enabled = try await Subprocess(["/usr/bin/csrutil", "status"]).run().standardOutput.lines.first(where: { $0.contains("enabled") } ) != nil
```
###### Output options
```swift
let errorText = try await Subprocess.string(for: ["/usr/bin/cat", "/non/existent/file.txt"], options: .returnStandardError)
let outputText = try await Subprocess.string(for: ["/usr/bin/sw_vers"])

async let (standardOutput, standardError, _) = try Subprocess(["/usr/bin/csrutil", "status"]).run()
let combinedOutput = try await [standardOutput.string(), standardError.string()]
```
###### Handling output as it is read
```swift
let (stream, input) = {
    var input: AsyncStream<UInt8>.Continuation!
    let stream: AsyncStream<UInt8> = AsyncStream { continuation in
        input = continuation
    }

    return (stream, input!)
}()

let subprocess = Subprocess(["/bin/cat"])
let (standardOutput, _, waitForExit) = try subprocess.run(standardInput: stream)

input.yield("hello\n")

Task {
    for await line in standardOutput.lines {
        switch line {
        case "hello":
            input.yield("world\n")
        case "world":
            input.yield("and\nuniverse")
            input.finish()
        case "universe":
            await waitForExit()
            break
        default:
            continue
        }
    }
}
```
###### Handling output on termination
```swift
let process = Subprocess(["/usr/bin/csrutil", "status"])
let (standardOutput, standardError, waitForExit) = try process.run()
async let (stdout, stderr) = (standardOutput, standardError)
let combinedOutput = await [stdout.data(), stderr.data()]

await waitForExit()

if process.exitCode == 0 {
    // Do something with output data
} else {
    // Handle failure
}
```
###### Closure based callbacks
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
###### Handing output on termination with a closure
```swift
let command: [String] = ...
let process = Subprocess(command)

try process.launch { (process, outputData, errorData) in
    if process.exitCode == 0 {
        // Do something with output data
    } else {
        // Handle failure
    }
```

## Installation
### SwiftPM
```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/jamf/Subprocess.git", .upToNextMajor(from: "3.0.0")),
    ],
    targets: [
        .target(name: "<target>",
        dependencies: [
            // other dependencies
            .product(name: "Subprocess"),
        ]),
        // other targets
    ]
)
```
### Cocoapods
```ruby
pod 'Subprocess'
```
### Carthage
```ruby
github 'jamf/Subprocess'
```
