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
    public var delegate: PriorityQueueTTSDelegate?
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
            completion(item, nil, .Canceled)
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
        if let token = entry.token {
            switch token.type {
            case .Text:
                NSLog("speak text:\(token), priority:\(entry.priority)")
                if let utterance = token.utterance {
                    tts.speak(utterance)
                }
                break
            case .Pause:
                NSLog("\(token), priority:\(entry.priority)")
                if let duration = token.duration {
                    dipatchQueue.asyncAfter(deadline: .now() + duration) {
                        self.finish(utterance: nil)
                    }
                }
                break
            }
        } else {
            processingEntry = nil
            queue.insert(entry)
        }
    }

    private func start(utterance: AVSpeechUtterance) {
        guard let delegate = delegate else { return }
        guard let entry = processingEntry else { return }
        NSLog("start")
        delegate.progress(queue: self, entry: entry)
    }

    private func progress(range: NSRange, utterance: AVSpeechUtterance) {
        guard let delegate = delegate else { return }
        guard let entry = processingEntry else { return }
        NSLog("progress")
        delegate.progress(queue: self, entry: entry)
    }

    private func finish(utterance: AVSpeechUtterance?) {
        if let entry = processingEntry {
            entry.finish(with: speakingRange)
            if !entry.is_completed() {
                queue.insert(entry)
            }
            if let completion = entry.completion {
                if entry.is_completed() {
                    completion(entry, utterance, .Completed)
                } else {
                    completion(entry, utterance, .Paused)
                }
            }
        }
        processingEntry = nil
        speakingRange = nil
    }
}

extension PriorityQueueTTS: AVSpeechSynthesizerDelegate {
    // iOS 16.0 or newer
    // func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
    // }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        NSLog("didStart \(utterance.speechString)")
        start(utterance: utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NSLog("didFinish \(utterance.speechString)")
        finish(utterance: utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        NSLog("didCancel \(utterance.speechString)")
        finish(utterance: utterance)
    }

    // func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
    //    NSLog("didPause \(utterance.speechString)")
    //    finish()
    // }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        NSLog("willSpeakRangeOfSpeechString \(utterance.speechString) \(characterRange)")
        speakingRange = characterRange
        progress(range: characterRange, utterance: utterance)
    }
}
