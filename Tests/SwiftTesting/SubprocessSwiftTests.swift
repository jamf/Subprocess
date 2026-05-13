#if swift(>=6.1)
import Foundation
import Testing
import Subprocess
import SubprocessMocks
import SubprocessTesting

@Suite
struct SubprocessSwiftTests: ~Copyable {
    @Test(.subprocess, arguments: 0..<100)
    func `mocks can handle parallel testing`(_ count: Int) async throws {
        let testFileURL = URL(fileURLWithPath: "/tmp/\(Self.self)-\(UUID().uuidString).txt")
        
        let commands = [
            ["/bin/cat", testFileURL.path],
            ["/usr/bin/head", "-n", "\(count)", testFileURL.path],
            ["/usr/bin/tail", "-r", "-n", "\(count)", testFileURL.path],
        ]
        
        for command in commands.shuffled() {
            Subprocess.expect(command)
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for command in commands.shuffled() {
                group.addTask {
                    _ = try await Subprocess.string(for: command)
                }
            }
            
            try await group.waitForAll()
        }
        
        try Subprocess.verify()
    }
    
    @Test(arguments: 0..<5)
    func `direct test of command still works`(_ count: Int) async throws {
        let testFileURL: URL = {
            let url = URL(fileURLWithPath: "/tmp/\(Self.self)-\(UUID().uuidString).txt")
            
            try! Self.generateRandomASCIIFile(at: url)
            return url
        }()
        
        let fileContents = try await Subprocess.string(for: ["/bin/cat", testFileURL.path])
        let stringFileContents = try String(contentsOfFile: testFileURL.path, encoding: .utf8)
        #expect(fileContents == stringFileContents)
        try FileManager.default.removeItem(at: testFileURL)
    }
    
    @Test(.subprocess, arguments: ["foo", "bar", "baz"])
    func echo(_ word: String) async throws {
        Subprocess.expect(["/bin/echo", word], standardOutput: "\(word)\n".data(using: .utf8))

        let output = try await Subprocess.string(for: ["/bin/echo", word])

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == word)
        try Subprocess.verify()
    }
    
    @Test(.subprocess)
    func `software version`() async throws {
        Subprocess.expect(["/usr/bin/sw_vers", "-productVersion"], standardOutput: "15.0\n".data(using: .utf8))

        let version = try await Subprocess.string(for: ["/usr/bin/sw_vers", "-productVersion"])

        #expect(version.trimmingCharacters(in: .whitespacesAndNewlines) == "15.0")
        try Subprocess.verify()
    }
}

@Suite(.subprocess)
struct MyCommandTests: ~Copyable {
    // must be serialized otherwise concurrent usage will race against the suite shared mock storage
    @Test(.serialized, arguments: 0..<10)
    func grep(count: Int) async throws {
        Subprocess.expect(["/usr/bin/grep", "foo"], standardOutput: "foo bar\n".data(using: .utf8))

        let result = try await Subprocess.string(for: ["/usr/bin/grep", "foo"])

        #expect(result.contains("foo"))
        try Subprocess.verify()
    }

    @Test
    func `missing file`() async throws {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
        Subprocess.expect(["/bin/cat", "/no/such/file"], error: error)

        await #expect(throws: (any Error).self) {
            try await Subprocess.data(for: ["/bin/cat", "/no/such/file"])
        }
    }
    
    // this test creates its own isolated mocks separate from the other tests
    @Test(.subprocess, arguments: 0..<10)
    func `grep returns an error`(count: Int) async throws {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
        Subprocess.expect(["/usr/bin/grep", "foo"], error: error)

        await #expect(throws: (any Error).self) {
            try await Subprocess.string(for: ["/usr/bin/grep", "foo"])
        }
        try Subprocess.verify()
    }
}

private extension SubprocessSwiftTests {
    static func generateRandomASCIIFile(at url: URL, lineCount: Int = 1000, maxLineLength: Int = 1000) throws {
        let printableASCII: [Character] = (UInt8(0x21)...UInt8(0x7E)).map { Character(UnicodeScalar($0)) }
        var contents = ""
        contents.reserveCapacity(lineCount * maxLineLength / 2)

        for _ in 0..<lineCount {
            let length = Int.random(in: 0...maxLineLength)
            contents.append(String((0..<length).map { _ in printableASCII.randomElement()! }))
            contents.append("\n")
        }

        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
