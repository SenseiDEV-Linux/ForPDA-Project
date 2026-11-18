import Foundation

/// Text and its UIKit selection must always refer to the same draft.
public struct BBCodeDraft: Equatable, Sendable {
    public var text: String
    public var selection: NSRange?

    public init(text: String = "", selection: NSRange? = nil) {
        self.text = text
        self.selection = selection
    }

    /// With no selection this leaves the caret between the opening and closing tags.
    public mutating func wrapSelection(in tags: (String, String)) {
        let range = selectionRange
        let utf16Range = NSRange(range, in: text)
        let replacement = tags.0 + String(text[range]) + tags.1
        text.replaceSubrange(range, with: replacement)
        selection = NSRange(location: utf16Range.location + tags.0.utf16.count, length: utf16Range.length)
    }

    /// Insert a quoted message before the selection, without erasing any draft text.
    public mutating func insertQuote(_ message: String) {
        guard !message.isEmpty else { return }
        let index = selectionRange.lowerBound
        let location = index.utf16Offset(in: text)
        let newline = text[..<index].last.map { $0.isNewline ? "" : "\n" } ?? ""
        let quote = "\(newline)[QUOTE]\(message)[/QUOTE]\n"
        text.insert(contentsOf: quote, at: index)
        selection = NSRange(location: location + quote.utf16.count, length: 0)
    }

    private var selectionRange: Range<String.Index> {
        let count = text.utf16.count
        guard let selection,
              (0...count).contains(selection.location),
              (0...(count - selection.location)).contains(selection.length),
              let range = Range(selection, in: text)
        else { return text.endIndex..<text.endIndex }
        return range
    }
}
