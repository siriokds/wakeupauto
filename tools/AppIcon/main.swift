import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let colors = [
    CGColor(srgbRed: 0.25, green: 0.53, blue: 0.77, alpha: 1),
    CGColor(srgbRed: 0.08, green: 0.20, blue: 0.38, alpha: 1)
]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!

func chunk(_ type: String, _ payload: Data) -> Data {
    var result = Data(type.utf8)
    var length = UInt32(payload.count + 8).bigEndian
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(payload)
    return result
}

let representations = [
    ("icp4", 16), ("ic11", 32), ("icp5", 32), ("ic12", 64), ("ic07", 128),
    ("ic13", 256), ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024)
]

func renderPNG(pixels: Int) -> Data {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    let tile = CGRect(x: 70, y: 70, width: 884, height: 884)
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 208, cornerHeight: 208, transform: nil))
    context.clip()
    context.drawLinearGradient(gradient, start: CGPoint(x: 200, y: 930),
                               end: CGPoint(x: 800, y: 90),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    let glyphScale: CGFloat = 28
    context.translateBy(x: (1024 - WiFiGlyph.size.width * glyphScale) / 2,
                        y: (1024 - WiFiGlyph.size.height * glyphScale) / 2)
    context.scaleBy(x: glyphScale, y: glyphScale)
    WiFiGlyph.draw(in: context, color: CGColor(gray: 1, alpha: 1))

    let png = NSMutableData()
    let output = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(output, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(output), "Could not generate the app icon")
    return png as Data
}

var icon = Data()
var rendered: [Int: Data] = [:]
for (type, size) in representations {
    let png = rendered[size] ?? renderPNG(pixels: size)
    rendered[size] = png
    icon.append(chunk(type, png))
}
try chunk("icns", icon).write(to: destination, options: .atomic)
