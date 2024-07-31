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
public class QueueEntry: Comparable {
    var token: Token? {
        get {
            if tokenIndex < _tokens.count {
                return _tokens[tokenIndex]
            }
            if _completed {
                return _tokens.last
            }
            return nil
        }
    }
    var tokens: [Token] {
        get {
            _tokens
        }
    }
    internal var _tokens: [Token] = []
    internal var tokenIndex: Int = 0
    public let priority: SpeechPriority
    public let created_time: TimeInterval
    public let expire_at: TimeInterval
    public var completion: ((_ entry: QueueEntry, _ utterance: AVSpeechUtterance?, _ reason: CompletionReason) -> Void)?
    public func is_completed() -> Bool {
        return _completed
    }
    internal var _completed: Bool = false

    init(
        token: Token?,
        priority: SpeechPriority,
        timeout_sec: TimeInterval,
        completion: ((_: QueueEntry, _: AVSpeechUtterance?, _: CompletionReason) -> Void)?
    ) {
        if let token = token {
            self._tokens = [token]
        }
        self.priority = priority
        self.created_time = Date().timeIntervalSince1970
        self.expire_at = self.created_time + timeout_sec
        self.completion = completion
    }

    convenience init(
        pause: Int,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ utteracne: AVSpeechUtterance?, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.init(token: Token.Pause(pause), priority: priority, timeout_sec: timeout_sec, completion: completion)
    }

    convenience init(
        text: String,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ utteracne: AVSpeechUtterance?, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.init(token: Token.Text(text), priority: priority, timeout_sec: timeout_sec, completion: completion)
    }

    func progress(with range: NSRange?) {
        guard _tokens.count > 0 else { return }
        guard let range = range else { return }
        _ = _tokens[0].readingRange = range
    }

    func finish(with range: NSRange?) {
        guard let token = _tokens.first else { return }
        switch token.type {
        case .Text:
            guard let range = range else { return }
            if _tokens[0].udpate(with: range) == false{
                _completed = true
            }
            break
        case .Pause:
            _completed = true
            break
        }
    }
    
    var text: String? {
        get {
            var text = ""
            for i in 0..<_tokens.count {
                if let tokenText = _tokens[i].text {
                    text += tokenText
                }
            }
            return text
        }
    }

    var spokenText: String? {
        get {
            var text = ""
            for i in 0..<min(tokenIndex, _tokens.count-1) {
                if let tokenText = _tokens[i].text {
                    text += tokenText
                }
            }
            if let token = self.token,
               let tokenText = token.spokenText {
                text += tokenText
            }
            return text
        }
    }

    var speakingText: String? {
        get {
            if let token = self.token,
               let tokenText = token.speakingText {
                return tokenText
            }
            return ""
        }
    }

    var willSpeakText: String? {
        get {
            var text = ""
            if let token = self.token,
               let tokenText = token.willSpeakText {
                text += tokenText
            }
            if tokenIndex+1 < _tokens.count {
                for i in tokenIndex+1..<_tokens.count {
                    if let tokenText = _tokens[i].text {
                        text += tokenText
                    }
                }
            }
            return text
        }
    }

    // Comparable
    public static func < (lhs: QueueEntry, rhs: QueueEntry) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.created_time > rhs.created_time
        }
        return lhs.priority.rawValue < rhs.priority.rawValue
    }
    public static func == (lhs: QueueEntry, rhs: QueueEntry) -> Bool {
        return lhs.priority == rhs.priority && lhs.created_time == rhs.created_time
    }
}
