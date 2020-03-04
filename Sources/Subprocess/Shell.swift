//
//  Shell.swift
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

/// Class used for synchronous process execution
public class Shell {
    
    public typealias Input = Subprocess.Input
    
    /// OptionSet representing output handling
    public struct OutputOptions: OptionSet {
        public let rawValue: Int
        
        /// Processes data written to stdout
        public static let stdout = OutputOptions(rawValue: 1 << 0)
        
        /// Processes data written to stderr
        public static let stderr = OutputOptions(rawValue: 1 << 1)
        
        /// Processes data written to both stdout and stderr
        public static let combined: OutputOptions = [ .stdout, .stderr ]
        public init(rawValue: Int) { self.rawValue = rawValue }
    }
    
    /// Reference to subprocess
    public let process: Subprocess

    /// Creates new Shell instance
    ///
    /// - Parameter command: Command represented as an array of strings
    public init(_ command: [String]) {
        process = Subprocess(command)
    }
    
    /// Executes shell command using a supplied block to tranform the process output into whatever type you would like
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process  (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    ///     - transformBlock: Block executed given a reference to the completed process and the output
    /// - Returns: Process output as output type of the `transformBlock`
    /// - Throws: Error from process launch,`transformBlock` or failing create a string from the process output
    public func exec<T>(input: Input? = nil, options: OutputOptions = .stdout, transformBlock: (_ process: Subprocess, _ data: Data) throws -> T) throws -> T {
        var buffer = Data()
        try process.launch(input: input,
                           outputHandler: options.contains(.stdout) ? { buffer.append($0) } : nil,
                           errorHandler: options.contains(.stderr) ? { buffer.append($0) } : nil,
                           terminationHandler: { _ in })
        process.waitForTermaination()
        return try transformBlock(process, buffer)
    }
    
    /// Executes shell command expecting exit code of zero and returning the output data
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process  (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    /// - Returns: Process output data
    /// - Throws: Error from process launch or  if termination code is none-zero
    public func exec(input: Input? = nil, options: OutputOptions = .stdout) throws -> Data {
        return try exec(input: input, options: options) { process, data in
            let exitCode = process.exitCode
            guard exitCode == 0 else { throw SubprocessError.exitedWithNoneZeroStatus(exitCode) }
            return data
        }
    }
    
    /// Executes shell command using a supplied block to tranform the process output as a String into whatever type you would like
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process  (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    ///     - encoding: Encoding to use for the output
    ///     - transformBlock: Block executed given a reference to the completed process and the output as a string
    /// - Returns: Process output as output type of the `transformBlock`
    /// - Throws: Error from process launch,`transformBlock` or failing create a string from the process output
    public func exec<T>(input: Input? = nil, options: OutputOptions = .stdout, encoding: String.Encoding, transformBlock: (_ process: Subprocess, _ string: String) throws -> T) throws -> T {
        return try exec(input: input, options: options) { process, data in
            guard let text = String(data: data, encoding: encoding) else { throw SubprocessError.outputStringEncodingError }
            return try transformBlock(process, text)
        }
    }
    
    /// Executes shell command expecting exit code of zero and returning the output as a string
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process  (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    ///     - encoding: Encoding to use for the output
    /// - Returns: Process output as a String
    /// - Throws: Error from process launch, if termination code is none-zero or failing create a string from the process output
    public func exec(input: Input? = nil, options: OutputOptions = .stdout, encoding: String.Encoding) throws -> String {
        return try exec(input: input, options: options, encoding: encoding) { process, text in
            let exitCode = process.exitCode
            guard exitCode == 0 else { throw SubprocessError.exitedWithNoneZeroStatus(exitCode) }
            return text
        }
    }
    
    /// Executes shell command expecting JSON
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process  (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    /// - Returns: Process output as an Array or Dictionary
    /// - Throws: Error from process launch, JSONSerialization or failing to cast to expected type
    public func execJSON<T>(input: Input? = nil, options: OutputOptions = .stdout) throws -> T {
        return try exec(input: input, options: options) { _, data in
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            guard let value = object as? T else {
                throw SubprocessError.unexpectedJSONObject(String(describing: type(of: object)))
            }
            return value
        }
    }
    
    /// Executes shell command expecting a property list
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    /// - Returns: Process output as an Array or Dictionary
    /// - Throws: Error from process launch, PropertyListSerialization or failing to cast to expected type
    public func execPropertyList<T>(input: Input? = nil, options: OutputOptions = .stdout) throws -> T {
        return try exec(input: input, options: options) { _, data in
            let object = try PropertyListSerialization.propertyList(from: data, options: [], format: .none)
            guard let value = object as? T else {
                throw SubprocessError.unexpectedPropertyListObject(String(describing: type(of: object)))
            }
            return value
        }
    }
    
    /// Executes shell command expecting JSON and decodes object conforming to Decodable
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    ///     - decoder: JSONDecoder instance used for decoding the output object
    /// - Returns: Process output as the decodable object type
    /// - Throws: Error from process launch or JSONDecoder
    public func exec<T: Decodable>(input: Input? = nil, options: OutputOptions = .stdout, decoder: JSONDecoder) throws -> T {
        return try exec(input: input, options: options) { _, data in try decoder.decode(T.self, from: data) }
    }
    
    /// Executes shell command expecting property list and decodes object conforming to Decodable
    ///
    /// - Parameters:
    ///     - input: File or data to write to standard input of the process (Default: nil)
    ///     - options: Output options defining the output to process (Default: .stdout)
    ///     - decoder: PropertyListDecoder instance used for decoding the output object
    /// - Returns: Process output as the decodable object type
    /// - Throws: Error from process launch or PropertyListDecoder
    public func exec<T: Decodable>(input: Input? = nil, options: OutputOptions = .stdout, decoder: PropertyListDecoder) throws -> T {
        return try exec(input: input, options: options) { _, data in try decoder.decode(T.self, from: data) }
    }
}
