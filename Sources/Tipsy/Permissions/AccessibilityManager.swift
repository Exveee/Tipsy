import ApplicationServices

/// Gatekeeper for the Accessibility permission that synthesized keyboard
/// events require. Without it, posted events are silently dropped.
enum AccessibilityManager {
    /// Whether this process is trusted to post input events.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Returns trust status; if `prompt` is true and untrusted, macOS shows
    /// the system dialog directing the user to System Settings.
    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        // Literal value of `kAXTrustedCheckOptionPrompt`; referencing the
        // imported global directly is rejected by Swift 6 concurrency checks.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
