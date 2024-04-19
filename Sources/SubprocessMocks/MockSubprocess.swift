//
//  MockSubprocess.swift
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
import Combine
#if !COCOA_PODS
import Subprocess
#endif

extension Subprocess: SubprocessMockObject {}

public extension Subprocess {

    /// Adds a mock for a given command which throws an error when `Process.run` is called
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - error: Error thrown when `Process.run` is called
    static func stub(_ command: [String], error: any Swift.Error) {
        let mock = MockProcessReference(withRunError: error)
        MockSubprocessDependencyBuilder.shared.stub(command, process: mock)
    }

    /// Adds a mock for a given command which calls the run block to mock process execution
    ///
    /// - Important: You must call`MockProcess.exit` for the process to complete
    /// - Parameters:
    ///     - command: The command to mock
    ///     - runBlock: Block called with a `MockProcess` to mock process execution.
    static func stub(_ command: [String], runBlock: (@Sendable (MockProcess) -> Void)? = nil) {
        let mock = MockProcessReference(withRunBlock: runBlock ?? { $0.exit() })
        MockSubprocessDependencyBuilder.shared.stub(command, process: mock)
    }
    
    /// Adds a mock for a command which writes the given data to the outputs and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - standardOutput: Data written to stdout of the process
    ///     - standardError: Data written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    static func stub(_ command: [String], standardOutput: (any MockOutput)? = nil, standardError: (any MockOutput)? = nil, exitCode: Int32 = 0) {
        stub(command) { process in
            if let data = standardOutput {
                process.writeTo(stdout: data)
            }
            
            if let data = standardError {
                process.writeTo(stderr: data)
            }
            
            process.exit(withStatus: exitCode)
        }
    }
    
    /// Adds a mock for a command which writes the given encodable object as JSON to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - content: Encodable object written to stdout
    ///     - encoder: `TopLevelEncoder` used to encoder `content` into `Data`.
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when encoding the provided object
    static func stub<Content, Encoder>(_ command: [String], content: Content, encoder: Encoder, exitCode: Int32 = 0) throws where Content : Encodable, Encoder : TopLevelEncoder, Encoder.Output == Data {
        let data: Data = try encoder.encode(content)
        
        stub(command, standardOutput: data, exitCode: exitCode)
    }
    
    // MARK: -

    /// Adds an expected mock for a given command which throws an error when `Process.run` is called
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - error: Error thrown when `Process.run` is called
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    static func expect(_ command: [String], input: Input? = nil, error: any Swift.Error, file: StaticString = #file, line: UInt = #line) {
        let mock = MockProcessReference(withRunError: error)
        MockSubprocessDependencyBuilder.shared.expect(command, input: input, process: mock, file: file, line: line)
    }

    /// Adds an expected mock for a given command which calls the run block to mock process execution
    ///
    /// - Important: You must call`MockProcess.exit` for the process to complete
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    ///     - runBlock: Block called with a `MockProcess` to mock process execution
    static func expect(_ command: [String], input: Input? = nil, file: StaticString = #file, line: UInt = #line, runBlock: (@Sendable (MockProcess) -> Void)? = nil) {
        let mock = MockProcessReference(withRunBlock: runBlock ?? { $0.exit() })
        MockSubprocessDependencyBuilder.shared.expect(command, input: input, process: mock, file: file, line: line)
    }
    
    /// Adds a mock for a command which writes the given data to the outputs and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - standardOutput: Data written to stdout of the process
    ///     - standardError: Data written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    static func expect(_ command: [String], standardOutput: (any MockOutput)? = nil, standardError: (any MockOutput)? = nil, input: Input? = nil, exitCode: Int32 = 0, file: StaticString = #file, line: UInt = #line) {
        expect(command, input: input, file: file, line: line) { process in
            if let data = standardOutput {
                process.writeTo(stdout: data)
            }
            
            if let data = standardError {
                process.writeTo(stderr: data)
            }
            
            process.exit(withStatus: exitCode)
        }
    }
    
    /// Adds a mock for a command which writes the given encodable object as JSON to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - content: Encodable object written to stdout
    ///     - encoder: `TopLevelEncoder` used to encoder `content` into `Data`.
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when encoding the provided object
    static func expect<Content, Encoder>(_ command: [String], content: Content, encoder: Encoder, input: Input? = nil, exitCode: Int32 = 0, file: StaticString = #file, line: UInt = #line) throws where Content : Encodable, Encoder : TopLevelEncoder, Encoder.Output == Data {
        let data: Data = try encoder.encode(content)
        
        expect(command, standardOutput: data, input: input, exitCode: exitCode, file: file, line: line)
    }
}
