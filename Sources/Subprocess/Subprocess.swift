//
//  Subprocess.swift
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
public import Combine
#else
import Foundation
import Combine
#endif

/// Class used for asynchronous process execution
public class Subprocess: @unchecked Sendable {
    /// Output options.
    public struct OutputOptions: OptionSet, Sendable {
        public let rawValue: Int
        
        /// Buffer standard output.
        public static let standardOutput = Self(rawValue: 1 << 0)
        
        /// Buffer standard error which may include useful error messages.
        public static let standardError = Self(rawValue: 1 << 1)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    /// Process reference
    let process: Process
    
    /// Process identifier
    public var pid: Int32 { process.processIdentifier }
    
    /// Exit code of the process
    public var exitCode: Int32 { process.terminationStatus }
    
    /// Returns whether the process is still running.
    public var isRunning: Bool { process.isRunning }
    
    /// Reason for process termination
    public var terminationReason: Process.TerminationReason { process.terminationReason }
    
    /// Reference environment property
    public var environment: [String: String]? {
        get {
            process.environment
        }
        set {
            process.environment = newValue
        }
    }
    
    private lazy var group = DispatchGroup()
    
    /// Creates new Subprocess
    ///
    /// - Parameter command: Command represented as an array of strings
    public required init(_ command: [String]) {
        process = SubprocessDependencyBuilder.shared.makeProcess(command: command)
    }
    
    // You may ask yourself, "Well, how did I get here?"
    // It would be nice if we could write something like:
    //
    // public func run<Input>(standardInput: Input? = nil, options: OutputOptions = [.standardOutput, .standardError]) throws -> (standardOutput: Pipe.AsyncBytes, standardError: Pipe.AsyncBytes, waitUntilExit: () async -> Void) where Input : AsyncSequence, Input.Element == UInt8 {}
    //
    // Then the equivelent convenience methods below could take an AsyncSequence as well in the same style.
    //
    // The problem with this is that AsyncSequence is a rethrowing protocol that has no primary associated type. So it's always up to the caller of the method to specify its type and if the default nil is used then it can't determine the type thus causing a compile time error.
    // There are a few Swift Forum threads discussing the problems with AsyncSequence in interfaces:
    // https://forums.swift.org/t/anyasyncsequence/50828/33
    // https://forums.swift.org/t/type-erasure-of-asyncsequences/66547/23
    //
    // The solution used here is to unfortunately have an extra method that just omits the standard input when its not going to be used. I believe the interface is well defined this way and easier to use in the end without strange hacks or conversions to AsyncStream.
    
    /// Run a command.
    ///
    /// - Parameters:
    ///   - options: Options to control which output should be returned.
    /// - Returns: The standard output and standard error as `Pipe.AsyncBytes` sequences and an optional closure that can be used to `await` the process until it has completed.
    ///
    /// Run a command and optionally read its output.
    ///
    ///     let subprocess = Subprocess(["/bin/cat somefile"])
    ///     let (standardOutput, _, waitForExit) = try subprocess.run()
    ///
    ///     Task {
    ///         for await line in standardOutput.lines {
    ///             switch line {
    ///             case "hello":
    ///                 await waitForExit()
    ///                 break
    ///             default:
    ///                 continue
    ///             }
    ///         }
    ///     }
    ///
    /// It is the callers responsibility to ensure that any reads occur if waiting for the process to exit otherwise a deadlock can happen if the process is waiting to write to its output buffer.
    /// A task group can be used to wait for exit while reading the output. If the output is discardable consider passing (`[]`) an empty set for the options which effectively flushes output to null.
    public func run(options: OutputOptions = [.standardOutput, .standardError]) throws -> (standardOutput: Pipe.AsyncBytes, standardError: Pipe.AsyncBytes, waitUntilExit: @Sendable () async -> Void) {
        let standardOutput: Pipe.AsyncBytes = {
            if options.contains(.standardOutput) {
                let pipe = Pipe()
                
                process.standardOutput = pipe
                return pipe.bytes
            } else {
                let pipe = Pipe()
                
                defer {
                    try? pipe.fileHandleForReading.close()
                }
                
                process.standardOutput = FileHandle.nullDevice
                return pipe.bytes
            }
        }()
        let standardError: Pipe.AsyncBytes = {
            if options.contains(.standardError) {
                let pipe = Pipe()
                
                process.standardError = pipe
                return pipe.bytes
            } else {
                let pipe = Pipe()
                
                defer {
                    try? pipe.fileHandleForReading.close()
                }
                
                process.standardError = FileHandle.nullDevice
                return pipe.bytes
            }
        }()
        
        let terminationContinuation = TerminationContinuation()
        let task: Task<Void, Never> = Task.detached {
            await withUnsafeContinuation { continuation in
                Task {
                    await terminationContinuation.setContinuation(continuation)
                }
            }
        }
        let waitUntilExit = { @Sendable in
            await task.value
        }
        
        process.terminationHandler = { _ in
            Task {
                await terminationContinuation.resume()
            }
        }
        
        try process.run()
        return (standardOutput, standardError, waitUntilExit)
    }
    
