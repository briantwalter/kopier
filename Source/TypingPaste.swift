import AppKit
import ApplicationServices

/// Intercepts Command-V only while explicitly enabled, outside Kopier.
final class TypingPaste {
    private var timer: Timer?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var swallowingPaste = false
    private var requestedAccessibility = false
    var speed: () -> Double = { 0.075 }
    private var activationObserver: NSObjectProtocol?
    private var chunks: [String] = []
    private var index = 0
    private var target: NSRunningApplication?
    private var interval = 0.075
    var status: ((String) -> Void)?
    var isRunning: Bool { timer != nil || target != nil }

    static func characters(in text: String) -> [String] {
        // Swift Characters keep emoji and combining marks together while preserving
        // every space, tab, and line break exactly as copied.
        text.map { String($0) }
    }

    @discardableResult
    func enable() -> Bool {
        disable()
        // Check silently first. The system list may contain an approval for an
        // older ad-hoc build, so repeatedly prompting cannot repair that entry.
        guard AXIsProcessTrusted() else {
            if !requestedAccessibility {
                requestedAccessibility = true
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)
            }
            status?("Accessibility blocked. Re-add this Kopier app in Settings, then retry.")
            return false
        }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) |
                   (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context = context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<TypingPaste>.fromOpaque(context).takeUnretainedValue()
                return owner.handle(type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            status?("Could not enable paste shortcut. Check Accessibility permission.")
            return false
        }
        eventTap = tap
        eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), eventSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        status?("Press Command-V in your destination. Esc stops typing.")
        return true
    }

    func disable() {
        stop("")
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        if let source = eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventSource = nil
        eventTap = nil
        swallowingPaste = false
    }

    private func handle(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop("Typing stopped.")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if key == 9 && swallowingPaste {
            if type == .keyUp { swallowingPaste = false }
            return nil
        }
        if type == .keyDown && key == 53 && isRunning {
            stop()
            return nil
        }
        let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
        guard type == .keyDown, key == 9, modifiers == .maskCommand,
              let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return Unmanaged.passUnretained(event)
        }
        // Read the clipboard at the hotkey, never stale editor contents. Let private
        // and non-text clipboard items follow the destination's normal paste path.
        let board = NSPasteboard.general
        guard let text = Self.eligibleText(from: board), !text.isEmpty else {
            return Unmanaged.passUnretained(event)
        }
        swallowingPaste = true
        if !isRunning { start(text, target: app) }
        return nil
    }

    static func eligibleText(from board: NSPasteboard) -> String? {
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        guard !privateTypes.contains(where: { board.types?.contains(NSPasteboard.PasteboardType($0)) == true }) else { return nil }
        return board.string(forType: .string)
    }

    private func start(_ text: String, target: NSRunningApplication) {
        stop("")
        self.target = target
        interval = speed()
        chunks = Self.characters(in: text)
        index = 0
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self, let target = self.target else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
                self.stop("Typing stopped: app changed.")
            }
        }
        // Wait for Command to be released so it cannot modify the typed text.
        status?("Release Command to begin typing. Esc stops.")
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let held = CGEventSource.flagsState(.combinedSessionState)
                .intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            guard held.isEmpty else { return }
            timer.invalidate()
            self.timer = nil
            self.sendNext()
        }
    }

    private func sendNext() {
        guard let target = target,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
              !target.isTerminated, AXIsProcessTrusted() else {
            stop("Typing stopped.")
            return
        }
        guard index < chunks.count else { stop("Typing complete."); return }
        let chunk = chunks[index]
        // Send exactly one composed character per timer tick.
        let units = Array(chunk.utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            stop("Unable to send typing events."); return
        }
        for event in [down, up] {
            event.flags = []
            units.withUnsafeBufferPointer {
                event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
            }
            event.postToPid(target.processIdentifier)
        }
        index += 1
        status?("Typing… Esc stops.")
        let pause: Double
        if chunk.contains(where: { $0.isNewline }) {
            pause = 6
        } else if chunk.contains(where: { ".!?;:".contains($0) }) {
            pause = 4
        } else if chunk.contains(where: { $0.isWhitespace || $0 == "," }) {
            pause = 2
        } else {
            pause = 1
        }
        let delay = interval * Double.random(in: 0.65...1.45) * pause
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.timer = nil
            self?.sendNext()
        }
    }

    func stop(_ message: String = "Typing stopped.") {
        timer?.invalidate()
        timer = nil
        target = nil
        chunks.removeAll()
        if let observer = activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        activationObserver = nil
        status?(message)
    }
}
