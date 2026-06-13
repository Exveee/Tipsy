import AppKit

/// Reads plain text from the system pasteboard.
enum ClipboardReader {
    /// Current clipboard string, or `nil` if it holds no text.
    static func text() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
