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

final class PriorityQueueTTSHelperTests: XCTestCase {

    let sample: String = "This is a sample message... all the message should be read"

    func test1_add_pause() throws {
        let item = TokenizerEntry(separator: ".")
        try? item.append(text: sample)
        item.close()
        XCTAssertEqual(item.tokens.count, 3)
        XCTAssertEqual(item.tokens[0].text, "This is a sample message")
        XCTAssertEqual(item.tokens[1].pause, 3)
        XCTAssertEqual(item.tokens[2].text, " all the message should be read")
    }

    func test2_process_tokenizer_item() throws {
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
}
