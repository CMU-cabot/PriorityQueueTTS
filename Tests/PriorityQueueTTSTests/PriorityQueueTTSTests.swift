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
import AVFoundation
@testable import PriorityQueueTTS

final class PriorityQueueTTSTests: XCTestCase {
    let sample: String = "This is a sample message, all the message should be read"

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
        tts.append(entry: QueueEntry(text: "Hello1") { item, token, canceld in
            XCTAssertEqual(count, 1)
            count += 1
        })
        tts.append(entry: QueueEntry(text: "Hello2") { item, token, canceld in
            XCTAssertEqual(count, 2)
            count += 1
            expectation.fulfill()
        })
        tts.append(entry: QueueEntry(text: "Hello3", priority: .High) { item, token, canceld in
            XCTAssertEqual(count, 0)
            count += 1
        })
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

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
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30.0) { item, token, reason in
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
            tts.append(entry: QueueEntry(text: "High Priority Message", priority: .High, timeout_sec: 1) { item, token, reason in
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
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
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
            tts.append(entry: QueueEntry(text: "Normal Priority Message", priority: .Normal, timeout_sec: 15) { item, token, reason in
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
        tts.append(entry: QueueEntry(text: "Hello1", timeout_sec: 10) { item, token, reason in
            XCTAssertEqual(count, 0)
            count += 1
            start = Date().timeIntervalSince1970
        })
        tts.append(entry: QueueEntry(pause: 10, timeout_sec: 10) { item, token, reason in
            XCTAssertEqual(count, 1)
            count += 1
            let end = Date().timeIntervalSince1970
            XCTAssertLessThan(abs((end - start) - 1.0), 0.2)
        })
        tts.append(entry: QueueEntry(text: "Hello2", timeout_sec: 10) { item, token, reason in
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
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual(self.sample, item.token?.text)
                XCTAssertEqual(count, 0)
                count += 1
                break
            case .Completed:
                if let textCount = token?.text?.count {
                    XCTAssertLessThanOrEqual(textCount, self.sample.count)
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
            tts.append(entry: QueueEntry(text: "High Priority", priority: .High, timeout_sec: 1) { item, token, reason in
                XCTAssertEqual(count, 1)
                count += 1
                start = Date().timeIntervalSince1970
            })
            tts.append(entry: QueueEntry(pause: 5, priority: .High, timeout_sec: 3) { item, token, reason in
                XCTAssertEqual(count, 2)
                count += 1
                let end = Date().timeIntervalSince1970
                XCTAssertLessThan(abs((end - start) - 0.5), 0.1)
            })
            tts.append(entry: QueueEntry(text: "Message", priority: .High, timeout_sec: 5) { item, token, reason in
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
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
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
            tts.append(entry: QueueEntry(text: "Normal Priority", priority: .Normal, timeout_sec: 15) { item, token, reason in
                XCTAssertEqual(count, 1)
                count += 1
                start = Date().timeIntervalSince1970
            })
            tts.append(entry: QueueEntry(pause: 5, priority: .Normal, timeout_sec: 15) { item, token, reason in
                XCTAssertEqual(count, 2)
                count += 1
                let end = Date().timeIntervalSince1970
                XCTAssertLessThan(abs((end - start) - 0.5), 0.1)
            })
            tts.append(entry: QueueEntry(text: "Message", priority: .Normal, timeout_sec: 15) { item, token, reason in
                XCTAssertEqual(count, 3)
                count += 1
                expectation.fulfill()
            })
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    func test7_tts_delegate_check_token() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            var expectation: XCTestExpectation?
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let token = entry.token,
                      let text = token.text,
                      let spokenText = token.spokenText,
                      let speakingText = token.speakingText,
                      let willSpeakText = token.willSpeakText
                      else { return }
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
                expectation?.fulfill()
            }
            func progress(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let token = entry.token,
                      let text = token.text,
                      let spokenText = token.spokenText,
                      let speakingText = token.speakingText,
                      let willSpeakText = token.willSpeakText
                      else { return }
                if speakingText.count > 0 {
                    print("\(spokenText)\"\(speakingText)\"\(willSpeakText)")
                } else {
                    print("\(spokenText)\(speakingText)\(willSpeakText)")
                }
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
            }
        }
        let delegate = Delegate()
        delegate.expectation = expectation
        tts.delegate = delegate
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
        })
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    func test8_tts_delegate_check_entry() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            var expectation: XCTestExpectation?
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
                expectation?.fulfill()
            }
            func progress(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
                if speakingText.count > 0 {
                    print("\(spokenText)\"\(speakingText)\"\(willSpeakText)")
                } else {
                    print("\(spokenText)\(speakingText)\(willSpeakText)")
                }
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
            }
        }
        let delegate = Delegate()
        delegate.expectation = expectation
        tts.delegate = delegate
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
        })
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    func test9_tts_delegate_check_entry_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
                print("completed: \(text) = \(spokenText)\(speakingText)\(willSpeakText)")
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
            }
            func progress(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
                if speakingText.count > 0 {
                    print("\(spokenText)\"\(speakingText)\"\(willSpeakText)")
                } else {
                    print("\(spokenText)\(speakingText)\(willSpeakText)")
                }
                if spokenText + speakingText + willSpeakText != text {
                    print("error")
                }
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
            }
        }
        let delegate = Delegate()
        tts.delegate = delegate
        tts.append(entry: QueueEntry(text: sample, timeout_sec: 30) { item, token, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        })
        tts.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: QueueEntry(text: "High Priority Message", priority: .High, timeout_sec: 1) { item, token, reason in
            })
        }
        waitForExpectations(timeout: 30, handler: nil)
    }

    
    /*  [
        ]
        <<  (TAG:"A", .Normal)
     */
    func test_10_tag_empty() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // <<  (TAG:"A", .Normal)
            let entry1 = QueueEntry(text:self.sample, priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 0, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry1, withRemoving:SameTag)
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"Def", .Normal) // keep
        ]
        <<  (TAG:"A", .Normal)
     */
    func test_11_tag_same_levels_no_remove() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"Def", .Normal) // keep
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // <<   (TAG:"A", .Normal)
            let entry2 = QueueEntry(text:"entry2: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"Def", .Normal) // keep
            (TAG:"Def", .Normal) // keep
        ]
        <<  (TAG:"A", .Normal)
     */
    func test_12_tag_no_remove() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"Def", .Normal) // keep
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        
        // 2) (TAG:"Def", .Normal) // keep
        let entry2 = QueueEntry(text: "entry2: (TAG:Def, .Normal)", priority: .Normal, timeout_sec: 30 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 1, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 3) (TAG:"A", .Normal)
            let entry3 = QueueEntry(text:"entry3: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 2, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry3, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"A", .Normal) // stop-replace
        ]
        <<  (TAG:"A", .Normal)
     */
    func test_13_tag_replace_1() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1)  (TAG:"A", .Normal) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30, tag: "A" ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 2) (TAG:"A", .Normal)
            let entry2 = QueueEntry(text:"entry2: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"A", .Normal) // stop-replace
            (TAG:"A", .Normal) // remove
            (TAG:"A", .Normal) // remove
        ] // exsit entries are not filterd
        <<  (TAG:"A", .Normal)
     */
    func test_14_tag_replace_all() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"A", .Normal) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...2).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        
        // 2) (TAG:"A", .Normal) // remove
        let entry2 = QueueEntry(text:"entry2: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...2).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)
        
        // 3) (TAG:"A", .Normal) // remove
        let entry3 = QueueEntry(text:"entry3 : (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...2).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry3)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // <<  <<  (TAG:"A", .Normal)
            let entry4 = QueueEntry(text:"entry4 : (TAG:A, .Normal)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 3, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry4, withRemoving:SameTag)
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"A", .Normal) // stop-replace
        ]
        <<  (TAG:"A", .High)
     */
    func test_15_tag_replace_1() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"A", .Normal) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30, tag: "A" ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 2) (TAG:"A", .High)
            let entry2 = QueueEntry(text:"entry2: (TAG:A, .High)", priority: .High, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"A", .High) // stop-replace
        ]
        <<  (TAG:"A", .Normal)
     */
    func test_16_tag_regardless_priority() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"A", .High) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .High, timeout_sec: 30, tag: "A" ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 2) (TAG:"A", .Normal)
            let entry2 = QueueEntry(text:"entry2: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"A", .High) // stop-replace
            (TAG:"Def", .Normal) // keep
        ]
        <<  (TAG:"A", .High)
     */
    func test_17_tag() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"A", .High) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .High, timeout_sec: 30, tag: "A" ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        // 2) (TAG:"Def", .Normal) // keep
        let entry2 = QueueEntry(text: "entry2: (TAG:Def, .Normal)", priority: .Normal, timeout_sec: 30 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 2, step.pass() )
                expectation.fulfill()
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 3) (TAG:"A", .High)
            let entry3 = QueueEntry(text:"entry3: (TAG:A, .High)", priority: .High, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry3, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"Def", .High) // keep
            (TAG:"A", .Normal) // remove
        ]
        <<  (TAG:"A", .High)
     */
    func test_18_tag() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"Def", .High) // keep
        let entry1 = QueueEntry(text: sample, priority: .High, timeout_sec: 30 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 1, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)

        // 2) (TAG:"A", .Normal) // remove
        let entry2 = QueueEntry(text: "entry2: (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A" ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 3) (TAG:"A", .High)
            let entry3 = QueueEntry(text:"entry3: (TAG:A, .High)", priority: .High, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 2, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry3, withRemoving:SameTag)
        }
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"Def", .High) // interrupt
            (TAG:"A", .Normal) // remove
        ]
        <<  (TAG:"A", .Required)
     */
    func test_19_tag_interrupt_remove() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1) (TAG:"Def", .High) // interrupt
        let entry1 = QueueEntry(text: sample, priority: .High, timeout_sec: 30) { item, _, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual( 0, step.pass() )
            case .Completed:
                XCTAssertEqual( 2, step.pass() )
                expectation.fulfill()
            case .Canceled:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        
        // 2) (TAG:"A", .Normal) // remove
        let entry2 = QueueEntry(text:"entry2 : (TAG:A, .Normal)", priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue(true)
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // <<  (TAG:"A", .Required)
            let entry3 = QueueEntry(text:"entry3 : (TAG:A, .Required)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry3, withRemoving:SameTag)
        }
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"A", .Required) // stop-replace
        ]
         <<  (TAG:"A", .Required) // stop-replace
         <<  (TAG:"A", .Required)
     */
    func test_20_tag_interrupt_periodically() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1) (TAG:"A", .Required) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        tts.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 2) (TAG:"A", .Required) // stop-replace
            let entry2 = QueueEntry(text:"entry2 : (TAG:A, .Required)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Canceled:
                    XCTAssertEqual( 1, step.pass() )
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                // << 3) (TAG:"A", .Required)
                let entry3 = QueueEntry(text:"entry3 : (TAG:A, .Required)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                    switch(reason) {
                    case .Completed:
                        XCTAssertEqual( 2, step.pass() )
                        expectation.fulfill()
                    default:
                        XCTFail()
                    }
                }
                tts.append(entry:entry3, withRemoving:SameTag)
            }
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (PAUSE  TAG:"A", 30sec) // stop-replace
        ]
         <<  (TAG:"A", .Required)
     */
    func test_21_tag_stop_pause() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1) (PAUSE  TAG:"A", 30sec) // stop-replace
        let entry1 = QueueEntry( pause: 300, tag: "A") { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTFail()
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 2) (TAG:"A", .Required) // stop-replace
            let entry2 = QueueEntry(text:"entry2 : (TAG:A, .Required)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"A", .Normal) // stop-replace
            (PAUSE  TAG:"A", 30sec, .Normal) // remove
        ]
         <<  (TAG:"A", .Normal)
     */
    func test_22_tag_remove_contain_pause() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1) (TAG:"A", .Normal) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        
        // 2) (PAUSE  TAG:"A", 30sec) // stop-replace
        let entry2 = QueueEntry( pause: 300, priority: .Normal, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry2)
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 2) (TAG:"A", .Required) // stop-replace
            let entry3 = QueueEntry(text:"entry3 : (TAG:A, .Required)", priority: .Required, timeout_sec: 30, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 2, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry3, withRemoving:SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"A", .Normal) // stop-replace
        ]
         <<  (PAUSE  TAG:"A", 3sec, .Normal)
     */
    func test_23_tag_cancel_by_pause() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1) (TAG:"A", .Normal) // stop-replace
        let entry1 = QueueEntry(text: sample, priority: .Normal, timeout_sec: 30, tag: "A") { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        }
        tts.append(entry:entry1)
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 2)  (PAUSE  TAG:"A", 3sec, .Normal)
            let entry2 = QueueEntry( pause: 30, priority: .Normal, tag: "A") { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 1, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            }
            tts.append(entry:entry2, withRemoving:SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            1. (Text timeout: 1s )     // keep
            2. (Pause: 3s, timeout: 10s ) // keep
            3. (Pause: 3s, timeout: 1s )  // timeout
            4. (Text  timeout: 10s )   // keep
            5. (Text  timeout: 2s )    // timeout
            6. (Text  timeout: 3s )    // timeout
            7. (Text  timeout: 20s )   // keep
        ]
        
        wait 1s
          <<  8. (Text  timeout: 5s )      // timeout
          <<  9. (Pause: 3s, timeout: 5s ) // timeout
          << 10. (Text  timeout: 30s )     // keep
     */
    func test_24_timeout() throws {
        let expectation = self.expectation(description: "Wait for 40 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;
        
        // 1. (Text timeout: 1s )     // keep
        tts.append(entry: QueueEntry(text:"1. (Text timeout: 1s ) // keep", timeout_sec: 1 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 0, step.pass() )
            default:
                XCTFail()
            }
        })
        
        // 2. (Pause: 3s, timeout: 10s ) // keep
        tts.append(entry: QueueEntry( pause: 30, timeout_sec: 10 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 1, step.pass() )
            default:
                XCTFail()
            }
        })

        // 3. (Pause: 3s, timeout: 1s )  // timeout
        tts.append(entry: QueueEntry( pause: 30, timeout_sec: 1 ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 2, step.pass() )
            default:
                XCTFail()
            }
        })
        
        // 4. (Text  timeout: 10s )   // keep
        tts.append(entry: QueueEntry(text:"4. (Text  timeout: 10s ) // keep", timeout_sec: 10 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 3, step.pass() )
            default:
                XCTFail()
            }
        })
        
        // 5. (Text  timeout: 2s )    // timeout
        tts.append(entry: QueueEntry(text:"5. (Text  timeout: 2s ) // timeout", timeout_sec: 2 ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 4, step.pass() )
            default:
                XCTFail()
            }
        })
        
        // 6. (Text  timeout: 3s )    // timeout
        tts.append(entry: QueueEntry(text:"6. (Text  timeout: 3s ) // timeout", timeout_sec: 3 ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual( 5, step.pass() )
            default:
                XCTFail()
            }
        })
        
        // 7. (Text  timeout: 20s )   // keep
        tts.append(entry: QueueEntry(text:"7. (Text  timeout: 20s ) // keep", timeout_sec: 20 ) { item, _, reason in
            switch(reason) {
            case .Completed:
                XCTAssertEqual( 6, step.pass() )
            default:
                XCTFail()
            }
        })

        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            // <<  8. (Text  timeout: 5s )      // timeout
            tts.append(entry: QueueEntry(text:"<< 8. (Text timeout: 5s ) // timeout", timeout_sec: 5 ) { item, _, reason in
                switch(reason) {
                case .Canceled:
                    XCTAssertEqual( 7, step.pass() )
                default:
                    XCTFail()
                }
            })

            // <<  9. (Pause: 3s, timeout: 5s ) // timeout
            tts.append(entry: QueueEntry( pause: 30, timeout_sec: 5 ) { item, _, reason in
                switch(reason) {
                case .Canceled:
                    XCTAssertEqual( 8, step.pass() )
                default:
                    XCTFail()
                }
            })
            
            // 10. (Text  timeout: 30s )     // keep
            tts.append(entry: QueueEntry(text:"<< 10. (Text timeout: 30s ) // keep", timeout_sec: 30 ) { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 9, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            })
        }

        waitForExpectations(timeout: 40, handler: nil)
    }
    
    /*  [
            1. (Text)
            2. (Pause: 3s)
        ]
        
        wait 1s from start()
          <<  3. (Text)
        wait 2s from start()
            cancel
     */
     func test_25_cancel_all() throws {
         let expectation = self.expectation(description: "Wait for 30 seconds")
         let tts = PriorityQueueTTS()
         var step : Int = 0;

         // 1. (Text)
         tts.append(entry: QueueEntry(text:sample ) { item, _, reason in
             switch(reason) {
             case .Canceled:
                 XCTAssertTrue( (0...2).contains(step.pass()) )
                 if step == 2 { expectation.fulfill() }
             default:
                 XCTFail()
             }
         })
         
         // 2. (Pause: 3s)
         tts.append(entry: QueueEntry( pause: 30 ) { item, _, reason in
             switch(reason) {
             case .Canceled:
                 XCTAssertTrue( (0...2).contains(step.pass()) )
                 if step == 2 { expectation.fulfill() }
             default:
                 XCTFail()
             }
         })

         tts.start()

         DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
             // <<  3. (Text)
             tts.append(entry: QueueEntry(text:"<<  3. (Text)" ) { item, _, reason in
                 switch(reason) {
                 case .Canceled:
                     XCTAssertTrue( (0...2).contains(step.pass()) )
                     if step == 2 { expectation.fulfill() }
                 default:
                     XCTFail()
                 }
             })
         }

         DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
             tts.cancel()
         }

         waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            1. (Pause: 3s)
            2. (Text)
        ]
        
        wait 1s from start()
            cancel
            << 3. (Text)
     */
    func test_26_cancel_pause_continue() throws {
        let expectation = self.expectation(description: "Wait for 50 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1. (Pause: 3s)
        tts.append(entry: QueueEntry( pause: 30 ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            default:
                XCTFail()
            }
        })
        // 2. (Text)
        tts.append(entry: QueueEntry(text:sample ) { item, _, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            default:
                XCTFail()
            }
        })
        tts.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            tts.cancel()
            
            // << 3. (Text)
            tts.append(entry: QueueEntry(text:"<< 3. (Text)" ) { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual( 2, step.pass() )
                    expectation.fulfill()
                default:
                    XCTFail()
                }
            })
        }
        
        waitForExpectations(timeout: 50, handler: nil)
   }
    
    
    /*  [
            1. (Voice:default)
            2. (Voice:Fred, slowly, volume min)
            3. (Voice:default)
        ]
     */
    func test_27_speach_options() throws {
        guard let fredVoice = AVSpeechSynthesisVoice.init(identifier:"com.apple.speech.synthesis.voice.Fred")
        else { XCTFail("the voice is not exist"); return }
        
        
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step = 0
        tts.append(entry: QueueEntry(text: "default voice speaking") { item, token, reason in
            guard reason == .Completed
                else { XCTFail(); return }
            XCTAssertEqual( 0, step.pass() )
        })
        let vol :Float = 0.3
        let rate :Float = 0.1
        tts.append(entry: QueueEntry(text: "Fred speaking", volume:vol, speechRate:rate, voice: fredVoice) { item, token, reason in
            guard reason == .Completed
                else { XCTFail(); return }
            
            XCTAssertEqual( 1, step.pass() )
        })
        tts.append(entry: QueueEntry(text: "default voice speaking") { item, token, reason in
            guard reason == .Completed
                else { XCTFail(); return }
            XCTAssertEqual( 2, step.pass() )
            expectation.fulfill()
        })
        
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    
    func test_28_stop_speaking() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step = 0
        tts.append(entry: QueueEntry(text: "this is first message.", priority: .Required) { item, token, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual( 0, step.pass() )
            case .Completed:
                XCTAssertEqual( 1, step.pass() )
            case .Canceled:
                XCTFail()
            }
        })
        tts.append(entry: QueueEntry(text: "this is second message.", priority: .Normal) { item, token, reason in
            guard reason == .Completed
                else { XCTFail(); return }
            XCTAssertEqual( 2, step.pass() )
            expectation.fulfill()
        })
        
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            tts.stopSpeaking(at: .immediate)
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
}


extension Int {
    mutating func pass() -> Self {
        let current = self
        self += 1
        return current
    }
}
