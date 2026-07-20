import CoreGraphics
import Foundation
import os

/// Immutable, `Sendable` snapshot of the typing tuning parameters.
///
/// The engine no longer carries mutable tuning state, so the caller builds a
/// `TypingConfig` from its current settings at trigger time and hands it to
/// ``KeystrokeEngine/type(_:using:config:)``. Because the value is captured by
/// value, a background typing run can never observe a half-written update from
/// the main actor.
public struct TypingConfig: Sendable {

    /// Pause between characters. Some KVM/console targets drop events that
    /// arrive too fast; a small delay keeps input reliable.
    public var characterDelay: TimeInterval

    /// Maximum random variation, in seconds, added to each inter-character
    /// pause to make typing look less mechanical.
    ///
    /// When greater than zero, the effective delay per character is
    /// `max(0, characterDelay + Double.random(in: -jitter...jitter))`.
    /// Values `<= 0` disable jitter and use ``characterDelay`` verbatim.
    public var jitter: TimeInterval

    /// When `true`, characters with no ``KeyboardLayout`` mapping are typed
    /// directly via their Unicode scalar values instead of being skipped.
    /// When `false`, unmapped characters are reported back to the caller.
    public var unicodeFallback: Bool

    /// Pause between the individual events *inside* one stroke sequence
    /// (modifier down → key down → key up → modifier up, and between dead-key
    /// steps). `0` posts back-to-back as before. Remote web consoles batch
    /// events and can miss a modifier that arrives in the same batch as the
    /// key; ``TargetProfile/remoteConsole`` defaults this to a few ms.
    public var interEventDelay: TimeInterval

    public init(characterDelay: TimeInterval = 0.012,
                jitter: TimeInterval = 0,
                unicodeFallback: Bool = true,
                interEventDelay: TimeInterval = 0) {
        self.characterDelay = characterDelay
        self.jitter = jitter
        self.unicodeFallback = unicodeFallback
        self.interEventDelay = interEventDelay
    }

    /// Builds a config constrained by the target `profile`.
    ///
    /// The profile overrides the stored user settings where typing would
    /// otherwise be unsafe: ``TargetProfile/remoteConsole`` forces
    /// ``unicodeFallback`` off (remote clients see only the virtual key code, so
    /// a fallback character would arrive as a stray `a`), and pacing defaults to
    /// ``TargetProfile/defaultInterEventDelay`` unless the caller passes an
    /// explicit `interEventDelay`.
    public init(profile: TargetProfile,
                characterDelay: TimeInterval = 0.012,
                jitter: TimeInterval = 0,
                unicodeFallback: Bool = true,
                interEventDelay: TimeInterval? = nil) {
        self.characterDelay = characterDelay
        self.jitter = jitter
        self.unicodeFallback = profile.allowsUnicodeFallback && unicodeFallback
        self.interEventDelay = interEventDelay ?? profile.defaultInterEventDelay
    }
}

/// Turns text into synthesized keyboard events for the focused application.
///
/// Each character is resolved through the active ``KeyboardLayout`` and posted
/// as a key-down / key-up pair via Quartz event services, so the target sees
/// genuine hardware-like keystrokes (works where clipboard paste is blocked).
///
/// Characters with no layout mapping are either typed directly as Unicode
/// (see ``TypingConfig/unicodeFallback``) or reported back to the caller via
/// the `type(_:using:config:)` return value.
///
/// The engine holds no shared mutable tuning state: all timing/fallback inputs
/// arrive per-call via an immutable ``TypingConfig``, so it is genuinely
/// `Sendable` and safe to invoke from a background serial queue while the main
/// actor owns it. The only cross-thread state is the cancel flag, guarded by a
/// lock.
public final class KeystrokeEngine: Sendable {

