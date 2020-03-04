import XCTest

import SubprocessTests

var tests = [XCTestCaseEntry]()
tests += SubprocessTests.allTests()
XCTMain(tests)
