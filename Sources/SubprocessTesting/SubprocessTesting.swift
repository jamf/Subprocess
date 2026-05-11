#if swift(>=6.0)
public import Testing
public import SubprocessMocks
#else
import Testing
import SubprocessMocks
#endif
import Subprocess

#if swift(>=6.1)
public struct SubprocessTrait: TestTrait, SuiteTrait, TestScoping {
    private let builder: MockSubprocessDependencyBuilder?
    
    public init(builder: MockSubprocessDependencyBuilder? = nil) {
        self.builder = builder
    }
    
    public func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
        let scopedBuilder = if let builder {
            builder
        } else {
            MockSubprocessDependencyBuilder()
        }
        
        try await SubprocessDependencyBuilder.$__shared.withValue(scopedBuilder) {
            try await MockSubprocessDependencyBuilder.$shared.withValue(scopedBuilder) {
                try await function()
            }
        }
    }
}

extension Trait where Self == SubprocessTrait {
    @available(*, deprecated, renamed: "subprocess")
    public static var subprocessTesting: Self {
        SubprocessTrait()
    }
    
    /// Creates an isolated mock subprocess dependency builder for the current test task
    public static var subprocess: Self {
        SubprocessTrait()
    }
    
    /// Uses the supplied mock subprocess dependency builder for the current test task
    public static func subprocessBuilder(_ builder: MockSubprocessDependencyBuilder) -> Self {
        SubprocessTrait(builder: builder)
    }
}
#endif