    /// Run an interactive command.
    ///
    /// - Parameters:
    ///   - standardInput: An `AsyncSequence` that is used to supply input to the underlying process.
    ///   - options: Options to control which output should be returned.
    /// - Returns: The standard output and standard error as `Pipe.AsyncBytes` sequences and an optional closure that can be used to `await` the process until it has completed.
    ///
    /// Run a command and interactively respond to output.
    ///
    ///     let (stream, input) = {
    ///         var input: AsyncStream<UInt8>.Continuation!
    ///         let stream: AsyncStream<UInt8> = AsyncStream { continuation in
    ///             input = continuation
    ///         }
    ///
    ///         return (stream, input!)
    ///     }()
    ///
    ///     let subprocess = Subprocess(["/bin/cat"])
    ///     let (standardOutput, _, waitForExit) = try subprocess.run(standardInput: stream)
    ///
    ///     input.yield("hello\n")
    ///
    ///     Task {
    ///         for await line in standardOutput.lines {
    ///             switch line {
    ///             case "hello":
    ///                 input.yield("world\n")
    ///             case "world":
    ///                 input.yield("and\nuniverse")
    ///                 input.finish()
    ///             case "universe":
    ///                 await waitForExit()
    ///                 break
    ///             default:
    ///                 continue
    ///             }
    ///         }
    ///     }
    ///
    public func run<Input>(standardInput: Input, options: OutputOptions = [.standardOutput, .standardError]) throws -> (standardOutput: Pipe.AsyncBytes, standardError: Pipe.AsyncBytes, waitUntilExit: @Sendable () async -> Void) where Input : AsyncSequence, Input.Element == UInt8 {
        process.standardInput = try SubprocessDependencyBuilder.shared.makeInputPipe(sequence: standardInput)
        return try run(options: options)
    }
    
    /// Suspends the command
    public func suspend() -> Bool {
        process.suspend()
    }
    
    /// Resumes the command which was suspended
    public func resume() -> Bool {
        process.resume()
    }
    
    /// Sends the command the term signal
    public func kill() {
        process.terminate()
    }
}

// Methods for typical one-off acquisition of output from running some command.
extension Subprocess {
    /// Additional configuration options.
    public struct RunOptions: OptionSet, Sendable {
        public let rawValue: Int

        /// Throw an error if the process exited with a non-zero exit code.
        public static let throwErrorOnNonZeroExit = Self(rawValue: 1 << 0)
        
        /// Return the output from standard error instead of standard output.
        public static let returnStandardError = Self(rawValue: 1 << 1)
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    /// Retreive output as `Data` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A type conforming to `DataProtocol` (typically a `Data` type) from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    public static func data(for command: [String], standardInput: (any DataProtocol & Sendable)? = nil, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> Data {
        let subprocess = Self(command)
        let (standardOutput, standardError, waitForExit) = if let standardInput {
            try subprocess.run(standardInput: AsyncStream(UInt8.self, { continuation in
                for byte in standardInput {
                    if case .terminated = continuation.yield(byte) {
                        break
                    }
                }
                
                continuation.finish()
            }))
        } else {
            try subprocess.run()
        }
        
        // need to read output for processes that fill their buffers otherwise a wait could occur waiting for a read to clear the buffer
        let result = await withTaskGroup(of: Void.self) { group in
            let stdoutData = UnsafeData()
            let stderrData = UnsafeData()
            
            group.addTask {
                await withTaskCancellationHandler(operation: {
                    await waitForExit()
                }, onCancel: {
                    subprocess.kill()
                })
            }
            group.addTask {
                var bytes = [UInt8]()
                
                for await byte in standardOutput {
                    bytes.append(byte)
                }
                
                stdoutData.set(Data(bytes))
            }
            group.addTask {
                var bytes = [UInt8]()
                
                for await byte in standardError {
                    bytes.append(byte)
                }
                
                stderrData.set(Data(bytes))
            }
            
            for await _ in group {
                // nothing to collect here
            }
            
            return (standardOutputData: stdoutData.value(), standardErrorData: stderrData.value())
        }
        try Task.checkCancellation()
        
        if options.contains(.throwErrorOnNonZeroExit), subprocess.process.terminationStatus != 0 {
            throw Error.nonZeroExit(status: subprocess.process.terminationStatus, reason: subprocess.process.terminationReason, standardOutput: result.standardOutputData, standardError: String(decoding: result.standardErrorData, as: UTF8.self))
        }
        
