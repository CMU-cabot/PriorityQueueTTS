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

enum TokenizerError: Error {
    case runtimeError(String)
}

class TokenizerEntry: QueueEntry {
    override var token: Token? {
        set {
            
        }
        get {
            if tokenIndex < _tokens.count {
                return _tokens[tokenIndex]
            }
            return nil
        }
    }
    let separator: String
    var tokens: [Token] {
        get {
            _tokens
        }
    }

    private var _tokens: [Token] = []
    private var tokenIndex: Int
    private var _buffer: String = ""
    private var separatorCount: Int
    private var cursor: Int
    private var startIndex: String.Index
    private var closed: Bool
    private var _completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)? = nil

    init(
        separator: String,
        priority: SpeechPriority = .Normal,
        timeout_sec: TimeInterval = 10.0,
        completion: ((_ entry: QueueEntry, _ reason: CompletionReason) -> Void)? = nil
    ) {
        self.separator = separator
        self.tokenIndex = 0
        self.separatorCount = 0
        self.cursor = 0
        self.startIndex = _buffer.startIndex
        self.closed = false
        self._completion = completion
        super.init(token: Token.Text(""), priority: priority, timeout_sec: timeout_sec, completion: nil)
        self.completion = { entry, reason in
            switch(reason) {
            case .Canceled:
                break
            case .Completed:
                self.tokenIndex += 1
                break
            case .Paused:
                break
            }
            guard let _completion = self._completion else { return }
            _completion(entry, reason)
        }
    }

    func append(text: String) throws {
        guard self.closed == false else { throw TokenizerError.runtimeError("already completed") }
        _buffer.append(text)
        process()
    }

    func close() {
        _tokens.append(Token.Text(String(_buffer[startIndex...])))
        self.closed = true
    }

    private func process() {
        while cursor < _buffer.count {
            let index = _buffer.index(_buffer.startIndex, offsetBy: cursor)
            let char = String(_buffer[index])
            if char == separator {
                separatorCount += 1
            } else {
                if separatorCount >= 3 {
                    let endIndex = _buffer.index(_buffer.startIndex, offsetBy: cursor - separatorCount)
                    let substring = String(_buffer[startIndex..<endIndex])
                    _tokens.append(Token.Text(substring))
                    _tokens.append(Token.Pause(separatorCount))
                    startIndex = _buffer.index(endIndex, offsetBy: separatorCount)
                }
                separatorCount = 0
            }
            cursor += 1
        }
    }

    override func finish(with range: NSRange?) {
        if let token = self.token {
            switch token.type {
            case .Text:
                if let range = range,
                   let result = self._token?.udpate(with: range), result == false {
                    tokenIndex += 1
                }
                break
            case .Pause:
                tokenIndex += 1
            }
        }
        if _tokens.count <= tokenIndex {
            completed = true
        }
    }
}
