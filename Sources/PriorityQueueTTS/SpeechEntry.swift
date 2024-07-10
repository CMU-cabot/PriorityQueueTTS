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

import Foundation
import AVFoundation

class SpeechEntry: QueueEntry {
    init(
        text: String,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        super.init(token: Token.Text(text), priority: priority, timeout_sec: timeout_sec, completion: completion)
    }

    override func finish(with range: NSRange?) {
        guard let range = range else { return }
        if let result = self._token?.udpate(with: range), result == false {
            completed = true
        }
    }
}

extension String {
    func substring(after range: NSRange) -> String? {
        guard let rangeStart = Range(range, in: self) else { return nil }
        let startIndex = rangeStart.upperBound
        return String(self[startIndex...])
    }
}