        let data = if options.contains(.returnStandardError) {
            result.standardErrorData
        } else {
            result.standardOutputData
        }
        
        return data
    }
    
    // MARK: Data convenience methods
    
    /// Retreive output as `Data` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A `String` from which to send input to the external command.
    ///   - options: Options used to specify runtime behavior.
    @inlinable
    public static func data(for command: [String], standardInput: String, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> Data {
        try await data(for: command, standardInput: standardInput.data(using: .utf8)!, options: options)
    }
    
    /// Retreive output as `Data` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A file `URL` from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    public static func data(for command: [String], standardInput: URL, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> Data {
        let subprocess = Self(command)
        let (standardOutput, standardError, waitForExit) = if #available(macOS 12.0, *) {
            try subprocess.run(standardInput: SubprocessDependencyBuilder.shared.makeInputFileHandle(url: standardInput).bytes)
        } else if let fileData = try SubprocessDependencyBuilder.shared.makeInputFileHandle(url: standardInput).readToEnd(), !fileData.isEmpty {
            try subprocess.run(standardInput: AsyncStream(UInt8.self, { continuation in
                for byte in fileData {
                    if case .terminated = continuation.yield(byte) {
                        break
                    }
                }
                
                continuation.finish()
            }))
        } else {
            try subprocess.run()
        }
        
        // need to read output for processes that fill their buffers otherwise a wait could occur waiting for a read to clear the buffer
        let result = await withTaskGroup(of: Void.self) { group in
            let stdoutData = UnsafeData()
            let stderrData = UnsafeData()
            
            group.addTask {
                await withTaskCancellationHandler(operation: {
                    await waitForExit()
                }, onCancel: {
                    subprocess.kill()
                })
            }
            group.addTask {
                var bytes = [UInt8]()
                
                for await byte in standardOutput {
                    bytes.append(byte)
                }
                
                stdoutData.set(Data(bytes))
            }
            group.addTask {
                var bytes = [UInt8]()
                
                for await byte in standardError {
                    bytes.append(byte)
                }
                
                stderrData.set(Data(bytes))
            }
            
            for await _ in group {
                // nothing to collect
            }
            
            return (standardOutputData: stdoutData.value(), standardErrorData: stderrData.value())
        }
        try Task.checkCancellation()
        
        if options.contains(.throwErrorOnNonZeroExit), subprocess.process.terminationStatus != 0 {
            throw Error.nonZeroExit(status: subprocess.process.terminationStatus, reason: subprocess.process.terminationReason, standardOutput: result.standardOutputData, standardError: String(decoding: result.standardErrorData, as: UTF8.self))
        }
        
        let data = if options.contains(.returnStandardError) {
            result.standardErrorData
        } else {
            result.standardOutputData
        }
        
        return data
    }
    
    // MARK: String convenience methods
    
