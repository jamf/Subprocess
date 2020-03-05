# Subprocess

# Usage
### Shell
The Shell class can be used for synchronous command execution.

#### Command Input

###### Input for data
```
let inputData: Data = ...
let data = try Shell(["/usr/bin/grep", "Hello"]).exec(input: .data(inputData))
```
###### Input for text
```
let data = try Shell(["/usr/bin/grep", "Hello"]).exec(input: .text("Hello world"))
```
###### Input for file URL
```
let url = URL(fileURLWithPath: "/path/to/input/file")
let data = try Shell(["/usr/bin/grep", "foo"]).exec(input: .file(url: url))
```
###### Input for file path
```
let data = try Shell(["/usr/bin/grep", "foo"]).exec(input: .file(path: "/path/to/input/file"))
```

#### Command Output


###### Output as Data
```
let data = try Shell(["/usr/bin/sw_vers"]).exec()
```
###### Output as String
```
let text = try Shell(["/usr/bin/sw_vers"]).exec(encoding: .utf8)
```
###### Output as JSON (Array or Dictionary)
```
let command = ["/usr/bin/log", "show", "--style", "json", "--last", "5m"]
let logs: [[String: Any]] = try Shell(command).execJSON())
```
###### Output as decodable object from JSON
```
struct LogMessage: Codable {
    var subsystem: String
    var category: String
    var machTimestamp: UInt64
}
let command = ["/usr/bin/log", "show", "--style", "json", "--last", "5m"]
let logs: [LogMessage] try Shell(command).exec(decoder: JSONDecoder())
```
###### Output as Property List (Array or Dictionary)
```
let command = ["/bin/cat", "/System/Library/CoreServices/SystemVersion.plist"]
let dictionary: [String: Any] = try Shell(command).execPropertyList())
```
###### Output as decodable object from Property List
```
struct SystemVersion: Codable {
    enum CodingKeys: String, CodingKey {
        case version = "ProductVersion"
    }
    var version: String
}
let command = ["/bin/cat", "/System/Library/CoreServices/SystemVersion.plist"]
let result: SystemVersion = try Shell(["/bin/cat", softwareVersionFilePath]).exec(decoder: PropertyListDecoder())
```
###### Output mapped to other type 
```
let enabled = try Shell(["csrutil", "status"]).exec(encoding: .utf8) { _, txt in txt.contains("enabled") }
```

###### Output options
```
let command: [String] = ...
let errorText = try Shell(command).exec(options: .stderr, encoding: .utf8)
let outputText = try Shell(command).exec(options: .stdout, encoding: .utf8)
let combinedData = try Shell(command).exec(options: .combined)
```
## Installation
### SwiftPM
```
dependencies: [
	.package(url: "https://github.com/jamf/Subprocess.git", from: "1.0.0")
]
```
### Cocoapods
```
pod 'Subprocess'
```
### Carthage
```
github 'jamf/Subprocess'
```