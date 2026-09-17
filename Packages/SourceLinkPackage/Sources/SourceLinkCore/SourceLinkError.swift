import Foundation

public enum SourceLinkError: LocalizedError {
  case invalidLink, outsideRepository, missingFile, invalidEditor, launchFailed

  case unresolvedSymbol, missingSymbol, missingText

  public var errorDescription: String? {
    switch self {
    case .unresolvedSymbol: "Choose a matching symbol before opening this link."
    case .missingSymbol: "No matching declaration was found in this file. Check the symbol name and checkout."
    case .missingText:
      "The literal find text was not found in any matching declaration. Check the snippet, symbol, and checkout."
    case .invalidLink:
      "Invalid source link. Use a repository, relative file path, "
        + "and either a symbol in a Swift, Ruby, Kotlin, or TypeScript file or positive line/column numbers. "
        + "An optional nonempty find value requires a symbol."
    case .outsideRepository: "The requested file is outside the selected repository."
    case .missingFile: "The requested file does not exist in this checkout."
    case .invalidEditor: "The editor executable is missing. Set its executable path in Settings."
    case .launchFailed: "The editor could not open the file. Check the editor installation and selected checkout."
    }
  }
}
