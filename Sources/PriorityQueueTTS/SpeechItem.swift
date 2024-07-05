//
//  SpeechItem
//
//
//  Created by Daisuke Sato on 7/4/24.
//

import Foundation
import AVFoundation


// class SpeechItem
// higher priority first
// earier created first
class SpeechItem {
    var text: String
    let priority: Int8
    let created_time: TimeInterval
    let expire_at: TimeInterval
    let completion: ((_ item: SpeechItem, _ canceled: Bool) -> Void)?
    var _utterance: AVSpeechUtterance? = nil

    init(text: String, priority: Int8, created_time: TimeInterval, expire_at: TimeInterval, 
         completion: ((_ item: SpeechItem, _ canceled: Bool) -> Void)? = nil) {
        self.text = text
        self.priority = priority
        self.created_time = created_time
        self.expire_at = expire_at
        self.completion = completion
    }
}

extension SpeechItem {
    var utterance: AVSpeechUtterance {
        get {
            AVSpeechUtterance(string: self.text)
        }
    }
    
    func update(with range: NSRange) {
        if let newText = self.text.substring(from: range) {
            text = newText
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

extension SpeechItem: Comparable {
    static func < (lhs: SpeechItem, rhs: SpeechItem) -> Bool {
        if lhs.priority == rhs.priority {
            return lhs.created_time > rhs.created_time
        }
        return lhs.priority < rhs.priority
    }
    static func == (lhs: SpeechItem, rhs: SpeechItem) -> Bool {
        return lhs.priority == rhs.priority && lhs.created_time == rhs.created_time
    }
}

