import AppKit

/// Reads plain text from the system pasteboard.
public enum ClipboardReader {
    /// Current clipboard string, or `nil` if it holds no text.
    public static func text() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
