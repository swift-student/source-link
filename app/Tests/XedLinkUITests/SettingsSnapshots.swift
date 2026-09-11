import AppKit
import XCTest

/// Compares decoded pixels rather than PNG encoding or metadata.
@MainActor
enum SettingsSnapshots {
  static func verify(_ screenshot: XCUIScreenshot, named name: String, in test: XCTestCase,
                     file: StaticString = #filePath, line: UInt = #line) {
    let actual = screenshot.pngRepresentation
    let attachment = XCTAttachment(data: actual, uniformTypeIdentifier: "public.png")
    attachment.name = name
    attachment.lifetime = .keepAlways
    test.add(attachment)
    let baseline = Bundle(for: type(of: test)).resourceURL!
      .appendingPathComponent("Snapshots").appendingPathComponent(name).appendingPathExtension("png")
    do {
      if ProcessInfo.processInfo.environment["SOURCE_LINK_RECORD_SNAPSHOTS"] == "1" {
        return
      }
      guard FileManager.default.fileExists(atPath: baseline.path) else {
        XCTFail("Missing baseline: \(name). Run make record-snapshots and review the images.", file: file, line: line)
        return
      }
      let expected = try Data(contentsOf: baseline)
      guard let reference = pixels(expected), let candidate = pixels(actual) else {
        XCTFail("Cannot decode snapshot \(name). Run git lfs pull.", file: file, line: line)
        return
      }
      XCTAssertEqual(candidate.width, reference.width, "Snapshot width: \(name)", file: file, line: line)
      XCTAssertEqual(candidate.height, reference.height, "Snapshot height: \(name)", file: file, line: line)
      guard candidate.width == reference.width && candidate.height == reference.height else { return }
      var changed = 0
      for offset in stride(from: 0, to: candidate.bytes.count, by: 4)
      where (0..<3).contains(where: {
        abs(Int(candidate.bytes[offset + $0]) - Int(reference.bytes[offset + $0])) > 12
      }) {
        changed += 1
      }
      let fraction = Double(changed) / Double(candidate.width * candidate.height)
      if fraction > 0.001 {
        let attachment = XCTAttachment(data: expected, uniformTypeIdentifier: "public.png")
        attachment.name = "\(name) expected"
        attachment.lifetime = .keepAlways
        test.add(attachment)
        XCTFail("Snapshot \(name) changed by \(fraction * 100)% (limit 0.1%). Review the attachments.",
                file: file, line: line)
      }
    } catch {
      XCTFail("Snapshot \(name): \(error)", file: file, line: line)
    }
  }

  private struct Pixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]
  }

  private static func pixels(_ data: Data) -> Pixels? {
    guard let image = NSBitmapImageRep(data: data)?.cgImage else { return nil }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return true
    }
    return rendered ? Pixels(width: image.width, height: image.height, bytes: bytes) : nil
  }
}
