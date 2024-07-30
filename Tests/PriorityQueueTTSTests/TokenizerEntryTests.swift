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

final class TokenizerEntryTests: XCTestCase {

    let sample: String = "This is a sample message. All the message should be read"
    let sample_pause: String = "This is a sample message... All the message should be read"
    let long_sample: String = "This is a sample message. All the message should be read. This is a sample message. All the message should be read."
    let long_sample_pause: String = "This is a sample message... All the message should be read... This is a sample message... All the message should be read."

    func test1_add_pause() throws {
        let item = TokenizerEntry(separator: ".")
        try? item.append(text: sample_pause)
        item.close()
        XCTAssertEqual(item.tokens.count, 3)
        XCTAssertEqual(item.tokens[0].text, "This is a sample message")
        XCTAssertEqual(item.tokens[1].pause, 3)
        XCTAssertEqual(item.tokens[2].text, " All the message should be read")
    }

    func test2_process_tokenizer_item() throws {
        let expectation = self.expectation(description: "Wait for 15 seconds")
        let tts = PriorityQueueTTS()
        let item = TokenizerEntry(separator: ".") { entry, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        }
        try? item.append(text: sample_pause)
        item.close()
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 15, handler: nil)
    }

    func test3_no_pause() throws {
        let item = TokenizerEntry(separator: ".")
        try? item.append(text: sample)
        item.close()
        XCTAssertEqual(item.tokens.count, 2)
        XCTAssertEqual(item.tokens[0].text, "This is a sample message.")
        XCTAssertEqual(item.tokens[1].text, " All the message should be read")
    }

    func test3_2_process_tokenizer_item() throws {
        let expectation = self.expectation(description: "Wait for 15 seconds")
        let tts = PriorityQueueTTS()
        let item = TokenizerEntry(separator: ".") { entry, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        }
        try? item.append(text: sample)
        item.close()
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 15, handler: nil)
    }

    func test4_streaming() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var response = 0
        let item = TokenizerEntry(separator: ".", timeout_sec: 30) { entry, reason in
            response += 1
            if (response == 4) {
                expectation.fulfill()
            }
        }
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {timer in
            let text = self.long_sample
            if count < text.count {
                let index = text.index(text.startIndex, offsetBy: count)
                let character = text[index]
                try? item.append(text: String(character))
                count += 1
            } else {
                timer.invalidate()
                item.close()
            }
        }
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    func test5_streaming_with_pause() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var response = 0
        let item = TokenizerEntry(separator: ".", timeout_sec: 30) { entry, reason in
            response += 1
            if (response == 7) {
                expectation.fulfill()
            }
        }
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {timer in
            let text = self.long_sample_pause
            if count < text.count {
                let index = text.index(text.startIndex, offsetBy: count)
                let character = text[index]
                try? item.append(text: String(character))
                count += 1
            } else {
                timer.invalidate()
                item.close()
            }
        }
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 30, handler: nil)
    }

    func test6_tts_delegate_check_token() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let token = entry.token,
                      let spokenText = token.spokenText,
                      let speakingText = token.speakingText,
                      let willSpeakText = token.willSpeakText
                      else { return }
                XCTAssertEqual(token.text, spokenText + speakingText + willSpeakText)
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
        tts.delegate = delegate
        let item = TokenizerEntry(separator: ".", timeout_sec: 30) { entry, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        }
        try item.append(text: sample)
        item.close()
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    func test7_tts_delegate_check_entry() throws {
        let expectation = self.expectation(description: "Wait for 10 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
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
        let item = TokenizerEntry(separator: ".", timeout_sec: 30) { entry, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        }
        try item.append(text: sample)
        item.close()
        tts.append(entry: item)
        tts.start()
        waitForExpectations(timeout: 10, handler: nil)
    }

    func test8_tts_delegate_check_entry_interrupt() throws {
        let expectation = self.expectation(description: "Wait for 15 seconds")
        let tts = PriorityQueueTTS()
        class Delegate: PriorityQueueTTSDelegate {
            func completed(queue: PriorityQueueTTS, entry: QueueEntry) {
                guard let text = entry.text,
                      let spokenText = entry.spokenText,
                      let speakingText = entry.speakingText,
                      let willSpeakText = entry.willSpeakText
                      else { return }
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
                XCTAssertEqual(text, spokenText + speakingText + willSpeakText)
            }
        }
        let delegate = Delegate()
        tts.delegate = delegate
        let item = TokenizerEntry(separator: ".", timeout_sec: 30) { entry, reason in
            if reason == .Completed {
                expectation.fulfill()
            }
        }
        try item.append(text: sample)
        item.close()
        tts.append(entry: item)
        tts.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            tts.append(entry: QueueEntry(text: "High Priority Message", priority: .High, timeout_sec: 1) { item, utterance, reason in
            })
        }
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    /*  [
            (TAG:"A", .Normal) // stop-replace
        ]
        <<  (TAG:"A", .Normal)
     */
    func test9_tag_replace_1() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        let entry1 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertEqual(0, step.pass())
            case .Completed:
                XCTFail()
            case .Paused:
                break
            }
        }
        try? entry1.append(text: sample_pause)
        entry1.close()
        tts.append(entry: entry1)
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 2)  (TAG:"A", .Normal)
            let entry2 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
                switch(reason) {
                case .Paused:
                    XCTAssertEqual(1, step.pass())
                case .Completed:
                    XCTAssertEqual(2, step.pass())
                    expectation.fulfill()
                case .Canceled:
                    XCTFail()
                }
            }
            try? entry2.append(text:"(TAG:A, .Normal)")
            entry2.close()
            tts.append(entry: entry2, withRemoving: SameTag)
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            (TAG:"A", .Normal) // stop-replace
            (TAG:"A", .Normal) // remove
        ]
        <<  (TAG:"A", .Normal)
     */
    func test10_tag_replace_2() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        let entry1 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            case .Completed:
                XCTFail()
            case .Paused:
                break
            }
        }
        try? entry1.append(text: sample_pause)
        entry1.close()
        tts.append(entry: entry1)
        
        // 2) (TAG:"A", .Normal) // remove
        let entry2 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            case .Completed:
                XCTFail()
            case .Paused:
                break
            }
        }
        try? entry2.append(text: "2) (TAG:A, .Normal) // remove")
        entry2.close()
        tts.append(entry: entry2)

        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 3)  (TAG:"A", .Normal)
            let entry3 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
                switch(reason) {
                case .Paused:
                    XCTAssertEqual(2, step.pass())
                case .Completed:
                    XCTAssertEqual(3, step.pass())
                    expectation.fulfill()
                case .Canceled:
                    XCTFail()
                }
            }
            try? entry3.append(text:"3) (TAG:A, .Normal)")
            entry3.close()
            tts.append(entry: entry3, withRemoving: SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"Def", .Normal) // keep
            (TAG:"A", .Normal) // remove
        ]
        <<  (TAG:"A", .Normal)
     */
    func test11_tag_replace_keep_remove() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"Def", .Normal) // keep
        let entry1 = TokenizerEntry(separator: ".") { entry, reason in
            switch(reason) {
            case .Paused:
                XCTAssertTrue( (0...2).contains(step.pass()) )
            case .Completed:
                XCTAssertEqual(3, step.pass())
            case .Canceled:
                XCTFail()
            }
        }
        try? entry1.append(text: sample_pause)
        entry1.close()
        tts.append(entry: entry1)
        
        // 2) (TAG:"A", .Normal) // remove
        let entry2 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...2).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        try? entry2.append(text: "2) (TAG:A, .Normal) // remove")
        entry2.close()
        tts.append(entry: entry2)

        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // 3)  (TAG:"A", .Normal)
            let entry3 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
                switch(reason) {
                case .Paused:
                    XCTAssertEqual(4, step.pass())
                case .Completed:
                    XCTAssertEqual(5, step.pass())
                    expectation.fulfill()
                case .Canceled:
                    XCTFail()
                }
            }
            try? entry3.append(text:"3) (TAG:A, .Normal)")
            entry3.close()
            tts.append(entry: entry3, withRemoving: SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }

    /*  [
            (TAG:"Def", .High) // interrupt
            (TAG:"A", .Normal) // remove
        ]
        <<  (TAG:"A", .Required)
     */
    func test12_tag_interrupt_remove() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1) (TAG:"Def", .High) // interrupt
        let entry1 = TokenizerEntry(separator: ".", priority: .High) { entry, reason in
            switch(reason) {
            case .Paused:
                XCTAssertTrue( Set([0,1,4,5]).contains(step.pass()) )
            case .Completed:
                XCTAssertEqual(6, step.pass())
                expectation.fulfill()
            case .Canceled:
                XCTFail()
            }
        }
        try? entry1.append(text: sample_pause)
        entry1.close()
        tts.append(entry: entry1)
        
        // 2) (TAG:"A", .Normal) // remove
        let entry2 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( Set([0,1]).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        try? entry2.append(text: "2) (TAG:A, .Normal) // remove")
        entry2.close()
        tts.append(entry: entry2)

        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 3) (TAG:"A", .Required)
            let entry3 = TokenizerEntry(separator: ".", priority: .Required, tag: "A") { entry, reason in
                switch(reason) {
                case .Paused:
                    XCTAssertEqual(2, step.pass())
                case .Completed:
                    XCTAssertEqual(3, step.pass())
                case .Canceled:
                    XCTFail()
                }
            }
            try? entry3.append(text:"3) (TAG:A, .Required)")
            entry3.close()
            tts.append(entry: entry3, withRemoving: SameTag)
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            1. (Text TAG:"A") // stop-replace not closed
        ]
        wait 1s from start()
            << 2. (Text TAG:"A")
        wait 3s from start()
            (1. append text, close)
     */
    func test13_tag_replace_before_close() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1. (Text TAG:"A") // stop-replace not closed
        let entry1 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
            switch(reason) {
            case .Canceled:
                XCTAssertTrue( (0...1).contains(step.pass()) )
            default:
                XCTFail()
            }
        }
        try? entry1.append(text: sample_pause)
        tts.append(entry: entry1)
        
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //  << 2. (Text TAG:"A")
            let entry2 = TokenizerEntry(separator: ".", tag: "A") { entry, reason in
                switch(reason) {
                case .Paused:
                    XCTAssertTrue( (0...1).contains(step.pass()) )
                case .Completed:
                    XCTAssertEqual(2, step.pass())
                case .Canceled:
                    XCTFail()
                }
            }
            try? entry2.append(text: "<< 2. (Text TAG:A)")
            entry2.close()
            tts.append(entry: entry2, withRemoving: SameTag)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            // (1. append text, close)
            do {
                try entry1.append(text: "may be cancelled")
                entry1.close()
            }
            catch {
                XCTFail()
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    /*  [
            1. (Text .Normal, timeout: 4s) // interrupt -> timeout
        ]
        wait 1s from start()
             << 2. (Pause:3s .Required)
             << 3. (Text .Required)
     */
    func test14_interrupt_timeout() throws {
        let expectation = self.expectation(description: "Wait for 30 seconds")
        let tts = PriorityQueueTTS()
        var step : Int = 0;

        // 1. (Text .Normal) // interrupt -> timeout
        let entry1 = TokenizerEntry(separator: ".", priority: .Normal, timeout_sec: 4) { entry, reason in
            switch(reason) {
            case .Paused:
                XCTAssertEqual(0, step.pass())
            case .Canceled:
                XCTAssertEqual(3, step.pass())
                expectation.fulfill()
            default:
                XCTFail()
            }
        }
        try? entry1.append(text: sample_pause)
        entry1.close()
        tts.append(entry: entry1)
        tts.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //  << 2. (Pause:3s .Required)
            tts.append(entry: QueueEntry(pause: 30, priority: .Required) { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual(1, step.pass() )
                default:
                    XCTFail()
                }
            })
            //  << 3. (Text .Required)
            tts.append(entry: QueueEntry(text: "<< 3. (Text .Required)", priority: .Required) { item, _, reason in
                switch(reason) {
                case .Completed:
                    XCTAssertEqual(2, step.pass() )
                default:
                    XCTFail()
                }
            })
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
}
