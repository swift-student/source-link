import Foundation

public struct Checkout: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var name = ""
  public var path = ""
  public var isDefault = false
  public init(name: String = "", path: String = "", isDefault: Bool = false) {
    self.name = name
    self.path = path
    self.isDefault = isDefault
  }
}
