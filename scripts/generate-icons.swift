// Run from the repository root: swift scripts/generate-icons.swift
// The approved artwork is preserved in docs/assets/source-link.png.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("app/Sources/SourceLinkApp/Assets.xcassets")
let sourceData = try Data(contentsOf: root.appendingPathComponent("docs/assets/source-link.png"))
guard let source = NSBitmapImageRep(data: sourceData) else {
  fatalError("Unable to load the Source Link master artwork")
}

/// Turn the monochrome artwork into a black alpha mask so the menu-bar template
/// has no white background. Remove the generated image's surrounding whitespace.
let mask = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: source.pixelsWide, pixelsHigh: source.pixelsHigh,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
var bounds = NSRect.null
for row in 0 ..< source.pixelsHigh {
  for column in 0 ..< source.pixelsWide {
    let color = source.colorAt(x: column, y: row)!.usingColorSpace(.deviceRGB)!
    let luminance = (color.redComponent + color.greenComponent + color.blueComponent) / 3
    // Suppress near-white background noise while retaining antialiased edges.
    let alpha = max(0, min(1, (0.95 - luminance) / 0.95)) * color.alphaComponent
    mask.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: alpha), atX: column, y: row)
    if alpha > 0.5 {
      bounds = bounds.union(NSRect(x: column, y: row, width: 1, height: 1))
    }
  }
}

guard !bounds.isNull, let maskImage = mask.cgImage else {
  fatalError("The Source Link artwork contains no visible mark")
}

let side = max(bounds.width, bounds.height)
let crop = NSRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side).integral
guard let cropped = maskImage.cropping(to: crop) else {
  fatalError("Unable to crop the Source Link artwork")
}

func writeJSON(_ value: [String: Any], to url: URL) throws {
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}

func render(pixels: Int, appIcon: Bool, to url: URL) throws {
  let size = CGFloat(pixels)
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  )!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  NSGraphicsContext.current?.imageInterpolation = .high
  let canvas = NSRect(x: 0, y: 0, width: size, height: size)
  NSColor.clear.setFill()
  canvas.fill(using: .copy)
  if appIcon {
    // A neutral tile keeps the black mark visible in Finder on either appearance.
    let tile = canvas.insetBy(dx: size * 0.08, dy: size * 0.08)
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile, xRadius: size * 0.18, yRadius: size * 0.18).fill()
    NSGraphicsContext.current?.cgContext.draw(cropped, in: canvas.insetBy(dx: size * 0.16, dy: size * 0.16))
  } else {
    NSGraphicsContext.current?.cgContext.draw(cropped, in: canvas)
  }
  NSGraphicsContext.restoreGraphicsState()
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
  }
  try png.write(to: url)
}

let info: [String: Any] = ["author": "xcode", "version": 1]
try writeJSON(["info": info], to: assets.appendingPathComponent("Contents.json"))
let menu = assets.appendingPathComponent("SourceLinkMenu.imageset")
try writeJSON([
  "info": info,
  "properties": ["template-rendering-intent": "template"],
  "images": [
    ["filename": "menu.png", "idiom": "mac", "scale": "1x"],
    ["filename": "menu@2x.png", "idiom": "mac", "scale": "2x"]
  ]
], to: menu.appendingPathComponent("Contents.json"))
try render(pixels: 20, appIcon: false, to: menu.appendingPathComponent("menu.png"))
try render(pixels: 40, appIcon: false, to: menu.appendingPathComponent("menu@2x.png"))

let appIcon = assets.appendingPathComponent("AppIcon.appiconset")
var images: [[String: String]] = []
try FileManager.default.createDirectory(at: appIcon, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let filename = "icon_\(points)x\(points)@\(scale)x.png"
    images.append([
      "filename": filename, "idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x"
    ])
    try render(pixels: points * scale, appIcon: true, to: appIcon.appendingPathComponent(filename))
  }
}

try writeJSON(["info": info, "images": images], to: appIcon.appendingPathComponent("Contents.json"))
print("Generated Source Link app and menu-bar icons.")
