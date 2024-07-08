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

class QeueEntry: Comparable {
    var text: String { get { "" } }  // should be overrided by Child class
    let priority: SpeechPriority
    let created_time: TimeInterval
    let expire_at: TimeInterval
    let completion: ((_ item: QeueEntry, _ reason: CompletionReason) -> Void)?

    init(
        priority: SpeechPriority,
        created_time: TimeInterval,
        expire_at: TimeInterval,
        completion: ((_: QeueEntry, _: CompletionReason) -> Void)?
    ) {
        self.priority = priority
        self.created_time = created_time
        self.expire_at = expire_at
        self.completion = completion
    }

    // Comparable
    static func < (lhs: QeueEntry, rhs: QeueEntry) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.created_time > rhs.created_time
        }
        return lhs.priority.rawValue < rhs.priority.rawValue
    }
    static func == (lhs: QeueEntry, rhs: QeueEntry) -> Bool {
        return lhs.priority == rhs.priority && lhs.created_time == rhs.created_time
    }
}

class PauseItem: QeueEntry {
    var duration: Double
    override var text: String {
        get {
            return "pause \(duration)"
        }
    }

    init(
        duration: Double,
        priority: SpeechPriority,
        created_time: TimeInterval,
        expire_at: TimeInterval,
        completion: ((_ item: QeueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.duration = duration
        super.init(priority: priority, created_time: created_time, expire_at: expire_at, completion: completion)
    }
}

// class SpeechItem
// higher priority first
// earier created first
class SpeechItem: QeueEntry {
    override var text: String {
        get {
            return _text
        }
    }
    var _text: String
    var _utterance: AVSpeechUtterance? = nil

    init(
        text: String,
        priority: SpeechPriority,
        created_time: TimeInterval,
        expire_at: TimeInterval,
        completion: ((_ item: QeueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self._text = text
        super.init(priority: priority, created_time: created_time, expire_at: expire_at, completion: completion)
    }
}

extension SpeechItem {
    var utterance: AVSpeechUtterance {
        get {
            if _utterance == nil {
                _utterance = AVSpeechUtterance(string: self.text)
            }
            return _utterance!
        }
    }

    func update(with range: NSRange) {
        if let newText = self.text.substring(from: range) {
            _text = newText
            _utterance = nil
        }
    }
}

extension String {
    func substring(from range: NSRange) -> String? {
        guard let rangeStart = Range(range, in: self) else { return nil }
        let startIndex = rangeStart.lowerBound
        return String(self[startIndex...])
    }
}

