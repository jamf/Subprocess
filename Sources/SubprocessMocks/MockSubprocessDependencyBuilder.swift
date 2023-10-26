//
//  MockSubprocessDependencyBuilder.swift
//  SubprocessMocks
//
//  MIT License
//
//  Copyright (c) 2023 Jamf
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
#if !COCOA_PODS
import Subprocess
#endif

/// Error representing a failed call to Subprocess.expect or Shell.expect
public struct ExpectationError: Error {
    /// Source file where expect was called
    public var file: StaticString
    /// Line number where expect was called
    public var line: UInt
    /// Error message
    public var message: String
}

/// Type representing possible errors thrown
public enum MockSubprocessError: Error {
    /// Error containing command thrown when a process is launched that was not stubbed
    case missingMock([String])
    /// List of expectations which failed
    case missedExpectations([ExpectationError])
}

public protocol SubprocessMockObject {}

public extension SubprocessMockObject {

    /// Verifies expected stubs and resets mocking
    /// - Throws: A `MockSubprocessError.missedExpectations` containing failed expectations
    static func verify() throws { try MockSubprocessDependencyBuilder.shared.verify() }

    /// Verifies expected stubs and resets mocking
    /// - Parameter missedBlock: Block called for each failed expectation
    static func verify(missedBlock: (ExpectationError) -> Void) {
        MockSubprocessDependencyBuilder.shared.verify(missedBlock: missedBlock)
    }

    /// Resets mocking
    static func reset() { MockSubprocessDependencyBuilder.shared.reset() }
}

public class MockFileHandle: FileHandle {
    public var url: URL?
}

public final class MockPipe: Pipe {
    private static let queue = DispatchQueue(label: "\(MockPipe.self)")
    private var _data: Data?
    public var data: Data? {
        get {
            Self.queue.sync {
                _data
            }
        }
        set {
            Self.queue.sync {
                _data = newValue
            }
        }
    }
}

class MockSubprocessDependencyBuilder {

    class MockItem {
        var used = false
        var command: [String]
        var input: Input?
        var process: MockProcessReference
        var file: StaticString?
        var line: UInt?
        
        init(command: [String], input: Input?, process: MockProcessReference, file: StaticString?, line: UInt?) {
            self.command = command
            self.input = input
            self.process = process
            self.file = file
            self.line = line
        }
    }

    var mocks: [MockItem] = []

    static let shared = MockSubprocessDependencyBuilder()

    init() { SubprocessDependencyBuilder.shared = self }

    func stub(_ command: [String], process: MockProcessReference) {
        let mock = MockItem(command: command, input: nil, process: process, file: nil, line: nil)
        mocks.append(mock)
    }

    func expect(_ command: [String], input: Input?, process: MockProcessReference, file: StaticString, line: UInt) {
        let mock = MockItem(command: command, input: input, process: process, file: file, line: line)
        mocks.append(mock)
    }

    func verify(missedBlock block: (ExpectationError) -> Void) {
        defer { reset() }
        // All of the mocks for errors
        mocks.forEach {
            // Check if the file and line properties were set, this indicates it was an expected mock
            guard let file = $0.file, let line = $0.line else { return }

            // Check if the mock was used
            guard $0.used else { return block(ExpectationError(file: file, line: line, message: "Command not called")) }

            // Check the expected input
            let expectedData: Data?
            let expectedFile: URL?
            
            switch $0.input?.value {
            case .data(let data):
                expectedData = data
                expectedFile = nil
            case .text(let string):
                expectedData = Data(string.utf8)
                expectedFile = nil
            case .file(let url):
                expectedData = nil
                expectedFile = url
            default:
                expectedData = nil
                expectedFile = nil
            }

            let inputFile: URL? = ($0.process.standardInput as? MockFileHandle)?.url
            let inputData: Data? = ($0.process.standardInput as? MockPipe)?.data

            let fileError = verifyInputFile(inputURL: inputFile, expectedURL: expectedFile, file: file, line: line)
            if let error = fileError { return block(error) }

            let dataError = verifyInputData(inputData: inputData, expectedData: expectedData, file: file, line: line)
            guard let error = dataError else { return }
            block(error)
        }
    }

    private func verifyInputFile(inputURL: URL?,
                                 expectedURL: URL?,
                                 file: StaticString,
                                 line: UInt) -> ExpectationError? {
        if let expected = expectedURL {
            if let url = inputURL {
                if expected != url {
                    return ExpectationError(file: file,
                                            line: line,
                                            message: "Input file URLs do not match \(expected) != \(url)")
                }
            } else {
                return ExpectationError(file: file, line: line, message: "Missing file input")
            }
        } else if let url = inputURL {
            return ExpectationError(file: file, line: line, message: "Unexpected input file \(url)")
        }
        return nil
    }

    private func verifyInputData(inputData: Data?,
                                 expectedData: Data?,
                                 file: StaticString,
                                 line: UInt) -> ExpectationError? {
        if let expectedData = expectedData {
            if let inputData = inputData {
                if inputData != expectedData {
                    if let input = String(data: inputData, encoding: .utf8),
                        let expected = String(data: inputData, encoding: .utf8) {
                        let errorText = "Input text does not match expected input text \(input) != \(expected)"
                        return ExpectationError(file: file,
                                                line: line,
                                                message: errorText)
                    } else {
                        return ExpectationError(file: file,
                                                line: line,
                                                message: "Input data does not match expected input data")
                    }
                }
            } else {
                return ExpectationError(file: file, line: line, message: "Missing data input")
            }
        } else if let unexpectedData = inputData {
            if let input = String(data: unexpectedData, encoding: .utf8) {
                return ExpectationError(file: file, line: line, message: "Unexpected input text: \(input)")
            } else {
                return ExpectationError(file: file, line: line, message: "Unexpected input data")
            }
        }
        return nil
    }

    func verify() throws {
        var errors: [ExpectationError] = []
        verify { errors.append($0) }
        if errors.isEmpty { return }
        throw MockSubprocessError.missedExpectations(errors)
    }

    func reset() {
        mocks = []
    }
}

extension MockSubprocessDependencyBuilder: SubprocessDependencyFactory {
    func makeProcess(command: [String]) -> Process {
        if let item = mocks.first(where: { !$0.used && $0.command == command }) {
            item.used = true
            return item.process
        }
        return MockProcessReference(withRunError: MockSubprocessError.missingMock(command))
    }

    func makeInputFileHandle(url: URL) throws -> FileHandle {
        let handle = MockFileHandle()
        handle.url = url
        return handle
    }
    
    func makeInputPipe<Input>(sequence: Input) throws -> Pipe where Input : AsyncSequence, Input.Element == UInt8 {
        let semaphore = DispatchSemaphore(value: 0)
        let pipe = MockPipe()
        
        Task {
            pipe.data = try await sequence.data()
            semaphore.signal()
        }
        
        semaphore.wait()
        return pipe
    }
}
