# Working on Kopier

Kopier is a small native macOS clipboard editor written in Swift with AppKit. Keep changes focused, local, and dependency-free unless the user requests otherwise.

## Project map

- `Source/main.swift`: app lifecycle, menus, editable clipboard view, polling, history drawer, and actions.
- `Source/ClipboardHistory.swift`: bounded session history model.
- `Source/ClipboardTextView.swift`: editor placeholder and history row separators.
- `Scripts/MakeIcon.swift`: reproducible pixel copier icon generation.
- `Assets/`: generated icon sources, included in the project.
- `Tests/HistoryTests.swift`: focused history model checks.
- `build.sh`: creates and locally signs `Kopier.app`; the app bundle is ignored by Git.

## Product behavior

- Open at 460 × 460 by default. Keep the centered title, editable text, responsive history drawer, and compact single row of **Copy**, **Clear**, and **Show History** buttons.
- Start with an empty editor and history. Observe the initial clipboard change count without importing or clearing existing contents.
- The empty editor shows “Copy any text and it will show here” as a placeholder, never real clipboard content.
- Automatic formatting removal starts on. Preserve Unicode, whitespace, and line breaks. Respect concealed/transient clipboard markers; leave non-text copies alone.
- Keep history only in memory, newest first, at most 1,000 records; evict oldest entries. Never persist, log, or transmit clipboard contents.
- Selecting history loads the editor. Copying happens through the main **Copy** button; do not add a separate history copy button.
- **Clear** empties the clipboard and editor while preserving history. **Clear All** empties only history.
- App-generated clipboard writes must update the observed change count to avoid polling loops and duplicate history.
- History rows wrap to available width and resize with the window. Draw separators only for actual records, not empty rows.
- Quit belongs in the standard macOS app menu and Dock, with Command-Q; keep it out of the window's button row.

## Build and verification

Run `./build.sh` after code changes. Verify signing with `codesign --verify --deep --strict Kopier.app`.

For changes to history behavior, run:

```sh
cat Source/ClipboardHistory.swift Tests/HistoryTests.swift > /private/tmp/kopier-history-tests.swift
swift -module-cache-path /private/tmp/kopier-module-cache /private/tmp/kopier-history-tests.swift
```

For clipboard action tests, use `NSPasteboard.withUniqueName()` so tests never clear or overwrite the user's clipboard. Check relevant layouts at the default size and with the history drawer open when changing UI.

Update `README.md` when controls or behavior change. Avoid introducing dependencies, persistent storage, network access, or extra permission requirements for routine features.
