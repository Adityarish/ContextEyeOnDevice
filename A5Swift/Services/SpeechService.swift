import AVFoundation
import Foundation

final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    private let cooldown: TimeInterval
    private var lastSpokenTimestamps: [String: Date] = [:]

    init(cooldown: TimeInterval = 2.0) {
        self.cooldown = cooldown
    }

    func speak(_ detections: [Detection]) {
        guard let strongestDetection = detections.first,
              strongestDetection.confidence >= 0.70 else {
            return
        }

        let key = strongestDetection.label.lowercased()
        let now = Date()

        if let lastSpoken = lastSpokenTimestamps[key],
           now.timeIntervalSince(lastSpoken) < cooldown {
            return
        }

        lastSpokenTimestamps[key] = now

        let utterance = AVSpeechUtterance(string: strongestDetection.label)
        utterance.rate = 0.48
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)

        if !synthesizer.isSpeaking {
            synthesizer.speak(utterance)
        }
    }
}
