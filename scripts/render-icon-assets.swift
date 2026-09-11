#!/usr/bin/env swift
// Draws the app icon layers (1024 x 1024 PNGs) into SoundcorePull/AppIcon.icon/Assets.
// Coordinates below are Icon Composer points: origin at the canvas centre, y down.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("SoundcorePull/AppIcon.icon/Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func gray(_ value: CGFloat) -> CGColor { CGColor(srgbRed: value, green: value, blue: value, alpha: 1) }

func draw(_ name: String, _ body: (CGContext) -> Void) throws {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    // Flip so y grows downwards and move the origin to the centre, matching Icon Composer points.
    context.translateBy(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    context.scaleBy(x: 1, y: -1)
    body(context)
    let url = assets.appendingPathComponent("\(name).png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
    print("wrote \(url.lastPathComponent)")
}

func circle(_ context: CGContext, center: CGPoint, diameter: CGFloat, color: CGColor) {
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
}

func roundedRect(_ context: CGContext, center: CGPoint, width: CGFloat, height: CGFloat, radius: CGFloat, color: CGColor) {
    let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

let micCenter = CGPoint(x: 180, y: -190)
let micDiameter: CGFloat = 440

// Clip: a tab that pokes up from behind the mic towards the top edge.
for (variant, tone) in [("light", 0.62), ("dark", 0.30)] {
    try draw("clip-\(variant)") { context in
        roundedRect(context, center: CGPoint(x: 240, y: -350), width: 96, height: 260, radius: 45, color: gray(tone))
    }
}

// Mic: the round bean with two grille slots.
for (variant, body, grille) in [("light", 0.80, 0.55), ("dark", 0.22, 0.45)] {
    try draw("mic-\(variant)") { context in
        circle(context, center: micCenter, diameter: micDiameter, color: gray(body))
        for offset in [-150.0, 150.0] {
            roundedRect(context, center: CGPoint(x: micCenter.x, y: micCenter.y + offset), width: 70, height: 16, radius: 8, color: gray(grille))
        }
    }
}

// Symbol: an SF Symbol where the soundcore logo sits on the real case.
func symbol(_ context: CGContext, name: String, pointSize: CGFloat, center: CGPoint, color: CGColor) {
    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
    let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
    context.saveGState()
    context.scaleBy(x: 1, y: -1)                          // undo the flip so the glyph is upright
    let rect = CGRect(x: center.x - width / 2, y: -center.y - height / 2, width: width, height: height)
    context.clip(to: rect, mask: cgImage)
    context.setFillColor(color)
    context.fill(rect)
    context.restoreGState()
}

for (variant, tone) in [("light", 0.72), ("dark", 0.36)] {
    try draw("symbol-\(variant)") { context in
        symbol(context, name: "mic.fill", pointSize: 210, center: CGPoint(x: -190, y: 175), color: gray(tone))
    }
}

// LED: orange dot below the top grille, shared by both appearances.
try draw("led") { context in
    circle(context, center: CGPoint(x: micCenter.x, y: micCenter.y - 110), diameter: 22,
           color: CGColor(srgbRed: 1.0, green: 0.55, blue: 0.1, alpha: 1))
}
