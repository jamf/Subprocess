//
//  MockShell.swift
//  SubprocessMocks
//
//  MIT License
//
//  Copyright (c) 2018 Jamf Software
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

extension Shell: SubprocessMockObject {}

public extension Shell {

    /// Adds a mock for a command which throws an error when `Process.run` is called
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - error: Error thrown when `Process.run` is called
    static func stub(_ command: [String], error: Error) {
        Subprocess.stub(command, error: error)
    }

    /// Adds a mock for a command which writes the given data to the outputs and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - standardOutput: Data written to stdout of the process
    ///     - standardError: Data written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    static func stub(_ command: [String],
                     standardOutput: Data? = nil,
                     standardError: Data? = nil,
                     exitCode: Int32 = 0) {
        Subprocess.stub(command) { process in
            if let data = standardOutput {
                process.writeTo(stdout: data)
            }
            if let data = standardError {
                process.writeTo(stderr: data)
            }
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds a mock for a command which writes the given text to the outputs and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - stdout: String written to stdout of the process
    ///     - stderr: String written to stderr of the process (Default: nil)
    ///     - exitCode: Exit code of the process (Default: 0)
    static func stub(_ command: [String],
                     stdout: String,
                     stderr: String? = nil,
                     exitCode: Int32 = 0) {
        Subprocess.stub(command) { process in
            process.writeTo(stdout: stdout)
            if let text = stderr {
                process.writeTo(stderr: text)
            }
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds a mock for a command which writes the given text to stderr and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - stdout: String written to stdout of the process
    ///     - stderr: String written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    static func stub(_ command: [String],
                     stderr: String,
                     exitCode: Int32 = 0) {
        Subprocess.stub(command) { process in
            process.writeTo(stderr: stderr)
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds a mock for a command which writes the given property list to stdout and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - plist: Property list object serialized and written to stdout
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when serializing property list object
    static func stub(_ command: [String],
                     plist: Any,
                     exitCode: Int32 = 0) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        Shell.stub(command, standardOutput: data, exitCode: exitCode)
    }

    /// Adds a mock for a command which writes the given JSON object to stdout and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - plist: JSON object serialized and written to stdout
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when serializing JSON object
    static func stub(_ command: [String],
                     json: Any,
                     exitCode: Int32 = 0) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        Shell.stub(command, standardOutput: data, exitCode: exitCode)
    }

    /// Adds a mock for a command which writes the given encodable object as a property list to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - plistObject: Encodable object written to stdout as a property list
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when encoding the provided object
    static func stub<T: Encodable>(_ command: [String],
                                   plistObject: T,
                                   exitCode: Int32 = 0) throws {
        let data = try PropertyListEncoder().encode(plistObject)
        Shell.stub(command, standardOutput: data, exitCode: exitCode)
    }

    /// Adds a mock for a command which writes the given encodable object as JSON to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - jsonObject: Encodable object written to stdout as JSON
    ///     - exitCode: Exit code of the process (Default: 0)
    /// - Throws: Error when encoding the provided object
    static func stub<T: Encodable>(_ command: [String],
                                   jsonObject: T,
                                   exitCode: Int32 = 0) throws {
        let data = try JSONEncoder().encode(jsonObject)
        Shell.stub(command, standardOutput: data, exitCode: exitCode)
    }

    // MARK: -

    /// Adds an expected mock for a command which throws an error when `Process.run` is called
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - error: Error thrown when `Process.run` is called
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    static func expect(_ command: [String],
                       input: Input? = nil,
                       error: Error,
                       file: StaticString = #file,
                       line: UInt = #line) {
        Subprocess.expect(command, input: input, error: error, file: file, line: line)
    }

    /// Adds an expected mock for a command which writes the given data to the outputs
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - standardOutput: Data written to stdout of the process
    ///     - standardError: Data written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    static func expect(_ command: [String],
                       input: Input? = nil,
                       standardOutput: Data? = nil,
                       standardError: Data? = nil,
                       exitCode: Int32 = 0,
                       file: StaticString = #file,
                       line: UInt = #line) {
        Subprocess.expect(command, input: input, file: file, line: line) { process in
            if let data = standardOutput {
                process.writeTo(stdout: data)
            }
            if let data = standardError {
                process.writeTo(stderr: data)
            }
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds an expected mock for a command which writes the given text to the outputs
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - stdout: String written to stdout of the process
    ///     - stderr: String written to stderr of the process (Default: nil)
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    static func expect(_ command: [String],
                       input: Input? = nil,
                       stdout: String,
                       stderr: String? = nil,
                       exitCode: Int32 = 0,
                       file: StaticString = #file,
                       line: UInt = #line) {
        Subprocess.expect(command, input: input, file: file, line: line) { process in
            process.writeTo(stdout: stdout)
            if let text = stderr {
                process.writeTo(stderr: text)
            }
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds an expected mock for a command which writes the given text to stderr and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - stdout: String written to stdout of the process
    ///     - stderr: String written to stderr of the process
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    static func expect(_ command: [String],
                       input: Input? = nil,
                       stderr: String,
                       exitCode: Int32 = 0,
                       file: StaticString = #file,
                       line: UInt = #line) {
        Subprocess.expect(command, input: input, file: file, line: line) { process in
            process.writeTo(stderr: stderr)
            process.exit(withStatus: exitCode)
        }
    }

    /// Adds an expected mock for a command which writes the given property list to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - plist: Property list object serialized and written to stdout
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    /// - Throws: Error when serializing property list object
    static func expect(_ command: [String],
                       input: Input? = nil,
                       plist: Any,
                       exitCode: Int32 = 0,
                       file: StaticString = #file,
                       line: UInt = #line) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        Shell.expect(command, input: input, standardOutput: data, exitCode: exitCode, file: file, line: line)
    }

    /// Adds an expected mock for a command which writes the given JSON object to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - plist: JSON object serialized and written to stdout
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    /// - Throws: Error when serializing JSON object
    static func expect(_ command: [String],
                       input: Input? = nil,
                       json: Any,
                       exitCode: Int32 = 0,
                       file: StaticString = #file,
                       line: UInt = #line) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        Shell.expect(command, input: input, standardOutput: data, exitCode: exitCode, file: file, line: line)
    }

    /// Adds an expected mock for a command which writes the given encodable object as a property list to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - plistObject: Encodable object written to stdout as a property list
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    /// - Throws: Error when encoding the provided object
    static func expect<T: Encodable>(_ command: [String],
                                     input: Input? = nil,
                                     plistObject: T,
                                     exitCode: Int32 = 0,
                                     file: StaticString = #file,
                                     line: UInt = #line) throws {
        let data = try PropertyListEncoder().encode(plistObject)
        Shell.expect(command, input: input, standardOutput: data, exitCode: exitCode, file: file, line: line)
    }

    /// Adds an expected mock for a command which writes the given encodable object as JSON to stdout
    /// and exits with the provided exit code
    ///
    /// - Parameters:
    ///     - command: The command to mock
    ///     - input: The expected input of the process
    ///     - jsonObject: Encodable object written to stdout as JSON
    ///     - exitCode: Exit code of the process (Default: 0)
    ///     - file: Source file where expect was called (Default: #file)
    ///     - line: Line number of source file where expect was called (Default: #line)
    /// - Throws: Error when encoding the provided object
    static func expect<T: Encodable>(_ command: [String],
                                     input: Input? = nil,
                                     jsonObject: T,
                                     exitCode: Int32 = 0,
                                     file: StaticString = #file,
                                     line: UInt = #line) throws {
        let data = try JSONEncoder().encode(jsonObject)
        Shell.expect(command, input: input, standardOutput: data, exitCode: exitCode, file: file, line: line)
    }
}