    /// Thread-safe cancellation flag, checked once per character. Set from the
    /// main actor (e.g. a "Stop Typing" action) while the run executes on a
    /// background serial queue.
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    /// Blocking sleep primitive, called for every intra-stroke and
    /// inter-character pause. Injected so tests can record pauses instead of
    /// actually sleeping; captured as an immutable `@Sendable` `let` so the
    /// engine stays `Sendable` and safe to run from a background queue.
    private let sleeper: @Sendable (TimeInterval) -> Void

    public init(sleeper: @escaping @Sendable (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }) {
        self.sleeper = sleeper
    }

    /// Requests that an in-flight run stop at the next character boundary.
    /// Safe to call from any thread.
    public func cancel() {
        cancelled.withLock { $0 = true }
    }

    /// Clears the cancel flag so a fresh run can proceed. Call once on the main
    /// actor before scheduling each run.
    public func resetCancellation() {
        cancelled.withLock { $0 = false }
    }

    private var isCancelled: Bool {
        cancelled.withLock { $0 }
    }

    /// One synthesized keyboard event: which virtual key, whether it is a press
    /// or a release, and the modifier flags the event should carry. Both the
    /// engine and the tests build event sequences out of these so the posting
    /// order can be verified without Quartz.
    public struct KeyEvent: Equatable {
        public let keyCode: CGKeyCode
        public let keyDown: Bool
        public let flags: CGEventFlags

        public init(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
            self.keyCode = keyCode
            self.keyDown = keyDown
            self.flags = flags
        }
    }

    /// Pure plan of the real modifier key events a stroke needs, in posting
    /// order: presses (Shift → Option → right Option) followed by releases in
    /// reverse.
    ///
    /// Local apps honor the per-event `CGEventFlags`, but remote consoles
    /// (VNC/KVM/web terminals like Teleport) track the *physical* modifier key
    /// state and ignore event flags — without an actual Shift/Option press they
    /// receive the unshifted key, so e.g. `"` (Shift+2) arrives as `2`. Right
    /// Option (`VK.rightOption`, 61) is a separate physical key from left Option
    /// (`VK.option`, 58): PC hosts behind a KVM only emit AltGr symbols with the
    /// right one, so a `rightOption` stroke must never fall back to key 58.
    ///
    /// Press events carry the stroke's full flags; each release reports the
    /// modifiers still held after it, so the key-up events show the correct
    /// remaining state.
    public static func modifierPlan(for stroke: KeyStroke) -> [KeyEvent] {
        var mods: [(keyCode: CGKeyCode, mask: CGEventFlags)] = []
        if stroke.shift { mods.append((VK.shift, .maskShift)) }
        if stroke.option { mods.append((VK.option, .maskAlternate)) }
        if stroke.rightOption { mods.append((VK.rightOption, .maskAlternate)) }

        var plan: [KeyEvent] = []
        // Press in order, every press carrying the full modifier flags.
        for mod in mods {
            plan.append(KeyEvent(keyCode: mod.keyCode, keyDown: true, flags: stroke.flags))
        }
        // Release in reverse, each event reporting the modifiers pressed before
        // it that are still held (so shared masks stay set until their last
        // holder releases).
        for k in mods.indices.reversed() {
            var remaining = CGEventFlags()
            for j in 0..<k { remaining.formUnion(mods[j].mask) }
            plan.append(KeyEvent(keyCode: mods[k].keyCode, keyDown: false, flags: remaining))
        }
        return plan
    }

    /// One step of a character's execution plan: a synthesized event or a pause.
    public enum PostStep: Equatable {
        case event(KeyEvent)
        case pause(TimeInterval)
    }

