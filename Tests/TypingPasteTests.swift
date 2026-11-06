// Combine with Source/TypingPaste.swift to run. Uses a unique pasteboard only.
let samples = ["", "hello world", "  hello\tworld\n\n", "👩🏽‍💻 café 中文\r\nnext", "one   two!"]
for sample in samples {
    let characters = TypingPaste.characters(in: sample)
    precondition(characters.joined() == sample)
    precondition(characters.allSatisfy { $0.count == 1 })
}
precondition(TypingPaste.characters(in: "Hi 👩🏽‍💻e\u{301}") == ["H", "i", " ", "👩🏽‍💻", "e\u{301}"])
let board = NSPasteboard.withUniqueName()
defer { board.releaseGlobally() }
board.setString("Hello 👋\n  world", forType: .string)
precondition(TypingPaste.eligibleText(from: board) == "Hello 👋\n  world")
for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"] {
    board.clearContents()
    board.setString("private", forType: .string)
    board.setData(Data(), forType: NSPasteboard.PasteboardType(marker))
    precondition(TypingPaste.eligibleText(from: board) == nil)
}
board.clearContents()
board.setData(Data(), forType: .png)
precondition(TypingPaste.eligibleText(from: board) == nil)
print("Typing preservation and private/non-text clipboard checks passed")
