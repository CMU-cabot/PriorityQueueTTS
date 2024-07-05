import XCTest
@testable import PriorityQueueTTS

final class PriorityQueueTTSTests: XCTestCase {

    /*
     add Hello1, priority normal
     add Hello2, priority normal
     add Hello3, priority high
     start
     should speak Hello3, Hello1, Hello2
     */
    func test1() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        tts.append(text: "Hello1", timeout_sec: 10) { item, canceled in
            XCTAssertEqual(count, 1)
            count += 1
        }
        tts.append(text: "Hello2", timeout_sec: 10) { item, canceled in
            XCTAssertEqual(count, 2)
            expectation.fulfill()
        }
        tts.append(text: "Hello3", priority: .High, timeout_sec: 20) { item, canceled in
            XCTAssertEqual(count, 0)
            count += 1
        }
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }
}