    /// Pure, ordered plan for a whole character's stroke sequence: every key
    /// event (modifier presses, key down, key up, modifier releases, and each
    /// dead-key step) with an `interEventDelay` pause interleaved *between*
    /// consecutive events.
    ///
    /// With `interEventDelay == 0` no `.pause` steps are emitted at all, so the
    /// event stream — and its timing — is byte-identical to posting back-to-back.
    /// The engine executes this list; tests assert on it directly.
    public static func postPlan(for strokes: [KeyStroke], interEventDelay: TimeInterval) -> [PostStep] {
        // Flatten every stroke into its ordered key events.
        var events: [KeyEvent] = []
        for stroke in strokes {
            let plan = modifierPlan(for: stroke)
            for event in plan where event.keyDown { events.append(event) }
            events.append(KeyEvent(keyCode: stroke.keyCode, keyDown: true, flags: stroke.flags))
            events.append(KeyEvent(keyCode: stroke.keyCode, keyDown: false, flags: stroke.flags))
            for event in plan where !event.keyDown { events.append(event) }
        }
        // Interleave a pause before every event except the first.
        var steps: [PostStep] = []
        for (index, event) in events.enumerated() {
            if index > 0, interEventDelay > 0 { steps.append(.pause(interEventDelay)) }
            steps.append(.event(event))
        }
        return steps
    }

    /// Types `text` using `layout` with the timing/fallback rules in `config`.
    /// Returns a ``SkippedReport`` aggregating the characters that could not be
    /// typed, so the caller can warn the user. Stops early (returning what was
    /// skipped so far) if ``cancel()`` is called mid-run.
    ///
    /// A character is skipped only when it has no layout mapping *and* either
    /// ``TypingConfig/unicodeFallback`` is `false` or the character could not be
    /// encoded as Unicode.
    @discardableResult
    public func type(_ text: String, using layout: KeyboardLayout, config: TypingConfig) -> SkippedReport {
        var skipped = SkippedReport()
        // `.privateState` so posted events do not inherit live hardware
        // modifiers (e.g. ⌘/⇧ still held from the hotkey), which would turn
        // typed characters into destructive chords.
        let source = CGEventSource(stateID: .privateState)

        for (index, character) in text.enumerated() {
            if isCancelled { break }

            if let strokes = layout.strokes(for: character) {
                post(strokes, source: source, config: config)
            } else if config.unicodeFallback {
                if !postUnicode(character, source: source) {
                    skipped.record(character, at: index)
                    continue
                }
            } else {
                skipped.record(character, at: index)
                continue
            }
            sleepAfterCharacter(config: config)
        }
        return skipped
    }

    /// Sleeps for the effective inter-character delay, applying jitter when set.
    private func sleepAfterCharacter(config: TypingConfig) {
        var delay = config.characterDelay
        if config.jitter > 0 {
            delay = max(0, config.characterDelay + Double.random(in: -config.jitter...config.jitter))
        }
        if delay > 0 {
            sleeper(delay)
        }
    }

    /// Posts every event for `strokes`, pausing `config.interEventDelay` between
    /// consecutive events (see ``postPlan(for:interEventDelay:)``).
    private func post(_ strokes: [KeyStroke], source: CGEventSource?, config: TypingConfig) {
        for step in Self.postPlan(for: strokes, interEventDelay: config.interEventDelay) {
            switch step {
            case .event(let event): postEvent(event, source: source)
            case .pause(let delay): sleeper(delay)
            }
        }
    }

    /// Posts a single key-down or key-up event with the given flags.
    private func postEvent(_ event: KeyEvent, source: CGEventSource?) {
        let cg = CGEvent(keyboardEventSource: source, virtualKey: event.keyCode, keyDown: event.keyDown)
        cg?.flags = event.flags
        cg?.post(tap: .cghidEventTap)
    }

    /// Posts `character` directly via its UTF-16 code units using a virtual-key-0
    /// key-down / key-up pair. Returns `false` if the events could not be created.
    private func postUnicode(_ character: Character, source: CGEventSource?) -> Bool {
        let utf16 = Array(String(character).utf16)
        guard !utf16.isEmpty,
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return false
        }
        // Explicitly clear modifiers for the synthetic Unicode strokes.
        down.flags = []
        up.flags = []
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
