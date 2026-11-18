import BBPanelFeature
import Foundation
import Testing

struct BBCodeDraftTests {
    @Test func emptyDraftGetsAnEditablePair() {
        var draft = BBCodeDraft()
        draft.wrapSelection(in: ("[B]", "[/B]"))
        #expect(draft == BBCodeDraft(text: "[B][/B]", selection: NSRange(location: 3, length: 0)))
    }

    @Test func caretInMiddleOfDraft() {
        var draft = BBCodeDraft(text: "до после", selection: NSRange(location: 2, length: 0))
        draft.wrapSelection(in: ("[SIZE=5]", "[/SIZE]"))
        #expect(draft == BBCodeDraft(text: "до[SIZE=5][/SIZE] после", selection: NSRange(location: 10, length: 0)))
    }

    @Test func keepsUnicodeSelectionForNestedFormatting() {
        let prefix = "🙂 "
        let selected = "Семья 👨‍👩‍👧‍👦 и е\u{301}"
        var draft = BBCodeDraft(
            text: prefix + selected + "!",
            selection: NSRange(location: prefix.utf16.count, length: selected.utf16.count)
        )
        draft.wrapSelection(in: ("[B]", "[/B]"))
        let opening = "[URL=https://пример.рф/📎]"
        draft.wrapSelection(in: (opening, "[/URL]"))
        #expect(draft.text == prefix + "[B]" + opening + selected + "[/URL][/B]!")
        #expect(draft.selection == NSRange(location: (prefix + "[B]" + opening).utf16.count, length: selected.utf16.count))
    }

    @Test func invalidOrMissingSelectionAppendsWithoutLosingText() {
        let text = "🚀 текст"
        let ranges: [NSRange?] = [
            nil, NSRange(location: NSNotFound, length: 0), NSRange(location: 100, length: 0),
            NSRange(location: 1, length: 0), // Middle of a surrogate pair.
            NSRange(location: 0, length: Int.max)
        ]
        for range in ranges {
            var draft = BBCodeDraft(text: text, selection: range)
            draft.wrapSelection(in: ("[QUOTE]", "[/QUOTE]"))
            #expect(draft.text == text + "[QUOTE][/QUOTE]")
            #expect(draft.selection == NSRange(location: (text + "[QUOTE]").utf16.count, length: 0))
        }
    }

    @Test func quoteIsInsertedWithoutDiscardingTheReply() {
        var draft = BBCodeDraft(text: "🖐 Ответ", selection: NSRange(location: "🖐 ".utf16.count, length: 5))
        draft.insertQuote("Привет\nмир!")
        let prefix = "🖐 \n[QUOTE]Привет\nмир![/QUOTE]\n"
        #expect(draft.text == prefix + "Ответ")
        #expect(draft.selection == NSRange(location: prefix.utf16.count, length: 0))
    }

    @Test func consecutiveQuotesShareOneLineBreak() {
        var draft = BBCodeDraft()
        draft.insertQuote("Один")
        draft.insertQuote("Два")
        #expect(draft.text == "[QUOTE]Один[/QUOTE]\n[QUOTE]Два[/QUOTE]\n")
        #expect(draft.selection == NSRange(location: draft.text.utf16.count, length: 0))
        let unchanged = draft
        draft.insertQuote("")
        #expect(draft == unchanged)
    }
}
