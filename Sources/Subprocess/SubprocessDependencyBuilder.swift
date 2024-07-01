//
//  SubprocessDependencyBuilder.swift
//  Subprocess
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

#if swift(>=6.0)
public import Foundation
#else
import Foundation
#endif

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
    
    /// Creates a `Pipe` and writes the sequence.
    ///
    /// - Parameter sequence: An `AsyncSequence` that supplies data to be written.
    /// - Returns: New `Pipe` instance.
    func makeInputPipe<Input>(sequence: Input) throws -> Pipe where Input : AsyncSequence, Input.Element == UInt8
}

/// Default implementation of SubprocessDependencyFactory
public struct SubprocessDependencyBuilder: SubprocessDependencyFactory {
    private static let queue = DispatchQueue(label: "\(Self.self)")
    nonisolated(unsafe) private static var _shared: any SubprocessDependencyFactory = SubprocessDependencyBuilder()
    /// Shared instance used for dependency creation
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
    
    public func makeInputPipe<Input>(sequence: Input) throws -> Pipe where Input : AsyncSequence & Sendable, Input.Element == UInt8 {
        let pipe = Pipe()
        // see here: https://developer.apple.com/forums/thread/690382
        let result = fcntl(pipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        
        guard result >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(result), userInfo: nil)
        }
        
        pipe.fileHandleForWriting.writeabilityHandler = { handle in
            handle.writeabilityHandler = nil

            Task {
                defer {
                    try? handle.close()
                }
                
                // `DispatchIO` seems like an interesting solution but doesn't seem to mesh well with async/await, perhaps there will be updates in this area in the future.
                // https://developer.apple.com/forums/thread/690310
                // According to Swift forum talk byte by byte reads _could_ be optimized by the compiler depending on how much visibility it has into methods.
                for try await byte in sequence {
                    try handle.write(contentsOf: [byte])
                }
            }
        }
        
        return pipe
    }
}
