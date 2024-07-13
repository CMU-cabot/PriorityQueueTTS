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

class Token {
    enum TokenType {
        case Text
        case Pause
    }
    var type: TokenType
    var text: String?
    var pause: Int?
    var readingRange: NSRange?
    var spokenText: String? {
        get {
            if let text = text {
                if finished {
                    return text
                }
                if let processedText = processedText,
                   let text = remainingText,
                   let range = readingRange,
                   let text = text.substring(before: range) {
                    return processedText + text
                }
                return ""
            }
            return nil
        }
    }
    var speakingText: String? {
        get {
            if let text = remainingText {
                if finished {
                    return ""
                }
                if let range = readingRange {
                    return text.substring(with: range)
                }
                return ""
            }
            return nil
        }
    }
    var willSpeakText: String? {
        get {
            if let text = remainingText {
                if finished {
                    return ""
                }
                if let range = readingRange {
                    return text.substring(after: range)
                }
                return text
            }
            return nil
        }
    }

    var processedRange: NSRange?
    var processedText: String? {
        get {
            if let text = text {
                if let range = processedRange {
                    return text.substring(with: range)
                } else {
                    return ""
                }
            }
            return nil
        }
    }
    var remainingText: String? {
        get {
            if let text = text {
                if let range = processedRange {
                    return text.substring(after: range)
                } else {
                    return text
                }
            }
            return nil
        }
    }
    var finished: Bool = false

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
    
    func udpate(with range: NSRange) -> Bool {
        guard let text = text else { return false }
        var temp: NSRange? = nil
        if self.processedRange == nil {
            temp = NSRange(location: 0, length: range.location+range.length)
        } else {
            temp = self.processedRange
            temp?.append(range: range)
        }
        if let range = temp,
           let newText = text.substring(after: range) {
            finished = newText.count == 0
            if !finished { self.processedRange = range }
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
                var add = ""
                withUnsafePointer(to: self) { pointer in
                    add = "\(pointer)"
                }
                return "Text Token\(add): \(text) (\(remainingText)) (\(finished)"
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
