import AppKit

final class ClipboardTextView: NSTextView {
    static let placeholder = "Copy any text and it will show here"

    override var string: String {
        didSet { needsDisplay = true }
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let rect = NSRect(
            x: textContainerInset.width + 5,
            y: textContainerInset.height,
            width: max(0, bounds.width - textContainerInset.width * 2 - 10),
            height: 50
        )
        (Self.placeholder as NSString).draw(in: rect, withAttributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ])
    }
}

final class HistoryRowView: NSTableRowView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.separatorColor.setFill()
        let pixel = 1 / (window?.backingScaleFactor ?? 2)
        let bottom = isFlipped ? bounds.maxY - pixel : bounds.minY
        NSRect(x: bounds.minX, y: bottom, width: bounds.width, height: pixel).fill()
    }
}
