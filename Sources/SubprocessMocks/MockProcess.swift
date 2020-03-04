//
//  MockProcess.swift
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
import Subprocess

/// Interface used for mocking a process
public struct MockProcess {
    
    /// The underlying `MockProcessReference`
    public var reference: MockProcessReference
    
    /// Writes given data to standard out of the mock child process
    /// - Parameter data: Data to write to standard out of the mock child process
    public func writeTo(stdout data: Data) {
        reference.standardOutputPipe?.fileHandleForWriting.write(data)
    }
    
    /// Writes given text to standard out of the mock child process
    /// - Parameter text: Text to write to standard out of the mock child process
    public func writeTo(stdout text: String, encoding: String.Encoding = .utf8) {
        guard let data = text.data(using: encoding) else { return }
        reference.standardOutputPipe?.fileHandleForWriting.write(data)
    }
    
    /// Writes given data to standard error of the mock child process
    /// - Parameter data: Data to write to standard error of the mock child process
    public func writeTo(stderr data: Data) {
        reference.standardErrorPipe?.fileHandleForWriting.write(data)
    }
    
    /// Writes given text to standard error of the mock child process
    /// - Parameter text: Text to write to standard error of the mock child process
    public func writeTo(stderr text: String, encoding: String.Encoding = .utf8) {
        guard let data = text.data(using: encoding) else { return }
        reference.standardErrorPipe?.fileHandleForWriting.write(data)
    }
    
    /// Completes the mock process execution
    /// - Parameters:
    ///     - statusCode: Exit code of the process (Default: 0)
    ///     - reason: Termination reason of the process (Default: .exit)
    public func exit(withStatus statusCode: Int32 = 0, reason: Process.TerminationReason = .exit) {
        reference.exit(withStatus: statusCode, reason: reason)
    }
}

/// Subclass of `Process` used for mocking
open class MockProcessReference: Process {
    
    /// Context information and values used for overriden properties
    public struct Context {
        
        /// State of the mock process
        public enum State {
            case initialized
            case running
            case uncaughtSignal
            case exited
        }
        public var terminationStatus: Int32 = 0
        public var processIdentifier: Int32 = -1
        public var state: State = .initialized
        
        /// Block called to stub the call to launch
        public var runStub: (MockProcess) throws -> Void
    }

    public var context: Context
    
    
    /// Creates a new `MockProcessReference` which throws an error on launch
    /// - Parameter error: Error thrown when `Process.run` is called
    public init(withRunError error: Error) {
        context = Context(runStub: { _ in throw error })
    }
    
    /// Creates a new `MockProcessReference` calling run stub block
    /// - Parameter block: Block used to stub `Process.run`
    public init(withRunBlock block: @escaping (MockProcess) -> Void) {
        context = Context(runStub: { mock in
            DispatchQueue.global(qos: .userInitiated).async {
                block(mock)
            }
        })
    }
    
    /// Block called when `Process.terminate` is called
    public var stubTerminate: ((MockProcessReference) -> Void)?
    
    /// Block called when `Process.resume` is called
    public var stubResume: (() -> Bool)?
    
    /// Block called when `Process.suspend` is called
    public var stubSuspend: (() -> Bool)?

    /// standardOutput object as a Pipe
    public var standardOutputPipe: Pipe? { standardOutput as? Pipe }
    
    /// standardError object as a Pipe
    public var standardErrorPipe: Pipe? { standardError as? Pipe }

    /// Completes the mock process execution
    /// - Parameters:
    ///     - statusCode: Exit code of the process (Default: 0)
    ///     - reason: Termination reason of the process (Default: .exit)
    public func exit(withStatus statusCode: Int32 = 0, reason: Process.TerminationReason = .exit) {
        guard context.state == .running else { return }
        context.state = (reason == .exit) ? .exited : .uncaughtSignal
        context.terminationStatus = statusCode
        if #available(OSX 10.15, *) {
            try? standardOutputPipe?.fileHandleForWriting.close()
            try? standardErrorPipe?.fileHandleForWriting.close()
        } else {
            standardOutputPipe?.fileHandleForWriting.closeFile()
            standardErrorPipe?.fileHandleForWriting.closeFile()
        }

        guard let handler = terminationHandler else { return }
        terminationHandler = nil
        handler(self)
    }
    
    open override var terminationReason: TerminationReason { context.state == .uncaughtSignal ? .uncaughtSignal : .exit }
    open override var terminationStatus: Int32 { context.terminationStatus }
    open override var processIdentifier: Int32 { context.processIdentifier }
    open override var isRunning: Bool { context.state == .running }
    
    open override func run() throws {
        guard context.state == .initialized else { return }
        context.state = .running
        context.processIdentifier = .random(in: 0...Int32.max)
        let mock = MockProcess(reference: self)
        try context.runStub(mock)
    }
    

    open override func terminate() {
        if let stub = stubTerminate {
            stub(self)
        } else {
            context.state = .uncaughtSignal
        }
    }
    
    open override func resume() -> Bool { stubResume?() ?? false }
    
    open override func suspend() -> Bool { stubSuspend?() ?? false }
}
