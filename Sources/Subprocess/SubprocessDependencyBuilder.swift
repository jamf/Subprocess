//
//  SubprocessDependencyBuilder.swift
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

/// Protocol call used for dependency injection
public protocol SubprocessDependencyFactory {
    /// Creates new Subprocess
    ///
    /// - Parameter command: Command represented as an array of strings
    /// - Returns: New Subprocess instance
    func makeProcess(command: [String]) -> Process

    /// Creates a FileHandle for reading
    ///
    /// - Parameter url: File URL
    /// - Returns: New FileHandle for reading
    /// - Throws: When unable to open file for reading
    func makeInputFileHandle(url: URL) throws -> FileHandle

    /// Creates a Pipe and writes given data
    ///
    /// - Parameter data: Data to write to the Pipe
    /// - Returns: New Pipe instance
    func makeInputPipe(data: Data) -> Pipe
}

/// Default implementation of SubprocessDependencyFactory
public struct SubprocessDependencyBuilder: SubprocessDependencyFactory {
    private static let queue = DispatchQueue(label: "\(Self.self)")
    private static var _shared: any SubprocessDependencyFactory = SubprocessDependencyBuilder()
    /// Shared instance used for dependency creatation
    public static var shared: any SubprocessDependencyFactory {
        get {
            queue.sync {
                _shared
            }
        }
        set {
            queue.sync {
                _shared = newValue
            }
        }
    }

    public func makeProcess(command: [String]) -> Process {
        var tmp = command
        let process = Process()
        
        process.executableURL = URL(fileURLWithPath: tmp.removeFirst())
        process.arguments = tmp
        return process
    }

    public func makeInputFileHandle(url: URL) throws -> FileHandle {
        return try FileHandle(forReadingFrom: url)
    }

    public func makeInputPipe(data: Data) -> Pipe {
        let pipe = Pipe()
        pipe.fileHandleForWriting.writeabilityHandler = { handle in
            handle.write(data)
            handle.writeabilityHandler = nil
            try? handle.close()
        }
        return pipe
    }
}
