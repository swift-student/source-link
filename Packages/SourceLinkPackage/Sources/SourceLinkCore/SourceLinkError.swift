import Foundation

public enum SourceLinkError: LocalizedError {
  case invalidLink, outsideRepository, missingFile, invalidEditor, launchFailed

  public var errorDescription: String? {
    switch self {
    case .invalidLink: "Invalid source link. Use a repository, relative file path, and positive line/column numbers."
    case .outsideRepository: "The requested file is outside the selected repository."
    case .missingFile: "The requested file does not exist in this checkout."
    case .invalidEditor: "The editor executable is missing. Set its executable path in Settings."
    case .launchFailed: "The editor could not open the file. Check the editor installation and selected checkout."
    }
  }
}
