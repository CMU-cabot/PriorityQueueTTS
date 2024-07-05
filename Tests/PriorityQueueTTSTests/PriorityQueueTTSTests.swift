/*******************************************************************************
 * Copyright (c) 2024  Carnegie Mellon University
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import XCTest
@testable import PriorityQueueTTS

final class PriorityQueueTTSTests: XCTestCase {

    /*
     add "Hello1", priority normal
     add "Hello2", priority normal
     add "Hello3", priority high
     start
     should speak "Hello3", "Hello1", "Hello2"
     */
    func test1_high_priority_comes_first() throws {
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

    let sample: String = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

    /*
     add `sample`, priority normal
     start and wait 3 secs
     add "High Priority", priority high
     should speak `sample` and pause, "High Priority", then rest of `sample`
     */
    func test2_high_priority_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        tts.append(text: sample, timeout_sec: 30) { item, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual(self.sample, item.text)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Completed:
                XCTAssertLessThan(item.text.count, self.sample.count)
                XCTAssertEqual(count, 2)
                count += 1
                expectation.fulfill()
                break
            case .Canceled:
                XCTAssertTrue(false)
                break
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(text: "High Priority Message", priority: .High, timeout_sec: 1) { item, reason in
                XCTAssertEqual(count, 1)
                count += 1
            }
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
}
