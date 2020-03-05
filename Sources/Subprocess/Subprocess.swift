//
//  Subprocess.swift
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

/// Class used for asynchronous process execution
open class Subprocess {
    
    /// Interface representing into to the process
    public struct Input {
        
        /// Reference to the input value
        public enum Value {
            
            /// Data to be written to stdin of the child process
            case data(Data)
            
            /// Data to be written to stdin of the child process
            case text(String, String.Encoding)
            
            /// File to be written to stdin of the child process
            case file(URL)
        }
        
        /// Reference to the input value
        public var value: Value
        
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
                return SubprocessManager.shared.createInputPipe(for: data)
            case .text(let text, let encoding):
                guard let data = text.data(using: encoding) else { throw SubprocessError.inputStringEncodingError }
                return SubprocessManager.shared.createInputPipe(for: data)
            case .file(let url):
                return try SubprocessManager.shared.createInputFileHandle(for: url)
            }
        }
    }
    
    /// Process reference
    public let reference: Process

    /// Process identifier
    public var pid: Int32 { reference.processIdentifier }
    
    /// Exit code of the process
    public var exitCode: Int32 { reference.terminationStatus }
    
    public var isRunning: Bool { reference.isRunning }
    
    /// Reason for process termination
    public var terminationReason: Process.TerminationReason { reference.terminationReason }
    
    /// Creates new Subprocess
    ///
    /// - Parameter command: Command represented as an array of strings
    public init(_ command: [String], qos: DispatchQoS = .default) {
        reference = SubprocessManager.shared.createProcess(for: command)
        queue = DispatchQueue(label: "SubprocessQueue",
                              qos: qos,
                              attributes: [],
                              autoreleaseFrequency: .workItem,
                              target: nil)
        
    }
    
    /// Launches command with read handlers and termination handler
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process
    ///     - outputHandler: Block called whenever new data is read from standard output of the process
    ///     - errorHandler: Block called whenever new data is read from standard error of the process
    ///     - terminationHandler: Block called when process has terminated and all output handlers have returned
    public func launch(input: Input? = nil,
                       outputHandler: ((Data) -> Void)? = nil,
                       errorHandler: ((Data) -> Void)? = nil,
                       terminationHandler: @escaping (Subprocess) -> Void) throws {
        
        reference.standardInput = try input?.createPipeOrFileHandle()
        
        if let handler = outputHandler {
            reference.standardOutput = createPipeWithReadabilityHandler(handler)
        } else {
            reference.standardOutput = FileHandle.nullDevice
        }

        if let handler = errorHandler {
            reference.standardError = createPipeWithReadabilityHandler(handler)
        } else {
            reference.standardError = FileHandle.nullDevice
        }

        group.enter()
        reference.terminationHandler = { [weak self] _ in
            self?.group.leave()
            self?.reference.terminationHandler = nil
        }
        
        group.notify(queue: queue) {
            terminationHandler(self)
        }
        
        try reference.run()
    }
    
    /// Launches command calling a block when process terminates
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process
    ///     - terminationHandler: Block called with Subprocess, stdout Data, stderr Data
    public func launch(input: Input? = nil, terminationHandler: @escaping (_ process: Subprocess, _ standardOutput: Data, _ standardError: Data) -> Void) throws {
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        try launch(input: input, outputHandler: { data in
            stdoutBuffer.append(data)
        }, errorHandler: { data in
            stderrBuffer.append(data)
        }, terminationHandler: { selfRef in
            terminationHandler(selfRef, stdoutBuffer, stderrBuffer)
        })
    }
    
    /// Suspends the command
    public func suspend() -> Bool {
        return reference.suspend()
    }

    /// Resumes the command which was suspended
    public func resume() -> Bool {
        return reference.resume()
    }

    /// Sends the command the term signal
    public func kill() {
        reference.terminate()
    }

    /// Waits for process to complete and all handlers to be called
    public func waitForTermaination() {
        group.wait()
    }
    
    private let group = DispatchGroup()
    private let queue: DispatchQueue
    
    private func createPipeWithReadabilityHandler(_ handler: @escaping (Data) -> Void) -> Pipe {
        let pipe = Pipe()
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                self.queue.async { self.group.leave() }
                handle.readabilityHandler = nil
            } else {
                self.queue.async { handler(data) }
            }
        }
        return pipe
    }
}
