import XCTest
@testable import Subprocess
#if !COCOA_PODS
@testable import SubprocessMocks
#endif

struct TestCodableObject: Codable, Equatable {
    let uuid: UUID
    init() { uuid = UUID() }
}

// swiftlint:disable control_statement duplicated_key_in_dictionary_literal
@available(*, deprecated, message: "Swift Concurrency methods in Subprocess replace Shell")
final class ShellTests: XCTestCase {

    let command = [ "/usr/local/bin/somefakeCommand", "foo", "bar" ]

    override func setUp() {
        // This is only needed for SwiftPM since it runs all of the test suites as a single test run
        SubprocessDependencyBuilder.shared = MockSubprocessDependencyBuilder.shared
    }

    override func tearDown() {
        Shell.reset()
    }

    // MARK: Data

    func testExecReturningDataWhenExitCodeIsNoneZero() {
        // Given
        let exitCode = Int32.random(in: 1...Int32.max)
        let stdoutData = "stdout example".data(using: .utf8)
        let stderrData = "stderr example".data(using: .utf8)
        Shell.expect(command, input: nil, standardOutput: stdoutData, standardError: stderrData, exitCode: exitCode)

        // When
        XCTAssertThrowsError(_ = try Shell(command).exec()) { error in
            switch (error as? SubprocessError) {
            case .exitedWithNonZeroStatus(let status, let errorMessage):
                XCTAssertEqual(status, exitCode)
                let failMsg = "error message should have contained the results from only stdout but was \(errorMessage)"
                XCTAssertTrue(errorMessage.contains("stdout example"), failMsg)
                XCTAssertEqual(errorMessage, error.localizedDescription, "should have also set localizedDescription")
                let nsError = error as NSError
                XCTAssertEqual(Int(status), nsError.code, "should have also set the NSError exit code")
            default: XCTFail("Unexpected error type: \(error)")
            }
        }

        // Then
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningDataFromStandardOutput() {
        // Given
        var result: Data?
        let expected = Data([ UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max) ])
        let errorData = Data([ UInt8.random(in: 0...UInt8.max) ])
        Shell.expect(command, input: nil, standardOutput: expected, standardError: errorData)

        // When
        XCTAssertNoThrow(result = try Shell(command).exec())

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningDataFromStandardError() {
        // Given
        var result: Data?
        let expected = Data([ UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max) ])
        let stdOutData = Data([ UInt8.random(in: 0...UInt8.max) ])
        Shell.expect(command, input: nil, standardOutput: stdOutData, standardError: expected)

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(options: .stderr))

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningDataFromBothOutputs() {
        // Given
        var result = Data()
        let expectedStdout = UUID().uuidString
        let expectedStderr = UUID().uuidString
        Shell.expect(command,
                     input: nil,
                     standardOutput: expectedStdout.data(using: .utf8) ?? Data(),
                     standardError: expectedStderr.data(using: .utf8) ?? Data())

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(options: .combined))

        // Then
        let text = String(data: result, encoding: .utf8)
        XCTAssertEqual("\(expectedStdout)\(expectedStderr)", text, "should have combined stdout and stderror")
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: String

