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
}
