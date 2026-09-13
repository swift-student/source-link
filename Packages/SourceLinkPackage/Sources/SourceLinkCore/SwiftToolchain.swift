import Darwin
import Foundation

/// SourceKitten traps when its library cannot be found. Check its macOS search locations first.
enum SwiftToolchain {
  static func validate() throws {
    let environment = ProcessInfo.processInfo.environment
    var roots = [environment["XCODE_DEFAULT_TOOLCHAIN_OVERRIDE"], environment["TOOLCHAIN_DIR"]].compactMap(\.self)
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["--find", "swift"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.standardInput = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    if process.terminationStatus == 0,
       let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       path.hasSuffix("/usr/bin/swift") {
      roots.append(String(path.dropLast("/usr/bin/swift".count)))
    }
    for directory in ["/Applications", NSHomeDirectory() + "/Applications"] {
      for app in ["Xcode.app", "Xcode-beta.app"] {
        roots.append("\(directory)/\(app)/Contents/Developer/Toolchains/XcodeDefault.xctoolchain")
      }
    }
    let library = "sourcekitdInProc.framework/Versions/A/sourcekitdInProc"
    for path in roots.map({ $0 + "/usr/lib/" + library }) + [library] {
      if let handle = dlopen(path, RTLD_LAZY) {
        dlclose(handle)
        return
      }
    }
    throw SourceLinkError.missingSwiftToolchain
  }
}
