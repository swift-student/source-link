import Foundation

/// Finds a project context without recursing into nested projects or workspace bundles.
enum XcodeProjectDiscovery {
  static func project(in root: URL) -> URL? {
    guard let children = try? FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return nil }

    for fileExtension in ["xcworkspace", "xcodeproj"] {
      let matches = children.filter {
        $0.pathExtension == fileExtension
          && (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      }
      // Do not silently select an arbitrary project, or a lower-priority context.
      if !matches.isEmpty {
        return matches.count == 1 ? matches.first : nil
      }
    }

    return children.first {
      $0.lastPathComponent == "Package.swift"
        && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
  }
}
