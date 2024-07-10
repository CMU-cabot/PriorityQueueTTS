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
        tts.append(entry: SpeechEntry(text: "Hello1") { item, canceld in
            XCTAssertEqual(count, 1)
            count += 1
        })
        tts.append(entry: SpeechEntry(text: "Hello2") { item, canceld in
            XCTAssertEqual(count, 2)
            count += 1
            expectation.fulfill()
        })
        tts.append(entry: SpeechEntry(text: "Hello3", priority: .High) { item, canceld in
            XCTAssertEqual(count, 0)
            count += 1
        })
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    let sample: String = "This is a sample message, all the message should be read"

    /*
     add `sample`, priority normal
     start and wait 3 secs
     add "High Priority Message", priority high
     should speak `sample` and pause, "High Priority Message", then rest of `sample`
     */
    func test2_high_priority_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        tts.append(entry: SpeechEntry(text: sample, timeout_sec: 30.0) { item, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual(self.sample, item.token?.text)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Completed:
                if let count = item.token?.remainingText?.count {
                    XCTAssertLessThan(count, self.sample.count)
                }
                XCTAssertEqual(count, 2)
                count += 1
                expectation.fulfill()
                break
            case .Canceled:
                XCTAssertTrue(false)
                break
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: SpeechEntry(text: "High Priority Message", priority: .High, timeout_sec: 1) { item, reason in
                XCTAssertEqual(count, 1)
                count += 1
            })
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*
     add `sample`, priority normal
     start and wait 3 secs
     add "Normal Priority Message", priority normal
     should speak `sample`, and then "Normal Priority Message"
     */
    func test3_same_priority_should_not_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        tts.append(entry: SpeechEntry(text: sample, timeout_sec: 30) { item, reason in
            switch(reason) {
            case .Paused:
                XCTAssertTrue(false)
                break
            case .Completed:
                XCTAssertEqual(item.token?.text, self.sample)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Canceled:
                XCTAssertTrue(false)
                break
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: SpeechEntry(text: "Normal Priority Message", priority: .Normal, timeout_sec: 15) { item, reason in
                XCTAssertEqual(count, 1)
                count += 1
                expectation.fulfill()
            })
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*
     add Hello1
     add pause 1.0
     add Hello2
     should speak Hello1, and Hello2 after 1.0 sec
     */
    func test4_add_pause() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        var start: TimeInterval = 0
        tts.append(entry: SpeechEntry(text: "Hello1", timeout_sec: 10) { item, reason in
            XCTAssertEqual(count, 0)
            count += 1
            start = Date().timeIntervalSince1970
        })
        tts.append(entry: PauseEntry(pause: 10, timeout_sec: 10) { item, reason in
            XCTAssertEqual(count, 1)
            count += 1
            let end = Date().timeIntervalSince1970
            XCTAssertLessThan(abs((end - start) - 1.0), 0.1)
        })
        tts.append(entry: SpeechEntry(text: "Hello2", timeout_sec: 10) { item, reason in
            XCTAssertEqual(count, 2)
            count += 1
            expectation.fulfill()
        })
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    /*
     add `sample`, priority normal
     start and wait 3 secs
     add "High Priority", priority high
     add pause 0.5, priority high
     add "Message", priority high
     should speak `sample` and pause, "High Priority", pause 0.5, "Message", then rest of `sample`
     */
    func test5_high_priority_interrupt_with_pause() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        var start: TimeInterval = 0
        tts.append(entry: SpeechEntry(text: sample, timeout_sec: 30) { item, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual(self.sample, item.token?.text)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Completed:
                if let text = item.token?.text?.count {
                    XCTAssertLessThan(count, self.sample.count)
                }
                XCTAssertEqual(count, 4)
                count += 1
                expectation.fulfill()
                break
            case .Canceled:
                XCTAssertTrue(false)
                break
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: SpeechEntry(text: "High Priority", priority: .High, timeout_sec: 1) { item, reason in
                XCTAssertEqual(count, 1)
                count += 1
                start = Date().timeIntervalSince1970
            })
            tts.append(entry: PauseEntry(pause: 5, priority: .High, timeout_sec: 3) { item, reason in
                XCTAssertEqual(count, 2)
                count += 1
                let end = Date().timeIntervalSince1970
                XCTAssertLessThan(abs((end - start) - 0.5), 0.1)
            })
            tts.append(entry: SpeechEntry(text: "Message", priority: .High, timeout_sec: 5) { item, reason in
                XCTAssertEqual(count, 3)
                count += 1
            })
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*
     add `sample`, priority normal
     start and wait 3 secs
     add "Normal Priority", priority normal
     add pause 0.5
     add "Message", priority normal
     should speak `sample`, and then "Normal Priority", pause 0.5, "Message"
     */
    func test6_same_priority_with_pause_should_not_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var count = 0
        var start: TimeInterval = 0
        tts.append(entry: SpeechEntry(text: sample, timeout_sec: 30) { item, reason in
            switch(reason) {
            case .Paused:
                XCTAssertTrue(false)
                break
            case .Completed:
                XCTAssertEqual(item.token?.text, self.sample)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Canceled:
                XCTAssertTrue(false)
                break
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: SpeechEntry(text: "Normal Priority", priority: .Normal, timeout_sec: 15) { item, reason in
                XCTAssertEqual(count, 1)
                count += 1
                start = Date().timeIntervalSince1970
            })
            tts.append(entry: PauseEntry(pause: 5, priority: .Normal, timeout_sec: 15) { item, reason in
                XCTAssertEqual(count, 2)
                count += 1
                let end = Date().timeIntervalSince1970
                XCTAssertLessThan(abs((end - start) - 0.5), 0.1)
            })
            tts.append(entry: SpeechEntry(text: "Message", priority: .Normal, timeout_sec: 15) { item, reason in
                XCTAssertEqual(count, 3)
                count += 1
                expectation.fulfill()
            })
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
}
