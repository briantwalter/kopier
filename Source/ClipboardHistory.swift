// Session memory only. No serialization or preferences storage.
struct ClipboardHistory {
    private var records: [String] = []
    static let limit = 1_000
    var count: Int { records.count }
    var indices: Range<Int> { records.indices }
    subscript(index: Int) -> String { records[index] }

    mutating func record(_ text: String) {
        records.insert(text, at: 0)
        if records.count > Self.limit {
            records.removeLast(records.count - Self.limit)
        }
    }

    mutating func removeAll() { records.removeAll() }
}
