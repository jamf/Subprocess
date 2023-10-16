//
//  AsyncStream+Yield.swift
//  Subprocess
//
//  MIT License
//
//  Copyright (c) 2023 Jamf Software
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

extension AsyncStream.Continuation where Element == UInt8 {
    /// Resume the task awaiting the next iteration point by having it return
    /// normally from its suspension point with the given data.
    ///
    /// - Parameter value: The value to yield from the continuation.
    /// - Returns: A `YieldResult` that indicates the success or failure of the
    ///   yield operation from the last byte of the `Data`.
    ///
    /// If nothing is awaiting the next value, this method attempts to buffer the
    /// result's element.
    ///
    /// This can be called more than once and returns to the caller immediately
    /// without blocking for any awaiting consumption from the iteration.
    @discardableResult public func yield(_ value: Data) -> AsyncStream<Element>.Continuation.YieldResult? {
        var yieldResult: AsyncStream<Element>.Continuation.YieldResult?
        
        for byte in value {
            yieldResult = yield(byte)
        }
        
        return yieldResult
    }
    
    /// Resume the task awaiting the next iteration point by having it return
    /// normally from its suspension point with the given string.
    ///
    /// - Parameter value: The value to yield from the continuation.
    /// - Returns: A `YieldResult` that indicates the success or failure of the
    ///   yield operation from the last byte of the string after being converted to `Data`.
    ///
    /// If nothing is awaiting the next value, this method attempts to buffer the
    /// result's element.
    ///
    /// This can be called more than once and returns to the caller immediately
    /// without blocking for any awaiting consumption from the iteration.
    @discardableResult public func yield(_ value: String) -> AsyncStream<Element>.Continuation.YieldResult? {
        // unicode encodings are safe to explicity unwrap
        yield(value.data(using: .utf8)!)
    }
}
