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

// abstract class QueueEntry
// higher priority first
// earier created first
class QueueEntry: Comparable {
    var token: Token? {
        get {
            _token
        }
    }
    internal var _token: Token?
    let priority: SpeechPriority
    let created_time: TimeInterval
    let expire_at: TimeInterval
    var completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)?
    internal var completed: Bool = false

    init(
        token: Token,
        priority: SpeechPriority,
        timeout_sec: TimeInterval,
        completion: ((_: QueueEntry, _: CompletionReason) -> Void)?
    ) {
        self._token = token
        self.priority = priority
        self.created_time = Date().timeIntervalSince1970
        self.expire_at = self.created_time + timeout_sec
        self.completion = completion
    }

    convenience init(
        pause: Int,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.init(token: Token.Pause(pause), priority: priority, timeout_sec: timeout_sec, completion: completion)
    }

    convenience init(
        text: String,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.init(token: Token.Text(text), priority: priority, timeout_sec: timeout_sec, completion: completion)
    }

    func is_completed() -> Bool {
        return completed
    }

    func finish(with range: NSRange?) {
        guard let token = _token else { return }
        switch token.type {
        case .Text:
            guard let range = range else { return }
            if let result = self._token?.udpate(with: range), result == false {
                completed = true
            }
            break
        case .Pause:
            completed = true
            break
        }
    }

    // Comparable
    static func < (lhs: QueueEntry, rhs: QueueEntry) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.created_time > rhs.created_time
        }
        return lhs.priority.rawValue < rhs.priority.rawValue
    }
    static func == (lhs: QueueEntry, rhs: QueueEntry) -> Bool {
        return lhs.priority == rhs.priority && lhs.created_time == rhs.created_time
    }
}
