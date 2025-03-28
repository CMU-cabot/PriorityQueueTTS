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

public enum TokenizerError: Error {
    case runtimeError(String)
}

public class TokenizerEntry: QueueEntry {
    let separators: [String]

    private var _buffer: String = ""
    private var separatorCount: Int
    private var cursor: Int
    private var startIndex: String.Index
    private var closed: Bool
    private var _completion: ((_: QueueEntry, _: Token?, _: CompletionReason) -> Void)? = nil

    public init(
        separators: [String],
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        tag: Tag = .Default,
        volume :Float? = nil,
        speechRate :Float? = nil,
        voice :AVSpeechSynthesisVoice? = nil,
        completion: ((_: QueueEntry, _: Token?, _: CompletionReason) -> Void)? = nil
    ) {
        self.separators = separators
        self.separatorCount = 0
        self.cursor = 0
        self.startIndex = _buffer.startIndex
        self.closed = false
        self._completion = completion
        super.init(token: nil, priority: priority, timeout_sec: timeout_sec, tag: tag, volume: volume, speechRate: speechRate, voice: voice, completion: nil)
        self.completion = { entry, token, reason in
            switch(reason) {
            case .Completed:
                self.tokenIndex += 1
                break
            case .Paused, .Canceled:
                break
            }
            guard let _completion = self._completion else { return }
            _completion(entry, token, reason)
        }
    }

    public func append(text: String) throws {
        guard self.closed == false else { throw TokenizerError.runtimeError("already completed") }
        _buffer.append(text)
        process()
    }

    public func close() {
        _tokens.append(Token.Text(String(_buffer[startIndex...])))
        self.closed = true
    }

    private func flushSeparator() {
        if separatorCount == 1 {
            let endIndex = _buffer.index(_buffer.startIndex, offsetBy: cursor)
            let substring = String(_buffer[startIndex..<endIndex])
            _tokens.append(Token.Text(substring))
            startIndex = endIndex
        } else if separatorCount >= 2 {
            let endIndex = _buffer.index(_buffer.startIndex, offsetBy: cursor - separatorCount)
            let substring = String(_buffer[startIndex..<endIndex])
            _tokens.append(Token.Text(substring))
            _tokens.append(Token.Pause(separatorCount))
            startIndex = _buffer.index(endIndex, offsetBy: separatorCount)
        }
        separatorCount = 0
    }

    private func process() {
        while cursor < _buffer.count {
            let index = _buffer.index(_buffer.startIndex, offsetBy: cursor)
            let char = String(_buffer[index])
            if separators.contains(char) {
                separatorCount += 1
            } else {
                flushSeparator()
            }
            cursor += 1
        }
        flushSeparator()
    }

    override func progress(with range: NSRange?) {
        guard _tokens.count > tokenIndex else { return }
        guard let range = range else { return }
        _ = _tokens[tokenIndex].readingRange = range
    }

    override func finish(with range: NSRange?) {
        if let token = self.token {
            switch token.type {
            case .Text:
                if let range = range,
                   let result = self.token?.udpate(with: range), result == false {
                    tokenIndex += 1
                }
                break
            case .Pause:
                tokenIndex += 1
            }
        }
        if closed {
            if _tokens.count <= tokenIndex {
                mark_completed()
            }
        }
    }
}
