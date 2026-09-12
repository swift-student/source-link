import Foundation

public enum Editor: String, Codable, CaseIterable, Identifiable, Sendable {
  case xcode, vscode, cursor, zed
  public var id: String {
    rawValue
  }

  public var title: String {
    switch self {
    case .xcode: "Xcode"
    case .vscode: "Visual Studio Code"
    case .cursor: "Cursor"
    case .zed: "Zed"
    }
  }

  public var defaultExecutable: String {
    switch self {
    case .xcode: "/usr/bin/xed"
    case .vscode: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    case .cursor: "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    case .zed: "/Applications/Zed.app/Contents/MacOS/cli"
    }
  }
}
