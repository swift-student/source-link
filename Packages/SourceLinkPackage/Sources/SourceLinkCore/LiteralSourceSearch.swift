import Foundation

/// Byte-exact search in one source snapshot, without Unicode or whitespace normalization.
struct LiteralSourceSearch {
  private let source: Data
  private let snippet: Data

  init(source: String, snippet: String) {
    self.source = Data(source.utf8)
    self.snippet = Data(snippet.utf8)
  }

  func offsets(in range: Range<Int>) -> [Int] {
    guard !snippet.isEmpty else { return [] }
    var offsets: [Int] = []
    var start = range.lowerBound
    while start < range.upperBound,
          let match = source.range(of: snippet, in: start ..< range.upperBound) {
      offsets.append(match.lowerBound)
      // Count overlapping occurrences too, e.g. both "ana" matches in "banana".
      start = match.lowerBound + 1
    }
    return offsets
  }

  func line(at offset: Int) -> String {
    // A match starting at LF inside CRLF still belongs to the preceding line.
    let anchor = offset > 0 && source[offset] == 10 && source[offset - 1] == 13 ? offset - 1 : offset
    let start = source[..<anchor].lastIndex { $0 == 10 || $0 == 13 }.map { $0 + 1 } ?? 0
    let end = source[anchor...].firstIndex { $0 == 10 || $0 == 13 } ?? source.endIndex
    return (String(bytes: source[start ..< end], encoding: .utf8) ?? "").trimmingCharacters(in: .whitespaces)
  }
}
