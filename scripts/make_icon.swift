#!/usr/bin/env swift
// Renders the 1024x1024 App Store icon. iOS applies the corner mask, so this is
// full-bleed and opaque (App Store Connect rejects icons with an alpha channel).
//   swift scripts/make_icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

let s = CGFloat(size)
let gradient = CGGradient(colorsSpace: space,
                          colors: [CGColor(srgbRed: 0.16, green: 0.71, blue: 0.68, alpha: 1),
                                   CGColor(srgbRed: 0.07, green: 0.29, blue: 0.50, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineCap(.round)

// dial
ctx.setLineWidth(34)
ctx.strokeEllipse(in: CGRect(x: s / 2 - 196, y: 396, width: 392, height: 392))

// needle, pointing up and to the right
ctx.setLineWidth(34)
ctx.move(to: CGPoint(x: s / 2, y: 592))
ctx.addLine(to: CGPoint(x: s / 2 + 118 * cos(.pi / 5), y: 592 + 118 * sin(.pi / 5)))
ctx.strokePath()

// hub
ctx.fillEllipse(in: CGRect(x: s / 2 - 26, y: 592 - 26, width: 52, height: 52))

// platform the scale stands on
ctx.addPath(CGPath(roundedRect: CGRect(x: 276, y: 214, width: 472, height: 74),
                   cornerWidth: 37, cornerHeight: 37, transform: nil))
ctx.fillPath()

guard let image = ctx.makeImage() else { exit(1) }
let out = URL(fileURLWithPath: "ScaleWeight/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { exit(1) }
print("wrote \(out.path)")
