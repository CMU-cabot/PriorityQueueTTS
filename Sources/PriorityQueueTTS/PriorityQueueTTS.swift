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
    private var queue: PriorityQueue<QueueEntry> = PriorityQueue<QueueEntry>()
    private var tts: AVSpeechSynthesizer
    private var processingEntry: QueueEntry?
    private var speakingRange: NSRange?
    private let dipatchQueue: DispatchQueue = DispatchQueue.global(qos: .utility)

    override init() {
        tts = AVSpeechSynthesizer()
        super.init()
        tts.delegate = self
    }
    
    func append(entry: QueueEntry) {
        if let currentItem = processingEntry,
           currentItem.priority < entry.priority {
            tts.stopSpeaking(at: .immediate)
        }
        queue.insert(entry)
    }

    func start() {
        dipatchQueue.async {
            let timer = Timer(timeInterval: 0.01, repeats: true) { timer in
                self.processQueue()
            }
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }

    func pause() {
        tts.stopSpeaking(at: .word)
    }

    func cancel() {
        tts.stopSpeaking(at: .word)
        while !queue.isEmpty {
            guard let item = queue.extractMax() else { break }
            guard let completion = item.completion else { continue }
            completion(item, .Canceled)
        }
    }

    private func processQueue() {
        guard processingEntry == nil else { return }
        guard !queue.isEmpty else { return }
        guard let entry = queue.extractMax() else { return }
        guard Date().timeIntervalSince1970 < entry.expire_at else { return }
        processingEntry = entry
        process(entry: entry)
    }

    private func process(entry: QueueEntry) {
        processingEntry = entry
        if let speech = entry as? SpeechItem {
            NSLog("speak text:\(speech.text), priority:\(entry.priority)")
            tts.speak(speech.utterance)
        }
        if let pause = entry as? PauseItem {
            NSLog("\(pause.text), priority:\(entry.priority)")
            dipatchQueue.asyncAfter(deadline: .now() + pause.duration) {
                if let entry = self.processingEntry,
                   let completion = entry.completion {
                    completion(entry, .Completed)
                    self.processingEntry = nil
                }
            }
        }
    }

    private func updateItem() {
        guard let entry = processingEntry else { return }
        guard let range = speakingRange else { return }
        if let speech = entry as? SpeechItem {
            speech.update(with: range)
        }
        queue.insert(entry)
    }
}

extension PriorityQueueTTS: AVSpeechSynthesizerDelegate {
    @available(iOS 16.0, *)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let entry = processingEntry,
           let range = speakingRange,
           let completion = entry.completion {
            // bug from iOS 15, didFinish is called instead of didCancel
            if let speechItem = entry as? SpeechItem,
               speechItem.utterance == utterance,
               range.location + range.length < entry.text.count {
                completion(entry, .Paused)
                updateItem()
            } else {
                completion(entry, .Completed)
            }
        }
        processingEntry = nil
        speakingRange = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        updateItem()
        if let item = processingEntry,
           let completion = item.completion {
            completion(item, .Paused)
        }
        processingEntry = nil
        speakingRange = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        speakingRange = characterRange
    }
}
