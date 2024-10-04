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

public typealias EntryFilter = (_ base: QueueEntry, _ test: QueueEntry) -> Bool
public let SameTag: EntryFilter = { base, test in base.tag == test.tag }


public class PriorityQueueTTS: NSObject {
    public static var shared = PriorityQueueTTS()

    public var delegate: PriorityQueueTTSDelegate?
    private var queue: PriorityQueue<QueueEntry> = PriorityQueue<QueueEntry>()
    private var tts: AVSpeechSynthesizer
    private var processingEntry: QueueEntry?
    private var speakingRange: NSRange?
    private let dipatchQueue: DispatchQueue = DispatchQueue.global(qos: .userInteractive)
    private var pausing :DispatchWorkItem? = nil
    
    override init() {
        tts = AVSpeechSynthesizer()
        super.init()
        tts.delegate = self
    }

    public func append(entry: QueueEntry, withRemoving:EntryFilter? = nil, cancelBoundary: AVSpeechBoundary = .immediate ) {
        if let withRemoving {
            cancel( where:{e in withRemoving(entry, e)}, at:cancelBoundary )
        }
        
        if let currentItem = processingEntry,
           currentItem.priority < entry.priority {
            tts.stopSpeaking(at: .immediate)
        }
        queue.insert(entry)
    }

    public func start() {
        dipatchQueue.async {
            let timer = Timer(timeInterval: 0.01, repeats: true) { timer in
                self.processQueue()
            }
            RunLoop.current.add(timer, forMode: .default)
            RunLoop.current.run()
        }
    }

    public func pause() {
        tts.stopSpeaking(at: .word)
    }

    public func cancel( at boundary: AVSpeechBoundary = .word ) {
        if let processingEntry {
            stopProcessingImmediately( current:processingEntry, at:boundary )
        }
        while !queue.isEmpty {
            guard let item = queue.extractMax() else { break }
            guard let completion = item.completion else { continue }
            completion(item, nil, .Canceled)
        }
    }
    
    public func cancel( where filter: (QueueEntry) -> Bool, at boundary: AVSpeechBoundary = .immediate ) {
        if let currentItem = processingEntry, filter(currentItem) {
            stopProcessingImmediately( current:currentItem, at:boundary )
        }
        queue.remove { entry in
            if filter(entry) {
                entry.completion?(entry, nil, .Canceled)
                return true
            }
            return false
        }
    }
    
    private func stopProcessingImmediately( current: QueueEntry, at boundary: AVSpeechBoundary = .immediate ) {
        current.mark_canceled()
        if tts.isSpeaking {
            tts.stopSpeaking(at: boundary)
        }
        if let pausing {
            pausing.cancel()
            self.finish(utterance: nil)
        }
    }

    private func processQueue() {
        guard processingEntry == nil else { return }
        guard !queue.isEmpty else { return }
        guard let entry = queue.extractMax() else { return }
        guard Date().timeIntervalSince1970 < entry.expire_at else {
            entry.completion?( entry, nil, .Canceled )
            return
        }
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
                    utterance.volume = entry.volume
                    utterance.rate = entry.speechRate;
                    utterance.voice = entry.voice;
                    tts.speak(utterance)
                }
                break
            case .Pause:
                NSLog("\(token), priority:\(entry.priority)")
                if let duration = token.duration {
                    let workItem = DispatchWorkItem() { [weak self] in self?.finish(utterance: nil) }
                    self.pausing = workItem
                    dipatchQueue.asyncAfter(deadline: .now() + duration, execute:workItem)
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
        delegate.progress(queue: self, entry: entry)
    }

    private func progress(range: NSRange, utterance: AVSpeechUtterance) {
        guard let entry = processingEntry else { return }
        entry.progress(with: range)
        delegate?.progress(queue: self, entry: entry)
    }

    private func finish(utterance: AVSpeechUtterance?) {
        if let entry = processingEntry {
            if entry.status == .canceled {
                entry.completion?(entry, nil, .Canceled)
            }
            else {
                if let utterance, speakingRange == nil {
                    speakingRange = NSRange(location:0, length:utterance.speechString.count)
                }
                
                entry.finish(with: speakingRange)
                if entry.is_completed() {
                    if let delegate = self.delegate {
                        delegate.completed(queue: self, entry: entry)
                    }
                } else {
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
        }
        processingEntry = nil
        speakingRange = nil
        pausing = nil
    }
}

extension PriorityQueueTTS: AVSpeechSynthesizerDelegate {
    // iOS 16.0 or newer
    // func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeak marker: AVSpeechSynthesisMarker, utterance: AVSpeechUtterance) {
    // }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // NSLog("didStart \(utterance.speechString)")
        start(utterance: utterance)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // NSLog("didFinish \(utterance.speechString)")
        finish(utterance: utterance)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // NSLog("didCancel \(utterance.speechString)")
        finish(utterance: utterance)
    }

    // func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
    //    NSLog("didPause \(utterance.speechString)")
    //    finish()
    // }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        NSLog("willSpeakRangeOfSpeechString \(utterance.speechString) \(characterRange)")
        speakingRange = characterRange
        progress(range: characterRange, utterance: utterance)
    }
}
