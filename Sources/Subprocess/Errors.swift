//
//  Errors.swift
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

/// Type representing possible errors
@available(*, deprecated, message: "This type is no longer used with methods supporting Swift Concurrency")
public enum SubprocessError: Error {

    /// The process completed with a non-zero exit code
    /// and a custom error message.
    case exitedWithNonZeroStatus(Int32, String)

    /// The property list object could not be cast to expected type
    case unexpectedPropertyListObject(String)

    /// The JSON object could not be cast to expected type
    case unexpectedJSONObject(String)

    /// Input string could not be encoded
    case inputStringEncodingError

    /// Output string could not be encoded
    case outputStringEncodingError
}

@available(*, deprecated, message: "This type is no longer used with methods supporting Swift Concurrency")
extension SubprocessError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .exitedWithNonZeroStatus(_, let errorMessage):
            return "\(errorMessage)"
        case .unexpectedPropertyListObject:
            // Ignoring the plist contents parameter as we don't want that in the error message
            return "The property list object could not be cast to expected type"
        case .unexpectedJSONObject:
            // Ignoring the json contents parameter as we don't want that in the error message
            return "The JSON object could not be cast to expected type"
        case .inputStringEncodingError:
            return "Input string could not be encoded"
        case .outputStringEncodingError:
            return "Output string could not be encoded"
        }
    }
}

/// Common NSError methods for better interop with Objective-C
@available(*, deprecated, message: "This type is no longer used with methods supporting Swift Concurrency")
extension SubprocessError: CustomNSError {
    public var errorCode: Int {
        switch self {
        case .exitedWithNonZeroStatus(let errorCode, _):
            return Int(errorCode)
        case .unexpectedPropertyListObject: return 10
        case .unexpectedJSONObject: return 20
        case .inputStringEncodingError: return 30
        case .outputStringEncodingError: return 40
        }
    }
}
