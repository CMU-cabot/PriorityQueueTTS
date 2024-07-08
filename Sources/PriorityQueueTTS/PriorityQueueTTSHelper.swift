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

class PriorityQueueTTSHelper {
    static func enumerateQueueItem(
        text: String,
        separator: String,
        handle: (_ text: String?, _ pause: Double?) -> Void
    ) {
        var keep = 0
        var i = 0
        var start = text.startIndex
        var text = text

        while i < text.count {
            let index = text.index(text.startIndex, offsetBy: i)
            let char = String(text[index])
            if char == separator {
                keep += 1
            } else {
                if keep >= 3 {
                    let endIndex = text.index(text.startIndex, offsetBy: i - keep)
                    let substring = String(text[start..<endIndex])
                    handle(substring, nil)
                    handle(nil, 0.1 * Double(keep))
                    text = String(text[text.index(text.startIndex, offsetBy: i)...])
                    i = 0
                    start = text.startIndex
                }
                keep = 0
            }
            i += 1
        }
        handle(text, nil)
    }
}
