//
//  Input.swift
//  Subprocess
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

/// Interface representing into to the process
public struct Input {

    /// Reference to the input value
    public enum Value {

        /// Data to be written to stdin of the child process
        case data(Data)

        /// Text to be written to stdin of the child process
        case text(String, String.Encoding)

        /// File to be written to stdin of the child process
        case file(URL)
    }

    /// Reference to the input value
    public let value: Value

    /// Creates input for writing data to stdin of the child process
    /// - Parameter data: Data written to stdin of the child process
    /// - Returns: New Input instance
    public static func data(_ data: Data) -> Input {
        return Input(value: .data(data))
    }

    /// Creates input for writing text to stdin of the child process
    /// - Parameter text: Text written to stdin of the child process
    /// - Returns: New Input instance
    public static func text(_ text: String, encoding: String.Encoding = .utf8) -> Input {
        return Input(value: .text(text, encoding))
    }

    /// Creates input for writing contents of file at path to stdin of the child process
    /// - Parameter path: Path to file written to stdin of the child process
    /// - Returns: New Input instance
    public static func file(path: String) -> Input {
        return Input(value: .file(URL(fileURLWithPath: path)))
    }

    /// Creates input for writing contents of file URL to stdin of the child process
    /// - Parameter url: URL for file written to stdin of the child process
    /// - Returns: New Input instance
    public static func file(url: URL) -> Input {
        return Input(value: .file(url))
    }

    /// Creates file handle or pipe for given input
    /// - Returns: New FileHandle or Pipe
    func createPipeOrFileHandle() throws -> Any {
        switch value {
        case .data(let data):
            return SubprocessDependencyBuilder.shared.makeInputPipe(data: data)
        case .text(let text, let encoding):
            guard let data = text.data(using: encoding) else { throw SubprocessError.inputStringEncodingError }
            return SubprocessDependencyBuilder.shared.makeInputPipe(data: data)
        case .file(let url):
            return try SubprocessDependencyBuilder.shared.makeInputFileHandle(url: url)
        }
    }
}
