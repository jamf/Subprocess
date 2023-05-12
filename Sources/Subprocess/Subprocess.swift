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

    /// Process reference
    let reference: Process

    /// Process identifier
    public var pid: Int32 { reference.processIdentifier }

    /// Exit code of the process
    public var exitCode: Int32 { reference.terminationStatus }

    /// Returns whether the process is still running.
    public var isRunning: Bool { reference.isRunning }

    /// Reason for process termination
    public var terminationReason: Process.TerminationReason { reference.terminationReason }

    /// Reference environment property
    public var environment: [String: String]? {
        get {
            reference.environment
        }
        set {
            reference.environment = newValue
        }
    }

    /// Creates new Subprocess
    ///
    /// - Parameter command: Command represented as an array of strings
    public init(_ command: [String], qos: DispatchQoS = .default) {
        reference = SubprocessDependencyBuilder.shared.makeProcess(command: command)
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
                       terminationHandler: ((Subprocess) -> Void)? = nil) throws {

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
            terminationHandler?(self)
        }

        if #available(OSX 10.13, *) {
            try reference.run()
        } else {
            reference.launch()
        }
    }

    /// Block type called for executing process returning data from standard out and standard error
    public typealias DataTerminationHandler = (_ process: Subprocess, _ stdout: Data, _ stderr: Data) -> Void

    /// Launches command calling a block when process terminates
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process
    ///     - terminationHandler: Block called with Subprocess, stdout Data, stderr Data
    public func launch(input: Input? = nil,
                       terminationHandler: @escaping DataTerminationHandler) throws {
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
    public func waitForTermination() {
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
