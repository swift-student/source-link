import Foundation

let result = Command.run(Array(CommandLine.arguments.dropFirst()))
FileHandle.standardOutput.write(Data(result.output.utf8))
FileHandle.standardError.write(Data(result.diagnostics.utf8))
exit(result.status)
