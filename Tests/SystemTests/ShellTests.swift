import XCTest
@testable import Subprocess

final class ShellTests: XCTestCase {

    override func setUp() {
        SubprocessDependencyBuilder.shared = SubprocessDependencyBuilder()
    }

    let softwareVersionFilePath = "/System/Library/CoreServices/SystemVersion.plist"

    // MARK: Input values

    func testExecWithDataInput() {
        // Given
        let inputText = "This is a text\nabc123\nHello World"
        var result: String?

        // When
        XCTAssertNoThrow(result = try Shell(["/usr/bin/grep", "abc123"]).exec(input: .text(inputText), encoding: .utf8))

        // Then
        XCTAssertFalse(result?.isEmpty ?? true)
    }

    func testExecWithFileInput() {
        // Given
        let cmd = ["/usr/bin/grep", "ProductVersion"]
        var result: String?

        // When
        XCTAssertNoThrow(result = try Shell(cmd).exec(input: .file(path: softwareVersionFilePath), encoding: .utf8))

        // Then
        XCTAssertFalse(result?.isEmpty ?? true)
    }

    // MARK: String transform

    func testExecReturningBoolFromString() {
        // Given
        var result = false
        let username = NSUserName()

        // When
        XCTAssertNoThrow(result = try Shell(["/usr/bin/dscl", ".", "list", "/Users"]).exec(encoding: .utf8,
                                                                                           transformBlock: { _, txt in
            return txt.contains(username)
        }))

        // Then
        XCTAssertTrue(result)
    }

    // MARK: String

    func testExecReturningString() {
        // Given
        var result: String?
        let username = NSUserName()

        // When
        XCTAssertNoThrow(result = try Shell(["/usr/bin/dscl", ".", "list", "/Users"]).exec(encoding: .utf8))

        // Then
        XCTAssertTrue(result?.contains(username) ?? false)
    }

    // MARK: JSON object

    func testExecReturningJSONObject() {
        // Given
        var result: [[String: Any]]?

        // When
        XCTAssertNoThrow(result = try Shell(["/usr/bin/log", "show", "--style", "json", "--last", "5m"]).execJSON())

        // Then
        XCTAssertFalse(result?.isEmpty ?? true)
    }

    // MARK: Property list object

    func testExecReturningPropertyList() {
        // Given
        let fullVersionString = ProcessInfo.processInfo.operatingSystemVersionString
        var result: [String: Any]?

        // When
        XCTAssertNoThrow(result = try Shell(["/bin/cat", softwareVersionFilePath]).execPropertyList())

        // Then
        guard let versionNumber = result?["ProductVersion"] as? String else { return XCTFail("Unable to find version") }
        XCTAssertTrue(fullVersionString.contains(versionNumber))
    }

    // MARK: Decodable object from JSON

    // swiftlint:disable nesting

    func testExecReturningDecodableObjectFromJSON() {
        // Given
        struct LogMessage: Codable {
            var subsystem: String
            var category: String
            var machTimestamp: UInt64
        }
        var result: [LogMessage]?
        let cmd = ["/usr/bin/log", "show", "--style", "json", "--last", "5m"]
        // When
        XCTAssertNoThrow(result = try Shell(cmd).exec(decoder: JSONDecoder()))

        // Then
        XCTAssertFalse(result?.isEmpty ?? true)
    }

    // MARK: Decodable object from property list

    func testExecReturningDecodableObjectFromPropertyList() {
        struct SystemVersion: Codable {
            enum CodingKeys: String, CodingKey {
                case version = "ProductVersion"
            }
            var version: String
        }

        // Given
        let fullVersionString = ProcessInfo.processInfo.operatingSystemVersionString
        var result: SystemVersion?

        // When
        XCTAssertNoThrow(result = try Shell(["/bin/cat", softwareVersionFilePath]).exec(decoder: PropertyListDecoder()))

        // Then
        guard let versionNumber = result?.version else { return XCTFail("Result is nil") }
        XCTAssertTrue(fullVersionString.contains(versionNumber))
    }
    // swiftlint:enable nesting
}
