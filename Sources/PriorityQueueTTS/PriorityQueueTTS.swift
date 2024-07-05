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

class PriorityQueueTTS: NSObject {
    private var queue: PriorityQueue<SpeechItem> = PriorityQueue<SpeechItem>()
    private var tts: AVSpeechSynthesizer
    private var speakingItem: SpeechItem?
    private var speakingRange: NSRange?

    override init() {
        tts = AVSpeechSynthesizer()
        super.init()
        tts.delegate = self
    }

    func append(text: String, priority: SpeechPriority = .Normal, timeout_sec: Double = 1.0,
                completion: ((_ item: SpeechItem, _ canceled: Bool) -> Void)?) {
        let now = Date().timeIntervalSince1970
        let expire = now + timeout_sec
        let item = SpeechItem(text: text, priority: priority,
                              created_time: now, expire_at: expire, completion: completion)
        queue.insert(item)
    }

    func start() {
        DispatchQueue.global(qos: .utility) .async {
            let timer = Timer(timeInterval: 0.1, repeats: true) { timer in
                self.processQueue()
            }
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }

    private func processQueue() {
        guard speakingItem == nil else { return }
        guard !queue.isEmpty else { return }
        guard let item = queue.extractMax() else { return }
        guard Date().timeIntervalSince1970 < item.expire_at else { return }
        speakingItem = item
        speak(item: item)
    }

    private func speak(item: SpeechItem) {
        NSLog("speak text:\(item.text), priority:\(item.priority)")
        speakingItem = item
        tts.speak(item.utterance)
    }

    private func updateItem() {
        guard let item = speakingItem else { return }
        guard let range = speakingRange else { return }
        item.update(with: range)
    }
}

extension PriorityQueueTTS: AVSpeechSynthesizerDelegate {
    @available(iOS 16.0, *)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let item = speakingItem,
           let completion = item.completion {
            completion(item, false)
        }
        speakingItem = nil
        speakingRange = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        updateItem()
        if let item = speakingItem,
           let completion = item.completion {
            completion(item, false)
        }
        speakingItem = nil
        speakingRange = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        speakingRange = characterRange
    }
}
