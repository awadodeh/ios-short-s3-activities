import Foundation
import XCTest

public class SomeTests: XCTestCase {

  func testSomething() {
    XCTAssertEqual(200,200)
 }

}

#if os(Linux)
extension SomeTests {
  static var allTests: [(String, (JSONControllerTests) -> () throws -> Void)] {
    return [
      ("testSomething", testSomething)
    ]
  }
}
#endif
