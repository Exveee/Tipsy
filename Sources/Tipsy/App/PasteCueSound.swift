import AVFoundation
import AppKit

/// Plays a short, distinctive cue right before Tipsy starts typing, so the user
/// knows the paste is imminent.
///
/// The cue is synthesized at runtime (a rising three-note motif) rather than
/// loaded from an audio file, so it needs no bundled resources and stays unique
/// to Tipsy instead of reusing a stock system sound.
@MainActor
final class PasteCueSound {

    static let shared = PasteCueSound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let buffer: AVAudioPCMBuffer?
    private var engineStarted = false

    private init() {
        let sampleRate = 44_100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        buffer = format.flatMap { Self.makeCueBuffer(format: $0, sampleRate: sampleRate) }
        if let format {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    /// Plays the cue. Falls back to the system beep if audio can't start.
    func play() {
        guard let buffer else { NSSound.beep(); return }
        do {
            if !engineStarted {
                try engine.start()
                engineStarted = true
            }
            if !player.isPlaying { player.play() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        } catch {
            NSSound.beep()
        }
    }

    // MARK: - Synthesis

    /// Builds the cue: three rising notes (G5 → D6 → G6, a fifth then a fourth),
    /// each with a soft attack and exponential decay, the last one ringing.
    private static func makeCueBuffer(format: AVAudioFormat,
                                      sampleRate: Double) -> AVAudioPCMBuffer? {
        // (frequency Hz, start s, duration s, decay rate)
        let notes: [(freq: Double, start: Double, dur: Double, decay: Double)] = [
            (783.99, 0.00, 0.12, 22),   // G5
            (1174.66, 0.10, 0.12, 22),  // D6
            (1567.98, 0.20, 0.22, 9)    // G6 (rings out)
        ]
        let total = 0.44
        let frameCount = AVAudioFrameCount(sampleRate * total)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for note in notes {
                let local = t - note.start
                guard local >= 0, local <= note.dur else { continue }
                // Linear 5 ms attack, exponential decay.
                let attack = min(1.0, local / 0.005)
                let envelope = attack * exp(-local * note.decay)
                let phase = twoPi * note.freq * local
                // Fundamental plus a quieter second harmonic for a brighter timbre.
                sample += envelope * (sin(phase) + 0.3 * sin(2 * phase))
            }
            channel[frame] = Float(sample * 0.22)
        }
        return buffer
    }
}
