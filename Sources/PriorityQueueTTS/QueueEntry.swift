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

class QueueEntry: Comparable {
    var text: String { get { "" } }  // should be overrided by Child class
    let priority: SpeechPriority
    let created_time: TimeInterval
    let expire_at: TimeInterval
    let completion: ((_ item: QueueEntry, _ reason: CompletionReason) -> Void)?

    init(
        priority: SpeechPriority,
        created_time: TimeInterval,
        expire_at: TimeInterval,
        completion: ((_: QueueEntry, _: CompletionReason) -> Void)?
    ) {
        self.priority = priority
        self.created_time = created_time
        self.expire_at = expire_at
        self.completion = completion
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
