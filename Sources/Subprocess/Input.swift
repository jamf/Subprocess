//
//  Input.swift
//  Subprocess
//
//  Created by Cyrus Ingraham on 3/9/20.
//  Copyright © 2020 Jamf. All rights reserved.
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
            return SubprocessDependencyBuilder.shared.createInputPipe(for: data)
        case .text(let text, let encoding):
            guard let data = text.data(using: encoding) else { throw SubprocessError.inputStringEncodingError }
            return SubprocessDependencyBuilder.shared.createInputPipe(for: data)
        case .file(let url):
            return try SubprocessDependencyBuilder.shared.createInputFileHandle(for: url)
        }
    }
}
