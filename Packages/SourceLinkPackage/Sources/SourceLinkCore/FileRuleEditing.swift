import Foundation

public extension SourceSettings {
  /// Adds a rule whose extension is unused, comparing normalized extensions.
  @discardableResult
  mutating func addFileRule() -> FileRule {
    let extensions = Set(rules.map(\.normalizedExtension))
    var rule = FileRule()
    if extensions.contains(rule.fileExtension) {
      rule.fileExtension = "txt"
      var suffix = 2
      while extensions.contains(rule.fileExtension) {
        rule.fileExtension = "extension\(suffix)"
        suffix += 1
      }
    }
    rules.append(rule)
    return rule
  }
}
