import Foundation

public struct DocumentLink: Equatable, Sendable {
  /// The URL as written in the document, before decoding markup entities.
  public let text: String
  public let line: Int
  public let column: Int
  public let urlText: String
}

/// Scans URL literals, including examples in code blocks; it does not render the document.
public enum DocumentLinks {
  public static func extract(from document: String, decodeEntities: Bool = false) throws -> [DocumentLink] {
    let scheme = try NSRegularExpression(pattern: #"(?i)(?<![\w+.-])source-link:"#)
    return document.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .enumerated().flatMap { offset, line in
        scheme.matches(in: String(line), range: NSRange(line.startIndex..., in: line)).compactMap { match in
          guard let range = Range(match.range, in: line) else { return nil }
          let text = token(in: line, from: range.lowerBound)
          let code = range.lowerBound > line.startIndex && line[line.index(before: range.lowerBound)] == "`"
          return DocumentLink(text: text, line: offset + 1,
                              column: line.distance(from: line.startIndex, to: range.lowerBound) + 1,
                              urlText: decodeEntities && !code ? decode(text) : text)
        }
      }
  }

  private static func token(in line: Substring, from start: String.Index) -> String {
    let previous = start == line.startIndex ? nil : line[line.index(before: start)]
    if let previous, "\"'`<".contains(previous) {
      let closing: Character = previous == "<" ? ">" : previous
      return String(line[start...].prefix { $0 != closing })
    }
    var end = start
    var closing: [Character] = []
    let pairs: [Character: Character] = ["(": ")", "[": "]", "{": "}"]
    while end < line.endIndex {
      let character = line[end]
      if character.isWhitespace || "<>\"'`".contains(character) {
        break
      }
      if let close = pairs[character] {
        closing.append(close)
      } else if ")]}".contains(character) {
        guard closing.last == character else { break }
        closing.removeLast()
      }
      end = line.index(after: end)
    }
    let markdownDestination = previous == "(" && line[..<start].dropLast().last == "]"
    // Sentence punctuation is ambiguous in bare URLs. Keep explicit link destinations exact.
    if !markdownDestination, previous != "=" {
      while end > start, ".,;!?".contains(line[line.index(before: end)]) {
        end = line.index(before: end)
      }
    }
    return String(line[start ..< end])
  }

  private static func decode(_ text: String) -> String {
    // Decode once, preserving URL percent escapes for SourceLink. No HTML renderer or external resources are used.
    let named = ["amp": "&", "quot": "\"", "apos": "'", "lt": "<", "gt": ">"]
    var result = ""
    var index = text.startIndex
    while index < text.endIndex {
      if text[index] == "&", let end = text[index...].firstIndex(of: ";") {
        let name = String(text[text.index(after: index) ..< end])
        let number: UInt32? = if name.lowercased().hasPrefix("#x") {
          UInt32(name.dropFirst(2), radix: 16)
        } else if name.hasPrefix("#") {
          UInt32(name.dropFirst())
        } else {
          nil
        }
        if let value = named[name] ?? number.flatMap(Unicode.Scalar.init).map(String.init) {
          result += value
          index = text.index(after: end)
          continue
        }
      }
      result.append(text[index])
      index = text.index(after: index)
    }
    return result
  }
}
