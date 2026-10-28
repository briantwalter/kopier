import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate {
    private let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var aboutWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let preview = ClipboardTextView()
    private let automatic = NSButton(checkboxWithTitle: "Automatically remove formatting when I copy text", target: nil, action: nil)
    private var timer: Timer?
    private var lastChange = -1
    private var currentText: String?
    private var history = ClipboardHistory()
    private let historyTable = NSTableView()
    private let drawer = NSStackView()
    private let historyToggle = NSButton(title: "Show History", target: nil, action: nil)
    private var drawerWidth: NSLayoutConstraint!
    private let historyCount = NSTextField(labelWithString: "0 / 1,000 copies")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        updaterController.startUpdater()
        configureMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 22, height: 22)
            icon.isTemplate = true
            statusItem.button?.image = icon
        }
        statusItem.button?.toolTip = "Kopier"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showWindow)
        lastChange = NSPasteboard.general.changeCount
        createWindow()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
        showWindow()
    }

    private func createWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 428), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Kopier"
        window.titleVisibility = .hidden
        if let titleBar = window.standardWindowButton(.closeButton)?.superview {
            let title = NSTextField(labelWithString: "Kopier")
            title.identifier = NSUserInterfaceItemIdentifier("CenteredWindowTitle")
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            title.alignment = .center
            title.translatesAutoresizingMaskIntoConstraints = false
            titleBar.addSubview(title)
            NSLayoutConstraint.activate([
                title.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
                title.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor)
            ])
        }
        window.minSize = NSSize(width: 430, height: 360)
        window.isReleasedWhenClosed = false
        window.delegate = self
        var initialFrame = window.frame
        initialFrame.size = NSSize(width: 460, height: 460)
        window.setFrame(initialFrame, display: false)
        window.center()
        let container = NSStackView()
        container.orientation = .horizontal
        container.distribution = .fill
        container.alignment = .top
        container.spacing = 0
        container.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            container.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor)
        ])
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(root)
        root.widthAnchor.constraint(greaterThanOrEqualToConstant: 430).isActive = true
        root.heightAnchor.constraint(equalTo: container.heightAnchor).isActive = true
        configureDrawer()
        drawerWidth = drawer.widthAnchor.constraint(equalTo: root.widthAnchor, multiplier: 0.65)
        drawerWidth.priority = .defaultHigh
        container.addArrangedSubview(drawer)
        drawer.heightAnchor.constraint(equalTo: container.heightAnchor).isActive = true
        drawer.isHidden = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        preview.isEditable = true
        preview.delegate = self
        preview.allowsUndo = true
        preview.setAccessibilityLabel("Editable clipboard text")
        preview.isSelectable = true
        preview.isRichText = false
        preview.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        preview.textContainerInset = NSSize(width: 12, height: 12)
        preview.autoresizingMask = [.width]
        preview.isVerticallyResizable = true
        preview.isHorizontallyResizable = false
        preview.textContainer?.widthTracksTextView = true
        scroll.documentView = preview
        root.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -44).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        automatic.state = .on
        automatic.target = self
        automatic.action = #selector(toggleAutomatic)
        root.addArrangedSubview(automatic)
        let actions = NSStackView()
        actions.orientation = .horizontal
        actions.spacing = 10
        let copy = NSButton(title: "Copy", target: self, action: #selector(copyPlain))
        copy.bezelStyle = .rounded
        copy.keyEquivalent = "\r"
        actions.addArrangedSubview(copy)
        let clear = NSButton(title: "Clear", target: self, action: #selector(clearClipboard))
        clear.bezelStyle = .rounded
        actions.addArrangedSubview(clear)
        historyToggle.target = self
        historyToggle.action = #selector(toggleHistory)
        historyToggle.bezelStyle = .rounded
        actions.addArrangedSubview(historyToggle)
        root.addArrangedSubview(actions)
    }

    private func configureMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Kopier")
        let about = appMenu.addItem(withTitle: "About Kopier", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        let updates = appMenu.addItem(withTitle: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updates.target = updaterController
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Kopier", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    @objc private func showAbout() {
        if aboutWindow == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "About Kopier"
            panel.isReleasedWhenClosed = false
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 12
            stack.translatesAutoresizingMaskIntoConstraints = false
            let icon = NSImageView()
            icon.image = NSApp.applicationIconImage
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.widthAnchor.constraint(equalToConstant: 80).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 80).isActive = true
            icon.setAccessibilityLabel("Kopier icon")
            stack.addArrangedSubview(icon)
            let name = NSTextField(labelWithString: "Kopier")
            name.font = .boldSystemFont(ofSize: 22)
            name.alignment = .center
            stack.addArrangedSubview(name)
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            let releaseDate = Bundle.main.object(forInfoDictionaryKey: "KopierReleaseDate") as? String ?? ""
            for text in ["Version \(version)", "Released \(releaseDate)"] {
                let label = NSTextField(labelWithString: text)
                label.alignment = .center
                label.textColor = .secondaryLabelColor
                stack.addArrangedSubview(label)
            }
            panel.contentView!.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor),
                stack.leadingAnchor.constraint(greaterThanOrEqualTo: panel.contentView!.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: panel.contentView!.trailingAnchor, constant: -20)
            ])
            panel.center()
            aboutWindow = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func configureDrawer() {
        drawer.orientation = .vertical
        drawer.alignment = .leading
        drawer.spacing = 12
        drawer.edgeInsets = NSEdgeInsets(top: 22, left: 16, bottom: 22, right: 16)
        drawer.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        let heading = NSTextField(labelWithString: "Copy History")
        heading.font = .systemFont(ofSize: 18, weight: .semibold)
        drawer.addArrangedSubview(heading)
        historyCount.textColor = .secondaryLabelColor
        drawer.addArrangedSubview(historyCount)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.width = 240
        historyTable.addTableColumn(column)
        historyTable.headerView = nil
        historyTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        column.resizingMask = .autoresizingMask
        historyTable.intercellSpacing = .zero
        historyTable.gridStyleMask = []
        historyTable.usesAlternatingRowBackgroundColors = false
        historyTable.backgroundColor = .textBackgroundColor
        historyTable.dataSource = self
        historyTable.delegate = self
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.documentView = historyTable
        scroll.borderType = .bezelBorder
        drawer.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: drawer.widthAnchor, constant: -32).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        let clear = NSButton(title: "Clear All", target: self, action: #selector(clearHistory))
        clear.bezelStyle = .rounded
        drawer.addArrangedSubview(clear)
    }

    @objc private func toggleHistory() {
        let opening = drawer.isHidden
        drawerWidth.isActive = opening
        drawer.isHidden = !opening
        historyToggle.title = opening ? "Hide History" : "Show History"
        window.minSize = NSSize(width: opening ? 710 : 430, height: 360)
        var frame = window.frame
        frame.size.width += opening ? 280 : -drawer.frame.width
        window.setFrame(frame, display: true, animate: true)
        updateHistoryHeights()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { history.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        HistoryRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label = NSTextField(wrappingLabelWithString: history[row])
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),
            label.bottomAnchor.constraint(lessThanOrEqualTo: cell.bottomAnchor, constant: -6)
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let width = max(1, (tableView.tableColumns.first?.width ?? 248) - 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let bounds = (history[row] as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 13), .paragraphStyle: paragraph]
        )
        return max(30, ceil(bounds.height) + 12)
    }

    private func updateHistoryHeights() {
        historyTable.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<history.count))
    }

    func tableViewColumnDidResize(_ notification: Notification) {
        updateHistoryHeights()
    }

    func windowDidResize(_ notification: Notification) {
        updateHistoryHeights()
    }

    func textDidChange(_ notification: Notification) {
        currentText = preview.string
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = historyTable.selectedRow
        guard history.indices.contains(row) else { return }
        loadText(history[row])
    }

    private func loadText(_ text: String?) {
        currentText = text
        preview.string = text ?? ""
        preview.undoManager?.removeAllActions()
    }

    @objc private func clearClipboard() {
        let board = NSPasteboard.general
        board.clearContents()
        lastChange = board.changeCount
        historyTable.deselectAll(nil)
        loadText(nil)
    }

    @objc private func clearHistory() {
        history.removeAll()
        historyTable.reloadData()
        historyCount.stringValue = "0 / 1,000 copies"
    }

    @objc private func showWindow() {
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func refresh() {
        let board = NSPasteboard.general
        guard board.changeCount != lastChange else { return }
        lastChange = board.changeCount
        // Honor common password-manager markers; never rewrite these copies.
        let sensitive = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"].contains { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }
        guard !sensitive else {
            loadText(nil)
            return
        }
        currentText = board.string(forType: .string)
        if currentText == nil {
            for kind in [NSPasteboard.PasteboardType.rtf, .html] {
                if let data = board.data(forType: kind),
                   let rich = NSAttributedString(rtf: data, documentAttributes: nil), kind == .rtf {
                    currentText = rich.string
                    break
                }
                if kind == .html, let data = board.data(forType: kind),
                   let rich = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
                    currentText = rich.string
                    break
                }
            }
        }
        loadText(currentText)
        if let text = currentText {
            history.record(text)
            historyTable.deselectAll(nil)
            historyTable.reloadData()
            historyCount.stringValue = "\(history.count) / 1,000 copies"
            if automatic.state == .on { writePlain(text) }
        }
    }

    private func writePlain(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        lastChange = board.changeCount
    }

    @objc private func copyPlain() {
        refresh()
        guard let text = currentText else { NSSound.beep(); return }
        writePlain(text)
    }

    @objc private func toggleAutomatic() {
        if automatic.state == .on { copyPlain() }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
