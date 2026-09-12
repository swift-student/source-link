import Foundation
import SourceLinkCore

let arguments = Array(CommandLine.arguments.dropFirst())
do {
  if arguments == ["config", "path"] {
    print(ConfigurationPaths.file().path)
  } else if arguments.count == 2 || arguments.count == 3, Array(arguments.prefix(2)) == ["config", "validate"] {
    let file = arguments.count == 3
      ? URL(fileURLWithPath: ConfigurationPaths.expand(arguments[2])) : ConfigurationPaths.file()
    do {
      _ = try ConfigurationDocument(text: String(contentsOf: file, encoding: .utf8))
      print("\(file.path): valid")
    } catch { throw ConfigurationError("\(file.path): \(error.localizedDescription)") }
  } else {
    FileHandle.standardError.write(Data("Usage: source-link config path | config validate [FILE]\n".utf8))
    exit(2)
  }
} catch {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  exit(1)
}
