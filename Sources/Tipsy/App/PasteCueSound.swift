import AVFoundation
import AppKit

/// A selectable cue motif. Each case is synthesized at runtime, so no audio
/// files are bundled and the cues stay unique to Tipsy.
enum CueVariant: String, CaseIterable {
    case rising
    case blip
    case chime

    var displayName: String {
        switch self {
        case .rising: return "Rising"
        case .blip: return "Blip"
        case .chime: return "Chime"
        }
    }

    /// (frequency Hz, start s, duration s, decay rate) notes + total length.
    fileprivate var notes: [(freq: Double, start: Double, dur: Double, decay: Double)] {
        switch self {
        case .rising:
            return [(783.99, 0.00, 0.12, 22), (1174.66, 0.10, 0.12, 22),
                    (1567.98, 0.20, 0.22, 9)]
        case .blip:
            return [(1046.50, 0.00, 0.07, 30), (1567.98, 0.05, 0.12, 18)]
        case .chime:
            return [(1318.51, 0.00, 0.16, 10), (880.00, 0.06, 0.30, 6)]
        }
    }

    fileprivate var total: Double {
        switch self {
        case .rising: return 0.44
        case .blip: return 0.20
        case .chime: return 0.40
        }
    }
}

/// Plays a short, distinctive cue right before Tipsy starts typing, so the user
/// knows the paste is imminent. Variant and volume come from ``Settings``.
@MainActor
final class PasteCueSound {

    static let shared = PasteCueSound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private let format: AVAudioFormat?
    private var engineStarted = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        if let format {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    /// Plays the configured cue at the configured volume. Falls back to the
    /// system beep if audio can't start.
    func play() {
        let variant = CueVariant(rawValue: Settings.cueVariant) ?? .rising
        play(variant: variant, volume: Settings.cueVolume)
    }

    /// Plays a specific `variant` at `volume` (0–1) — used for live previews.
    func play(variant: CueVariant, volume: Double) {
        guard let format,
              let buffer = Self.makeBuffer(variant: variant, volume: volume,
                                           format: format, sampleRate: sampleRate) else {
            NSSound.beep(); return
        }
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

    private static func makeBuffer(variant: CueVariant, volume: Double,
                                   format: AVAudioFormat, sampleRate: Double) -> AVAudioPCMBuffer? {
        let notes = variant.notes
        let frameCount = AVAudioFrameCount(sampleRate * variant.total)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        let gain = max(0, min(1, volume)) * 0.32
        let twoPi = 2.0 * Double.pi
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for note in notes {
                let local = t - note.start
                guard local >= 0, local <= note.dur else { continue }
                let attack = min(1.0, local / 0.005)         // 5 ms attack
                let envelope = attack * exp(-local * note.decay)
                let phase = twoPi * note.freq * local
                sample += envelope * (sin(phase) + 0.3 * sin(2 * phase))
            }
            channel[frame] = Float(sample * gain)
        }
        return buffer
    }
}
