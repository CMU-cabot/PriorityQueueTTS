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

extension String {
    func substring(before range: NSRange) -> String? {
        guard let rangeStart = Range(range, in: self) else { return nil }
        let endIndex = rangeStart.lowerBound
        return String(self[..<endIndex])
    }
    func substring(with range: NSRange) -> String? {
        guard let rangeStart = Range(range, in: self) else { return nil }
        let startIndex = rangeStart.lowerBound
        let endIndex = rangeStart.upperBound
        return String(self[startIndex..<endIndex])
    }
    func substring(after range: NSRange) -> String? {
        guard let rangeStart = Range(range, in: self) else { return nil }
        let startIndex = rangeStart.upperBound
        return String(self[startIndex...])
    }
}

extension NSRange {
    mutating func append(range: NSRange) {
        self.location = self.location + self.length + range.location
        self.length = range.length
    }
    
    var nextLocation : Int {
        return self.location + self.length
    }
    
    func shift( _ shift: Int ) -> NSRange {
        return NSRange(location: self.location + shift, length: self.length)
    }
}
