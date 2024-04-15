import XCTest
@testable import Subprocess
#if !COCOA_PODS
@testable import SubprocessMocks
#endif

// swiftlint:disable duplicated_key_in_dictionary_literal
final class SubprocessTests: XCTestCase {

    let command = [ "/usr/local/bin/somefakeCommand", "foo", "bar" ]

    override func setUp() {
        // This is only needed for SwiftPM since it runs all of the test suites as a single test run
        SubprocessDependencyBuilder.shared = MockSubprocessDependencyBuilder.shared
    }

    override func tearDown() {
        Subprocess.reset()
    }

    // MARK: Input

    func testInputData() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = Data([ UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max) ])

        // When
        let input = Input.data(expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .data(let data): XCTAssertEqual(data, expected)
        default: XCTFail("Unexpected type")
        }
        guard let pipe = pipeOrFileHandle as? MockPipe else { return XCTFail("Unable to cast MockPipe") }
        XCTAssertEqual(pipe.data, expected)
    }

    func testInputText() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = UUID().uuidString

        // When
        let input = Input.text(expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .text(let text):
            XCTAssertEqual(text, expected)
        default: XCTFail("Unexpected type")
        }
        guard let pipe = pipeOrFileHandle as? MockPipe else { return XCTFail("Unable to cast MockPipe") }
        guard let data = pipe.data, let text = String(data: data, encoding: .utf8) else {
            return XCTFail("Failed to convert pipe data to string")
        }
        XCTAssertEqual(text, expected)
    }

    func testInputFilePath() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = "/some/fake/path/\(UUID().uuidString)"

        // When
        let input = Input.file(path: expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .file(let url): XCTAssertEqual(url.path, expected)
        default: XCTFail("Unexpected type")
        }
        guard let pipe = pipeOrFileHandle as? MockFileHandle else { return XCTFail("Unable to cast MockFileHandle") }
        XCTAssertEqual(pipe.url?.path, expected)
    }

    func testInputFileURL() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = URL(fileURLWithPath: "/some/fake/path/\(UUID().uuidString)")

        // When
        let input = Input.file(url: expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .file(let url): XCTAssertEqual(url, expected)
        default: XCTFail("Unexpected type")
        }
        guard let pipe = pipeOrFileHandle as? MockFileHandle else { return XCTFail("Unable to cast MockFileHandle") }
        XCTAssertEqual(pipe.url, expected)
    }

    // MARK: PID
    
    func testGetPID() throws {
        // Given
        let mockCalled = expectation(description: "Mock setup called")
        nonisolated(unsafe) var expectedPID: Int32?
        Subprocess.expect(command) { mock in
            expectedPID = mock.reference.processIdentifier
            mockCalled.fulfill()
        }

        // When
        let subprocess = Subprocess(command)
        _ = try subprocess.run()

        // Then
        wait(for: [mockCalled], timeout: 5.0)
        XCTAssertEqual(subprocess.pid, expectedPID)
    }

    // MARK: launch with termination handler

    func testLaunchWithTerminationHandler() {
        // Given
        let terminationExpectation = expectation(description: "Termination block called")
        let expectedExitCode = Int32.random(in: Int32.min...Int32.max)
        let expectedStdout = Data([ UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max) ])
        let expectedStderr = Data([ UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max) ])
        Subprocess.expect(command) { mock in
            mock.writeTo(stdout: expectedStdout)
            mock.writeTo(stderr: expectedStderr)
            mock.exit(withStatus: expectedExitCode, reason: .uncaughtSignal)
        }

        // When
        let subprocess = Subprocess(command)
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (process, standardOutput, standardError) in
            XCTAssertEqual(standardOutput, expectedStdout)
            XCTAssertEqual(standardError, expectedStderr)
            XCTAssertEqual(process.terminationReason, .uncaughtSignal)
            XCTAssertEqual(process.exitCode, expectedExitCode)
            terminationExpectation.fulfill()
        }))

        // Then
        wait(for: [terminationExpectation], timeout: 5.0)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }
    
    func testRunhWithWaitUntilExit() async throws {
        // Given
        let expectedExitCode = Int32.random(in: Int32.min...Int32.max)
        let expectedStdout = Data([ UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max) ])
        let expectedStderr = Data([ UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max),
                                    UInt8.random(in: 0...UInt8.max) ])
        Subprocess.expect(command) { mock in
            mock.writeTo(stdout: expectedStdout)
            mock.writeTo(stderr: expectedStderr)
            mock.exit(withStatus: expectedExitCode, reason: .uncaughtSignal)
        }

        // When
        let subprocess = Subprocess(command)
        let (standardOutput, standardError, waitUntilExit) = try subprocess.run()
        async let (stdout, stderr) = (standardOutput, standardError)
        let combinedOutput = await [stdout.data(), stderr.data()]
        
        await waitUntilExit()
        
        XCTAssertEqual(combinedOutput[0], expectedStdout)
        XCTAssertEqual(combinedOutput[1], expectedStderr)
        XCTAssertEqual(subprocess.terminationReason, .uncaughtSignal)
        XCTAssertEqual(subprocess.exitCode, expectedExitCode)

        // Then
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: suspend

    @MainActor func testSuspend() throws {
        // Given
        let semaphore = DispatchSemaphore(value: 0)
        let suspendCalled = expectation(description: "Suspend called")
        Subprocess.expect(command) { mock in
            mock.reference.stubSuspend = {
                suspendCalled.fulfill()
                return true
            }
            semaphore.signal()
        }
        let subprocess = Subprocess(command)
        _ = try subprocess.run()
        semaphore.wait()

        // When
        XCTAssertTrue(subprocess.suspend())

        // Then
        waitForExpectations(timeout: 5.0)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: resume

    @MainActor func testResume() throws {
        // Given
        let semaphore = DispatchSemaphore(value: 0)
        let resumeCalled = expectation(description: "Resume called")
        Subprocess.expect(command) { mock in
            mock.reference.stubResume = {
                resumeCalled.fulfill()
                return true
            }
            semaphore.signal()
        }
        let subprocess = Subprocess(command)
        _ = try subprocess.run()
        semaphore.wait()

        // When
        XCTAssertTrue(subprocess.resume())

        // Then
        waitForExpectations(timeout: 5.0)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: kill

    @MainActor func testKill() throws {
        // Given
        let semaphore = DispatchSemaphore(value: 0)
        let terminateCalled = expectation(description: "Terminate called")
        Subprocess.expect(command) { mock in
            mock.reference.stubTerminate = { _ in
                terminateCalled.fulfill()
            }
            semaphore.signal()
        }
        let subprocess = Subprocess(command)
        _ = try subprocess.run()
        semaphore.wait()

        // When
        XCTAssertTrue(subprocess.isRunning)
        subprocess.kill()

        // Then
        waitForExpectations(timeout: 5.0)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testEnvironmentProperty() {
        // Given
        let subprocess = Subprocess(["/bin/echo"])
        let environmentVariableName = "FOO"
        let environmentVariableValue = "BAR"

        // When
        subprocess.environment = [environmentVariableName: environmentVariableValue]

        // Then
        XCTAssertEqual(subprocess.environment?[environmentVariableName], environmentVariableValue,
                       "The environment property did not store the value correctly.")
    }
    
    // MARK: Data

    func testReturningDataWhenExitCodeIsNoneZero() async {
        // Given
        let exitCode = Int32.random(in: 1...Int32.max)
        let stdoutData = Data("stdout example".utf8)
        let stderrData = Data("stderr example".utf8)
        Subprocess.expect(command, standardOutput: stdoutData, standardError: stderrData, exitCode: exitCode)

        // When
        do {
            _ = try await Subprocess.data(for: command)
        } catch let Subprocess.Error.nonZeroExit(status: status, reason: _, standardOutput: stdout, standardError: stderr) {
            XCTAssertEqual(status, exitCode)
            XCTAssertTrue(stderr.contains("stderr example"))
            XCTAssertEqual(stdoutData, stdout)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Then
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testReturningDataFromStandardOutput() async throws {
        // Given
        let expected = Data([ UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max) ])
        let errorData = Data([ UInt8.random(in: 0...UInt8.max) ])
        Subprocess.expect(command, standardOutput: expected, standardError: errorData)

        // When
        let result = try await Subprocess.data(for: command)

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testReturningDataFromStandardError() async throws {
        // Given
        let expected = Data([ UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max),
                              UInt8.random(in: 0...UInt8.max) ])
        let stdOutData = Data([ UInt8.random(in: 0...UInt8.max) ])
        Subprocess.expect(command, standardOutput: stdOutData, standardError: expected)

        // When
        let result = try await Subprocess.data(for: command, options: .returnStandardError)

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: String

    func testReturningStringWhenExitCodeIsNoneZero() async throws {
        // Given
        let exitCode = Int32.random(in: 1...Int32.max)
        let stdoutText = "should not show up"
        let stderrText = "should show up"
        Subprocess.expect(command, standardOutput: stdoutText, standardError: stderrText, exitCode: exitCode)
        
        // When
        do {
            _ = try await Subprocess.string(for: command)
        } catch let Subprocess.Error.nonZeroExit(status: status, reason: _, standardOutput: stdout, standardError: stderr) {
            XCTAssertEqual(status, exitCode)
            XCTAssertTrue(stderr.contains("should show up"))
            XCTAssertEqual(stdoutText, String(decoding: stdout, as: UTF8.self))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Then
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testReturningStringFromStandardOutput() async throws {
        // Given
        let expected = UUID().uuidString
        Subprocess.expect(command, standardOutput: expected, standardError: UUID().uuidString)

        // When
        let result = try await Subprocess.string(for: command)

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testReturningStringFromStandardError() async throws {
        // Given
        let expected = UUID().uuidString
        Subprocess.expect(command, standardOutput: UUID().uuidString, standardError: expected)

        // When
        let result = try await Subprocess.string(for: command, options: .returnStandardError)

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    // MARK: JSON object

    func testReturningJSONArray() async throws {
        // Given
        let expected: [String] = [
            UUID().uuidString,
            UUID().uuidString
        ]
        
        XCTAssertNoThrow(try Subprocess.expect(command, content: expected, encoder: JSONEncoder()))

        // When
        let result: [String] = try await Subprocess.value(for: command, decoder: JSONDecoder())

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }

    func testExecReturningJSONDictionary() async throws {
        // Given
        let expected: [String: [String: String]] = [
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ],
            UUID().uuidString: [
                UUID().uuidString: UUID().uuidString
            ]
        ]
        XCTAssertNoThrow(try Subprocess.expect(command, content: expected, encoder: JSONEncoder()))

        // When
        let result: [String: [String: String]] = try await Subprocess.value(for: command, decoder: JSONDecoder())

        // Then
        XCTAssertEqual(expected, result)
        Subprocess.verify { XCTFail($0.message, file: $0.file, line: $0.line) }
    }
}
// swiftlint:enable duplicated_key_in_dictionary_literal