    /// Retreive output as a UTF8 `String` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A type conforming to `DataProtocol` (typically a `Data` type) from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    @inlinable
    public static func string(for command: [String], standardInput: (any DataProtocol & Sendable)? = nil, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> String {
        String(decoding: try await data(for: command, standardInput: standardInput, options: options), as: UTF8.self)
    }
    
    /// Retreive output as `String` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A `String` from which to send input to the external command.
    ///   - options: Options used to specify runtime behavior.
    @inlinable
    public static func string(for command: [String], standardInput: String, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> String {
        String(decoding: try await data(for: command, standardInput: standardInput, options: options), as: UTF8.self)
    }
    
    /// Retreive output as `String` from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A file `URL` from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    @inlinable
    public static func string(for command: [String], standardInput: URL, options: RunOptions = .throwErrorOnNonZeroExit) async throws -> String {
        String(decoding: try await data(for: command, standardInput: standardInput, options: options), as: UTF8.self)
    }
    
    // MARK: Decodable types convenience methods
    
    /// Retreive output from from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A type conforming to `DataProtocol` (typically a `Data` type) from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    ///   - decoder: A `TopLevelDecoder` that will be used to decode the data.
    @inlinable
    public static func value<Content, Decoder>(for command: [String], standardInput: (any DataProtocol & Sendable)? = nil, options: RunOptions = .throwErrorOnNonZeroExit, decoder: Decoder) async throws -> Content where Content : Decodable, Decoder : TopLevelDecoder, Decoder.Input == Data {
        try await decoder.decode(Content.self, from: data(for: command, standardInput: standardInput, options: options))
    }
    
    /// Retreive output from from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A `String` from which to send input to the external command.
    ///   - options: Options used to specify runtime behavior.
    ///   - decoder: A `TopLevelDecoder` that will be used to decode the data.
    @inlinable
    public static func value<Content, Decoder>(for command: [String], standardInput: String, options: RunOptions = .throwErrorOnNonZeroExit, decoder: Decoder) async throws -> Content where Content : Decodable, Decoder : TopLevelDecoder, Decoder.Input == Data {
        try await decoder.decode(Content.self, from: data(for: command, standardInput: standardInput, options: options))
    }
    
    /// Retreive output from from running an external command.
    /// - Parameters:
    ///   - command: An external command to run with optional arguments.
    ///   - standardInput: A file `URL` from which to read input to the external command.
    ///   - options: Options used to specify runtime behavior.
    ///   - decoder: A `TopLevelDecoder` that will be used to decode the data.
    @inlinable
    public static func value<Content, Decoder>(for command: [String], standardInput: URL, options: RunOptions = .throwErrorOnNonZeroExit, decoder: Decoder) async throws -> Content where Content : Decodable, Decoder : TopLevelDecoder, Decoder.Input == Data {
        try await decoder.decode(Content.self, from: data(for: command, standardInput: standardInput, options: options))
    }
}

// closure based methods
extension Subprocess {
    /// Launches command with read handlers and termination handler
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process
    ///     - outputHandler: Block called whenever new data is read from standard output of the process
    ///     - errorHandler: Block called whenever new data is read from standard error of the process
    ///     - terminationHandler: Block called when process has terminated and all output handlers have returned
    public func launch(input: Input? = nil, outputHandler: (@Sendable (Data) -> Void)? = nil, errorHandler: (@Sendable (Data) -> Void)? = nil, terminationHandler: (@Sendable (Subprocess) -> Void)? = nil) throws {
        process.standardInput = try input?.createPipeOrFileHandle()
        
        process.standardOutput = if let outputHandler {
            createPipeWithReadabilityHandler(outputHandler)
        } else {
            FileHandle.nullDevice
        }
        
        process.standardError = if let errorHandler {
            createPipeWithReadabilityHandler(errorHandler)
        } else {
            FileHandle.nullDevice
        }
        
        group.enter()
        process.terminationHandler = { [unowned self] _ in
            group.leave()
        }
        
        group.notify(queue: .main) {
            terminationHandler?(self)
        }
        
        try process.run()
    }
    
    /// Block type called for executing process returning data from standard out and standard error
    public typealias DataTerminationHandler = @Sendable (_ process: Subprocess, _ stdout: Data, _ stderr: Data) -> Void
    
    /// Launches command calling a block when process terminates
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process
    ///     - terminationHandler: Block called with Subprocess, stdout Data, stderr Data
    public func launch(input: Input? = nil, terminationHandler: @escaping DataTerminationHandler) throws {
        let stdoutData = UnsafeData()
        let stderrData = UnsafeData()
        
        try launch(input: input, outputHandler: { data in
            stdoutData.append(data)
        }, errorHandler: { data in
            stderrData.append(data)
        }, terminationHandler: { selfRef in
            let standardOutput = stdoutData.value()
            let standardError = stderrData.value()
            
            terminationHandler(selfRef, standardOutput, standardError)
        })
    }
    
    /// Waits for process to complete and all handlers to be called. Not to be
    /// confused with `Process.waitUntilExit()` which can return before its
    /// `terminationHandler` is called.
    /// Calling this method when using the non-deprecated methods will return immediately and not wait for the process to exit.
    public func waitForTermination() {
        group.wait()
    }
    
    private func createPipeWithReadabilityHandler(_ handler: @escaping @Sendable (Data) -> Void) -> Pipe {
        let pipe = Pipe()
        
        group.enter()
        
        let stream: AsyncStream<Data> = AsyncStream { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    continuation.finish()
                    return
                }
                
                continuation.yield(data)
            }
            
            continuation.onTermination = { _ in
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
        
        Task {
            for await data in stream {
                handler(data)
            }
            
            group.leave()
        }
        
        return pipe
    }
}

extension Subprocess {
    /// Errors specific to `Subprocess`.
    public enum Error: LocalizedError {
        case nonZeroExit(status: Int32, reason: Process.TerminationReason, standardOutput: Data, standardError: String)
        
        public var errorDescription: String? {
            switch self {
            case let .nonZeroExit(status: terminationStatus, reason: _, standardOutput: _, standardError: errorString):
                return "Process exited with status \(terminationStatus): \(errorString)"
            }
        }
    }
}

private actor TerminationContinuation {
    private var continuation: UnsafeContinuation<Void, Never>?
    private var didResume = false
    
    deinit {
        continuation?.resume()
    }
    
    func setContinuation(_ continuation: UnsafeContinuation<Void, Never>) {
        self.continuation = continuation
        
        // in case the termination happened before the task was able to set the continuation
        if didResume {
            resume()
        }
    }
    
    func resume() {
        continuation?.resume()
        continuation = nil
        didResume = true
    }
}