    func testExecReturningStringWhenExitCodeIsNoneZero() {
        // Given
        let exitCode = Int32.random(in: 1...Int32.max)
        let stdoutText = "should not show up"
        let stderrText = "should show up"
        Shell.expect(command, input: nil, stdout: stdoutText, stderr: stderrText, exitCode: exitCode)
        // When
        XCTAssertThrowsError(_ = try Shell(command).exec(options: .stderr, encoding: .utf8)) { error in
            switch (error as? SubprocessError) {
            case .exitedWithNonZeroStatus(let status, let errorMessage):
                XCTAssertEqual(status, exitCode)
                let failMsg = "should have put just stderr in the error: \(errorMessage)"
                XCTAssertEqual("should show up", errorMessage, failMsg)
                XCTAssertEqual(errorMessage, error.localizedDescription, "also should have set localizedDescription")
            default: XCTFail("Unexpected error type: \(error)")
            }
        }

        // Then
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningStringWhenOutputEncodingErrorOccurs() {
        // Given
        let invalidData = Data([ 0xFF, 0xFF, 0xFF, 0xFF ])
        Shell.expect(command, input: nil, standardOutput: invalidData)

        // When
        XCTAssertThrowsError(_ = try Shell(command).exec(encoding: .utf8)) {
            switch ($0 as? SubprocessError) {
            case .outputStringEncodingError: break
            default: XCTFail("Unexpected error type: \($0)")
            }
        }

        // Then
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningStringFromStandardOutput() {
        // Given
        var result: String?
        let expected = UUID().uuidString
        Shell.expect(command, input: nil, stdout: expected, stderr: UUID().uuidString)

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(encoding: .utf8))

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningStringFromStandardError() {
        // Given
        var result: String?
        let expected = UUID().uuidString
        Shell.expect(command, input: nil, stdout: UUID().uuidString, stderr: expected)

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(options: .stderr, encoding: .utf8))

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningStringFromBothOutputs() {
        // Given
        var result: String?
        let expectedStdout = UUID().uuidString
        let expectedStderr = UUID().uuidString
        Shell.expect(command, input: nil, stdout: expectedStdout, stderr: expectedStderr)

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(options: .combined, encoding: .utf8))

        // Then
        XCTAssertTrue(result?.contains(expectedStdout) ?? false)
        XCTAssertTrue(result?.contains(expectedStderr) ?? false)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: JSON object

    func testExecReturningJSONArray() {
        // Given
        var result: [String]?
        let expected: [String] = [
            UUID().uuidString,
            UUID().uuidString
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, json: expected))

        // When
        XCTAssertNoThrow(result = try Shell(command).execJSON())

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningJSONDictionary() {
        // Given
        var result: [String: [String: String]]?
        let expected: [String: [String: String]] = [
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ],
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ]
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, json: expected))

        // When
        XCTAssertNoThrow(result = try Shell(command).execJSON())

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningJSONWithInvalidCast() {
        // Given
        var result: [String]?
        let expected: [String: [String: String]] = [
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ],
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ]
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, json: expected))

        // When
        XCTAssertThrowsError(result = try Shell(command).execJSON()) {
            switch ($0 as? SubprocessError) {
            case .unexpectedJSONObject(let type):
                XCTAssertEqual(type, "__NSDictionaryI")
            default: XCTFail("Unexpected error type: \($0)")
            }
        }

        // Then
        XCTAssertNil(result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: Property list object

    func testExecReturningPropertyListArray() {
        // Given
        var result: [String]?
        let expected: [String] = [
            UUID().uuidString,
            UUID().uuidString
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, plist: expected))

        // When
        XCTAssertNoThrow(result = try Shell(command).execPropertyList())

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningPropertyListDictionary() {
        // Given
        var result: [String: [String: String]]?
        let expected: [String: [String: String]] = [
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ],
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ]
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, plist: expected))

        // When
        XCTAssertNoThrow(result = try Shell(command).execPropertyList())

        // Then
        XCTAssertEqual(expected, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningPropertyListWithInvalidCast() {
        // Given
        var result: [String]?
        let expected: [String: [String: String]] = [
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ],
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ]
        ]
        XCTAssertNoThrow(try Shell.expect(command, input: nil, plist: expected))

        // When
        XCTAssertThrowsError(result = try Shell(command).execPropertyList()) {
            switch ($0 as? SubprocessError) {
            case .unexpectedPropertyListObject(let type):
                XCTAssertEqual(type, "__NSDictionaryM")
            default: XCTFail("Unexpected error type: \($0)")
            }
        }

        // Then
        XCTAssertNil(result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: Decodable object from JSON

    func testExecReturningDecodableObjectFromJSON() {
        // Given
        var result: TestCodableObject?
        let expectObject: TestCodableObject = TestCodableObject()
        XCTAssertNoThrow(try Shell.expect(command, input: nil, jsonObject: expectObject))

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(decoder: JSONDecoder()))

        // Then
        XCTAssertEqual(expectObject, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: Decodable object from property list

    func testExecReturningDecodableObjectFromPropertyList() {
        // Given
        var result: TestCodableObject?
        let expectObject: TestCodableObject = TestCodableObject()
        XCTAssertNoThrow(try Shell.expect(command, input: nil, plistObject: expectObject))

        // When
        XCTAssertNoThrow(result = try Shell(command).exec(decoder: PropertyListDecoder()))

        // Then
        XCTAssertEqual(expectObject, result)
        Shell.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }
}
// swiftlint:enable control_statement duplicated_key_in_dictionary_literal
