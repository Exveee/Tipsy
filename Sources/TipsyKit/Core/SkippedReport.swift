/// Aggregated summary of the characters a typing run could not produce.
///
/// A character is skipped when it has no layout mapping *and* the Unicode
/// fallback is off (or the character could not be encoded). Rather than a flat
/// list with duplicates, the report keeps one ``Entry`` per unique character —
/// with an occurrence count and the index it was first seen at — so the caller
/// can warn the user compactly (e.g. "couldn't type: € ✓ 本").
public struct SkippedReport: Sendable, Equatable {

    /// One skipped character, how often it occurred, and where it first appeared.
    public struct Entry: Sendable, Equatable {
        /// The character that could not be typed.
        public let character: Character
        /// How many times it was skipped across the run.
        public let count: Int
        /// Zero-based index (in the source text) of its first occurrence.
        public let firstIndex: Int

        public init(character: Character, count: Int, firstIndex: Int) {
            self.character = character
            self.count = count
            self.firstIndex = firstIndex
        }
    }

    /// Unique skipped characters in first-seen order.
    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// `true` when nothing was skipped.
    public var isEmpty: Bool { entries.isEmpty }

    /// Total number of skipped occurrences across every character.
    public var totalCount: Int { entries.reduce(0) { $0 + $1.count } }

    /// The unique skipped characters, in first-seen order.
    public var uniqueCharacters: [Character] { entries.map(\.character) }

    /// Records one skipped `character` seen at `index`, incrementing its count
    /// if already present or appending a new first-seen entry otherwise.
    public mutating func record(_ character: Character, at index: Int) {
        if let i = entries.firstIndex(where: { $0.character == character }) {
            let existing = entries[i]
            entries[i] = Entry(character: character,
                               count: existing.count + 1,
                               firstIndex: existing.firstIndex)
        } else {
            entries.append(Entry(character: character, count: 1, firstIndex: index))
        }
    }
}
