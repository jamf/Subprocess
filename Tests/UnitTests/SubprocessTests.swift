import XCTest
@testable import Subprocess
import SubprocessMocks

final class SubprocessTests: XCTestCase {
    static var allTests = [
        ("testInputData", testInputData),
        ("testInputText", testInputText),
        ("testInputFilePath", testInputFilePath),
        ("testInputFileURL", testInputFileURL),
        
        ("testGetPID", testGetPID),
        
        ("testLaunchWithTerminationHandler", testLaunchWithTerminationHandler),
        
        ("testSuspend", testSuspend),
        
        ("testResume", testResume),
        
        ("testKill", testKill)
    ]
    
    let command = [ "/usr/local/bin/somefakeCommand", "foo", "bar",  ]

    override func tearDown() {
        Subprocess.reset()
    }
    
    // MARK: Input
    
    func testInputData() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = Data([ UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max)  ])

        // When
        let input = Subprocess.Input.data(expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())
        
        // Then
        switch input.value {
        case .data(let data): XCTAssertEqual(data, expected)
        default: XCTFail()
        }
        guard let pipe = pipeOrFileHandle as? MockPipe else { return XCTFail() }
        XCTAssertEqual(pipe.data, expected)
    }
    
    func testInputText() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = UUID().uuidString

        // When
        let input = Subprocess.Input.text(expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .text(let text, let encoding):
            XCTAssertEqual(text, expected)
            XCTAssertEqual(encoding, .utf8)
        default: XCTFail()
        }
        guard let pipe = pipeOrFileHandle as? MockPipe else { return XCTFail() }
        guard let data = pipe.data, let text = String(data: data, encoding: .utf8) else { return XCTFail() }
        XCTAssertEqual(text, expected)
    }
    
    func testInputFilePath() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = "/some/fake/path/\(UUID().uuidString)"

        // When
        let input = Subprocess.Input.file(path: expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .file(let url): XCTAssertEqual(url.path, expected)
        default: XCTFail()
        }
        guard let pipe = pipeOrFileHandle as? MockFileHandle else { return XCTFail() }
        XCTAssertEqual(pipe.url?.path, expected)
    }
    
    func testInputFileURL() {
        // Given
        var pipeOrFileHandle: Any?
        let expected = URL(fileURLWithPath: "/some/fake/path/\(UUID().uuidString)")

        // When
        let input = Subprocess.Input.file(url: expected)
        XCTAssertNoThrow(pipeOrFileHandle = try input.createPipeOrFileHandle())

        // Then
        switch input.value {
        case .file(let url): XCTAssertEqual(url, expected)
        default: XCTFail()
        }
        guard let pipe = pipeOrFileHandle as? MockFileHandle else { return XCTFail() }
        XCTAssertEqual(pipe.url, expected)
    }

    // MARK: PID
    
    func testGetPID() {
        // Given
        let mockCalled = expectation(description: "Mock setup called")
        var expectedPID: Int32?
        Subprocess.expect(command) { mock in
            expectedPID = mock.reference.processIdentifier
            mockCalled.fulfill()
        }
        
        // When
        let subprocess = Subprocess(command)
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (_, _, _) in }))
        
        // Then
        waitForExpectations(timeout: 5.0) { _ in
            XCTAssertEqual(subprocess.pid, expectedPID)
        }
    }
    
    // MARK: launch with termination handler
    
    func testLaunchWithTerminationHandler() {
        // Given
        let terminationExpectation = expectation(description: "Termination block called")
        let expectedExitCode = Int32.random(in: Int32.min...Int32.max)
        let expectedStdout = Data([ UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max)  ])
        let expectedStderr = Data([ UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max),  UInt8.random(in: 0...UInt8.max)  ])
        Subprocess.expect(command) { mock in
            mock.writeTo(stdout: expectedStdout)
            mock.writeTo(stderr: expectedStderr)
            mock.exit(withStatus: expectedExitCode, reason: .uncaughtSignal)
        }
        
        // When
        let subprocess = Subprocess(command)
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (process, standardOutput, standardError) in
            XCTAssertEqual(standardOutput, expectedStdout)
            XCTAssertEqual(standardOutput, expectedStdout)
            XCTAssertEqual(process.terminationReason, .uncaughtSignal)
            XCTAssertEqual(process.exitCode, expectedExitCode)
            terminationExpectation.fulfill()
        }))
        

        // Then
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: suspend
    
    func testSuspend() {
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
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (_, _, _) in }))
        semaphore.wait()
        
        // When
        XCTAssertTrue(subprocess.suspend())
        
        // Then
        waitForExpectations(timeout: 5.0)
    }

    // MARK: resume
    
    func testResume() {
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
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (_, _, _) in }))
        semaphore.wait()

        // When
        XCTAssertTrue(subprocess.resume())
        
        // Then
        waitForExpectations(timeout: 5.0)
    }

    // MARK: kill
    
    func testKill() {
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
        XCTAssertNoThrow(try subprocess.launch(terminationHandler: { (_, _, _) in }))
        semaphore.wait()

        // When
        XCTAssertTrue(subprocess.isRunning)
        subprocess.kill()
        
        // Then
        waitForExpectations(timeout: 5.0)
    }
}
