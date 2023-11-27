//
//  Pipe+AsyncBytes.swift
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

import Foundation

// `FileHandle.AsyncBytes` has a bug that can block reading of stdout when also reading stderr.
// We can avoid this problem if we create independent handlers.
extension Pipe {
    /// Convenience for reading bytes from the pipe's file handle.
    public struct AsyncBytes: AsyncSequence, Sendable {
        public typealias Element = UInt8

        let pipe: Pipe

        public func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
            AsyncStream { continuation in
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let availableData = handle.availableData
                    
                    guard !availableData.isEmpty else {
                        handle.readabilityHandler = nil
                        continuation.finish()
                        return
                    }
                    
                    for byte in availableData {
                        if case .terminated = continuation.yield(byte) {
                            break
                        }
                    }
                }

                continuation.onTermination = { _ in
                    pipe.fileHandleForReading.readabilityHandler = nil
                }
            }.makeAsyncIterator()
        }
    }

    public var bytes: AsyncBytes {
        AsyncBytes(pipe: self)
    }
}
