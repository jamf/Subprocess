import XCTest
@testable import Subprocess

final class SubprocessSystemTests: XCTestCase {
    let softwareVersionFilePath = "/System/Library/CoreServices/SystemVersion.plist"
    
    override func setUp() {
        SubprocessDependencyBuilder.shared = SubprocessDependencyBuilder()
    }
    
    @available(macOS 12.0, *)
    func testRunWithOutput() async throws {
        let result = try await Subprocess(["/bin/cat", softwareVersionFilePath]).run().standardOutput.lines.first(where: { $0.contains("ProductName") }) != nil
        
        XCTAssertTrue(result)
    }
    
    @available(macOS 12.0, *)
    func testRunWithStandardOutput() async throws {
        let result = try await Subprocess(["/bin/cat", softwareVersionFilePath]).run(options: .standardOutput).standardOutput.lines.first(where: { $0.contains("ProductName") }) != nil
        
        XCTAssertTrue(result)
    }
    
    @available(macOS 12.0, *)
    func testRunWithStandardError() async throws {
        let result = try await Subprocess(["/bin/cat", "/non/existent/path/file.txt"]).run(options: .standardError).standardError.lines.first(where: { $0.contains("No such file or directory") }) != nil
        
        XCTAssertTrue(result)
    }
    
    func testRunWithCombinedOutput() async throws {
        let process = Subprocess(["/bin/cat", softwareVersionFilePath])
        let (standardOutput, standardError, waitForExit) = try process.run()
        async let (stdout, stderr) = (standardOutput, standardError)
        let combinedOutput = await [stdout.string(), stderr.string()]
        
        await waitForExit()
        XCTAssertTrue(combinedOutput[0].contains("ProductName"))
    }
    
    @available(macOS 12.0, *)
    func testInteractiveRun() async throws {
        var input: AsyncStream<UInt8>.Continuation!
        let stream: AsyncStream<UInt8> = AsyncStream { continuation in
            input = continuation
        }
        let subprocess = Subprocess(["/bin/cat"])
        let (standardOutput, _, _) = try subprocess.run(standardInput: stream)
        
        input.yield("hello\n")
        
        for await line in standardOutput.lines {
            XCTAssertEqual("hello", line)
            break
        }
        
        input.yield("world\n")
        input.finish()
        
        for await line in standardOutput.lines {
            XCTAssertEqual("world", line)
            break
        }
    }
    
    @available(macOS 12.0, *)
    func testInteractiveAsyncRun() throws {
        let exp = expectation(description: "\(#file):\(#line)")
        let (stream, input) = {
            var input: AsyncStream<UInt8>.Continuation!
            let stream: AsyncStream<UInt8> = AsyncStream { continuation in
                input = continuation
            }
            
            return (stream, input!)
        }()
        
        let subprocess = Subprocess(["/bin/cat"])
        let (standardOutput, _, _) = try subprocess.run(standardInput: stream)
        
        input.yield("hello\n")
        
        Task {
            for await line in standardOutput.lines {
                switch line {
                case "hello":
                    Task {
                        input.yield("world\n")
                    }
                case "world":
                    input.yield("and\nuniverse")
                    input.finish()
                case "universe":
                    break
                default:
                    continue
                }
            }
            
            exp.fulfill()
        }

        wait(for: [exp])
    }
    
    func testData() async throws {
        let data = try await Subprocess.data(for: ["/bin/cat", softwareVersionFilePath])
        
        XCTAssert(!data.isEmpty)
    }
    
    func testDataWithInput() async throws {
        let data = try await Subprocess.data(for: ["/bin/cat"], standardInput: Data("hello".utf8))
        
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "hello")
    }
    
    @available(macOS 13.0, *)
    func testDataCancel() async throws {
        let exp = expectation(description: "\(#file):\(#line)")
        let task = Task {
            do {
                _ = try await Subprocess.data(for: ["/bin/cat"], standardInput: URL(filePath: "/dev/random"))
                
                XCTFail("expected task to be canceled")
            } catch {
                exp.fulfill()
            }
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()
        await fulfillment(of: [exp])
    }
    
    func testDataCancelWithoutInput() async throws {
        let exp = expectation(description: "\(#file):\(#line)")
        let task = Task {
            do {
                _ = try await Subprocess.data(for: ["/bin/cat", "/dev/random"])
                
                XCTFail("expected task to be canceled")
            } catch {
                exp.fulfill()
            }
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()
        await fulfillment(of: [exp])
    }
    
    func testString() async throws {
        let username = NSUserName()
        let result = try await Subprocess.string(for: ["/usr/bin/dscl", ".", "list", "/Users"])
        
        XCTAssertTrue(result.contains(username))
    }
    
    func testStringWithStringInput() async throws {
        let result = try await Subprocess.string(for: ["/bin/cat"], standardInput: "hello")
        
        XCTAssertEqual("hello", result)
    }
    
    @available(macOS 13.0, *)
    func testStringWithFileInput() async throws {
        let result = try await Subprocess.string(for: ["/bin/cat"], standardInput: URL(filePath: softwareVersionFilePath))
        
        XCTAssertEqual(try String(contentsOf: URL(filePath: softwareVersionFilePath)), result)
    }
    
    func testReturningJSON() async throws {
        struct LogMessage: Codable {
            var subsystem: String
            var category: String
            var machTimestamp: UInt64
        }

        let result: [LogMessage] = try await Subprocess.value(for: ["/usr/bin/log", "show", "--style", "json", "--last", "30s"], decoder: JSONDecoder())
        
        XCTAssertTrue(!result.isEmpty)
    }
    
    func testReturningPropertyList() async throws {
        struct SystemVersion: Codable {
            enum CodingKeys: String, CodingKey {
                case version = "ProductVersion"
            }
            var version: String
        }

        let fullVersionString = ProcessInfo.processInfo.operatingSystemVersionString
        let result: SystemVersion = try await Subprocess.value(for: ["/bin/cat", softwareVersionFilePath], decoder: PropertyListDecoder())
        let versionNumber = result.version
        
        XCTAssertTrue(fullVersionString.contains(versionNumber))
    }
    
    func testNonZeroExit() async {
        do {
            _ = try await Subprocess.string(for: ["/bin/cat", "/non/existent/path/file.txt"])
            XCTFail("expected failure")
        } catch Subprocess.Error.nonZeroExit {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
