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

struct Token {
    enum TokenType {
        case Text
        case Pause
    }
    var type: TokenType
    var text: String?
    var pause: Int?
    var readingRange: NSRange?
    var readText: String? {
        get {
            if let text = text {
                if let range = readingRange {
                    return text.substring(before: range)
                }
            }
            return nil
        }
    }
    var speakingText: String? {
        get {
            if let text = text {
                if let range = readingRange {
                    return text.substring(with: range)
                }
            }
            return nil
        }
    }
    var willSpeakText: String? {
        get {
            if let text = text {
                if let range = readingRange {
                    return text.substring(after: range)
                }
            }
            return nil
        }
    }

    var range: NSRange?
    var remainingText: String? {
        get {
            if let text = text {
                if let range = range {
                    return text.substring(after: range)
                } else {
                    return text
                }
            }
            return nil
        }
    }

    var utterance: AVSpeechUtterance? {
        get {
            if let text = self.remainingText {
                let utterance = AVSpeechUtterance(string: text)
                return utterance
            }
            return nil
        }
    }

    var duration: Double? {
        get {
            if let pause = pause {
                return 0.1 * Double(pause)
            }
            return nil
        }
    }

    private init(type: TokenType, text: String? = nil, pause: Int? = nil) {
        self.type = type
        self.text = text
        self.pause = pause
    }
    
    static func Text(_ text: String) -> Token {
        return Token(type: .Text, text: text, pause: nil)
    }
    
    static func Pause(_ pause: Int) -> Token  {
        return Token(type: .Pause, text: nil, pause: pause)
    }
    
    mutating func udpate(with range: NSRange) -> Bool {
        guard let text = text else { return false }
        if self.range == nil {
            self.range = range
        } else {
            self.range?.append(range: range)
        }
        if let range = self.range,
           let newText = text.substring(after: range) {
            return newText.count > 0
        }
        return false
    }
}

extension Token: CustomStringConvertible {
    var description: String {
        switch type {
        case .Text: 
            if let text = text,
               let remainingText = remainingText {
                return "Text Token: \(text) (\(remainingText))"
            }
            break
        case .Pause:
            if let pause = pause {
                return "Pause Token: \(pause)"
            }
            break
        }
        return "Unknown Token"
    }
}
