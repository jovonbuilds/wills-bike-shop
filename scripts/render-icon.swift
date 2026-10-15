// Renders the Will's Bike Shop app icon with CoreGraphics.
//
// Regenerate (run from the repo root):
//
//   swift scripts/render-icon.swift
//
// Outputs:
//   WillsBikeShop/Assets.xcassets/Contents.json
//   WillsBikeShop/Assets.xcassets/AppIcon.appiconset/   every macOS size + Contents.json
//   docs/icon-1024.png                              1024 px preview for the README
//
// The icon: an amber wheel on a graphite squircle, ringed by a glowing speedometer
// arc like the dashboard's gauge, trimmed in amber. Each size is drawn from vectors
// at its own pixel size rather than downscaled; small sizes get heavier strokes and
// drop the spokes and arc, which turn to mush below 64 px.
//
// The tile, trim, lit-solid and glow helpers are adapted from Reload's
// render-icon.swift by miotke (MIT): https://github.com/miotke/reload

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Paths

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoDir = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let catalogDir = repoDir.appendingPathComponent("WillsBikeShop/Assets.xcassets")
let iconSetDir = catalogDir.appendingPathComponent("AppIcon.appiconset")
let docsDir = repoDir.appendingPathComponent("docs")

// MARK: - Colors

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: sRGB,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha,
        ])!
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
}

/// A colour fading to fully transparent, for halos and sheens.
func fade(_ color: CGColor) -> CGGradient {
    gradient([(0, color), (1, color.copy(alpha: 0)!)])
}

// MARK: - Geometry (1024-point design space, y grows downward)

/// macOS icon grid: 824 pt rounded square centred on a 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let wheelCenter = CGPoint(x: 512, y: 524)

/// Superellipse approximating Apple's continuous-corner icon shape.
func squircle(in rect: CGRect, exponent n: CGFloat = 5.2) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY, a = rect.width / 2, b = rect.height / 2
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * copysign(pow(abs(c), 2 / n), c)
        let y = cy + b * copysign(pow(abs(s), 2 / n), s)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func circle(_ center: CGPoint, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2), transform: nil)
}

/// The tire: a thick ring.
func tire() -> CGPath {
    circle(wheelCenter, 262).subtracting(circle(wheelCenter, 196))
}

/// The gauge arc: 240° opening at the bottom, like the dashboard's speedometer.
/// Angles are in the flipped design space, so 150° is lower-left, sweeping clockwise over the top.
func gaugeArc(radius: CGFloat, fraction: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let start = CGFloat(150) * .pi / 180
    let sweep = CGFloat(240) * .pi / 180 * fraction
    path.addArc(center: wheelCenter, radius: radius, startAngle: start, endAngle: start + sweep, clockwise: false)
    return path
}

// MARK: - Shared drawing helpers

/// Flips into the 1024-point design space and returns the stroke weight for this size.
func begin(_ ctx: CGContext, pixels: Int) -> (scale: CGFloat, weight: CGFloat) {
    let scale = CGFloat(pixels) / 1024
    // Heavier strokes at small sizes so details survive downsampling.
    let weight: CGFloat = pixels <= 16 ? 1.9 : pixels <= 32 ? 1.25 : pixels <= 64 ? 1.15 : 1
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    return (scale, weight)
}

struct TileStyle {
    var base: CGColor
    var background: [(CGFloat, CGColor)]
    var halo: CGColor?
    var haloCenter = CGPoint(x: 512, y: 500)
    var haloRadius: CGFloat = 420
    var trim: [(CGFloat, CGColor)]
    var trimWidth: CGFloat = 10
    var shadowAlpha: CGFloat = 0.35
    var gloss: CGFloat = 0.4
}

/// The squircle with drop shadow, background, halo, inner trim and top gloss.
func drawTile(_ ctx: CGContext, _ style: TileStyle, scale: CGFloat, weight: CGFloat, pixels: Int) {
    let shape = squircle(in: tile)

    ctx.saveGState()
    // Shadow offsets are in unflipped device space, so negative heights fall downward.
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 20 * scale, color: rgb(0x000000, style.shadowAlpha))
    ctx.addPath(shape)
    ctx.setFillColor(style.base)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(style.background),
        start: CGPoint(x: 512, y: tile.minY), end: CGPoint(x: 512, y: tile.maxY), options: [])
    if let halo = style.halo {
        ctx.drawRadialGradient(
            fade(halo), startCenter: style.haloCenter, startRadius: 0,
            endCenter: style.haloCenter, endRadius: style.haloRadius, options: [])
    }
    ctx.restoreGState()

    // Trim just inside the tile edge.
    ctx.saveGState()
    ctx.addPath(squircle(in: tile.insetBy(dx: 14, dy: 14)))
    ctx.setLineWidth(style.trimWidth * weight)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(style.trim),
        start: CGPoint(x: 512, y: tile.minY), end: CGPoint(x: 512, y: tile.maxY), options: [])
    ctx.restoreGState()

    // Glassy top highlight on the outer edge.
    if pixels > 32 {
        ctx.saveGState()
        ctx.addPath(shape)
        ctx.setLineWidth(6)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([(0, rgb(0xFFFFFF, style.gloss)), (0.12, rgb(0xFFFFFF, 0.0))]),
            start: CGPoint(x: 512, y: tile.minY), end: CGPoint(x: 512, y: tile.maxY), options: [])
        ctx.restoreGState()
    }
}

/// How a raised solid is lit.
struct Material {
    var shadow: CGColor
    var shadowDrop: CGFloat = 18
    var shadowBlur: CGFloat = 36
    var base: CGColor
    var body: [(CGFloat, CGColor)]
    var bodyEndInset: CGFloat = 80
    var sheen: CGColor?
    var sheenOffset = CGPoint(x: 120, y: 200)
    var sheenRadius: CGFloat = 260
    var highlight: CGColor
    var highlightDepth: CGFloat = 10
    var lowlight: CGColor
    var lowlightDepth: CGFloat = 12
    var rim: CGColor
    var rimWidth: CGFloat = 6
}

/// Fills `path` as a lifted solid: cast shadow, diagonal body gradient,
/// specular sheen, bevel light on top edges and shade on bottom edges, rim.
func drawSolid(_ ctx: CGContext, _ path: CGPath, _ m: Material, scale: CGFloat, weight: CGFloat) {
    let box = path.boundingBoxOfPath

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -m.shadowDrop * scale), blur: m.shadowBlur * scale, color: m.shadow)
    ctx.addPath(path)
    ctx.setFillColor(m.base)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(m.body),
        start: CGPoint(x: box.minX, y: box.minY), end: CGPoint(x: box.maxX - m.bodyEndInset, y: box.maxY), options: [])
    if let sheen = m.sheen {
        let c = CGPoint(x: box.minX + m.sheenOffset.x, y: box.minY + m.sheenOffset.y)
        ctx.drawRadialGradient(fade(sheen), startCenter: c, startRadius: 0, endCenter: c, endRadius: m.sheenRadius, options: [])
    }
    // Bevel: the shape minus itself shifted down leaves a sliver along top edges.
    var down = CGAffineTransform(translationX: 0, y: m.highlightDepth)
    ctx.addPath(path.subtracting(path.copy(using: &down)!))
    ctx.setFillColor(m.highlight)
    ctx.fillPath()
    var up = CGAffineTransform(translationX: 0, y: -m.lowlightDepth)
    ctx.addPath(path.subtracting(path.copy(using: &up)!))
    ctx.setFillColor(m.lowlight)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(path)
    ctx.setStrokeColor(m.rim)
    ctx.setLineWidth(m.rimWidth * weight)
    ctx.strokePath()
}

/// Strokes `path` as light: a bloom of widening translucent strokes, then a bright core.
/// Built from strokes rather than a blurred shadow, which CoreGraphics clips
/// to the stroke's bounding box.
func glow(_ ctx: CGContext, _ path: CGPath, width: CGFloat, color: CGColor, core: CGColor, bloom: CGFloat) {
    ctx.saveGState()
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    let rings = 10
    for i in stride(from: rings, through: 1, by: -1) {
        let t = CGFloat(i) / CGFloat(rings)
        ctx.addPath(path)
        ctx.setLineWidth(width + bloom * t)
        ctx.setStrokeColor(color.copy(alpha: color.alpha * 0.16 * (1 - t * 0.6))!)
        ctx.strokePath()
    }
    ctx.addPath(path)
    ctx.setLineWidth(width)
    ctx.setStrokeColor(color)
    ctx.strokePath()
    ctx.addPath(path)
    ctx.setLineWidth(width * 0.45)
    ctx.setStrokeColor(core)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Palette

let amber = Material(
    shadow: rgb(0x000000, 0.6),
    base: rgb(0xA65E08),
    body: [(0, rgb(0xFFE6A6)), (0.35, rgb(0xFFBA36)), (0.75, rgb(0xE38C12)), (1, rgb(0xA65E08))],
    bodyEndInset: 120,
    sheen: rgb(0xFFF6DC, 0.5), sheenOffset: CGPoint(x: 150, y: 120), sheenRadius: 220,
    highlight: rgb(0xFFF3CF, 0.6),
    lowlight: rgb(0x5A3204, 0.55),
    rim: rgb(0x3E2203, 0.9))

// MARK: - Icon

func drawIcon(in ctx: CGContext, pixels: Int) {
    let (scale, weight) = begin(ctx, pixels: pixels)
    drawTile(
        ctx,
        TileStyle(
            base: rgb(0x111316),
            // Graphite, like the dashboard at night.
            background: [(0, rgb(0x3C424B)), (0.55, rgb(0x1E2228)), (1, rgb(0x0B0D10))],
            halo: rgb(0xFFB020, 0.20),
            haloCenter: wheelCenter,
            haloRadius: 380,
            trim: [(0, rgb(0xFFD27A, 0.95)), (0.5, rgb(0xD08A1E, 0.75)), (1, rgb(0x6B420C, 0.9))]),
        scale: scale, weight: weight, pixels: pixels)

    // Speedometer: a dim track with a glowing reading, outside the tire.
    if pixels >= 64 {
        ctx.saveGState()
        ctx.addPath(gaugeArc(radius: 328, fraction: 1))
        ctx.setLineWidth(22)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(rgb(0xFFFFFF, 0.08))
        ctx.strokePath()
        ctx.restoreGState()
        glow(ctx, gaugeArc(radius: 328, fraction: 0.68), width: 22 * weight,
             color: rgb(0xFFB020), core: rgb(0xFFF1C4), bloom: 46)
    }

    // Spokes, laced in crossing pairs like a real wheel.
    if pixels >= 64 {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(9 * weight)
        ctx.setStrokeColor(rgb(0xC9CED6, 0.75))
        let spokes = 16
        for i in 0..<spokes {
            let rimAngle = CGFloat(i) / CGFloat(spokes) * 2 * .pi
            let hubAngle = rimAngle + (i % 2 == 0 ? 0.42 : -0.42)
            ctx.move(to: CGPoint(x: wheelCenter.x + 40 * cos(hubAngle), y: wheelCenter.y + 40 * sin(hubAngle)))
            ctx.addLine(to: CGPoint(x: wheelCenter.x + 200 * cos(rimAngle), y: wheelCenter.y + 200 * sin(rimAngle)))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    drawSolid(ctx, tire(), amber, scale: scale, weight: weight)

    // Tread: short cuts across the tire face, only where there's room to see them.
    if pixels >= 128 {
        ctx.saveGState()
        ctx.addPath(tire())
        ctx.clip()
        ctx.setLineCap(.round)
        ctx.setLineWidth(10)
        ctx.setStrokeColor(rgb(0x5A3204, 0.35))
        let treads = 36
        for i in 0..<treads {
            let a = CGFloat(i) / CGFloat(treads) * 2 * .pi
            ctx.move(to: CGPoint(x: wheelCenter.x + 214 * cos(a), y: wheelCenter.y + 214 * sin(a)))
            ctx.addLine(to: CGPoint(x: wheelCenter.x + 244 * cos(a + 0.05), y: wheelCenter.y + 244 * sin(a + 0.05)))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    var hub = amber
    hub.shadowDrop = 8
    hub.shadowBlur = 16
    hub.highlightDepth = 6
    hub.lowlightDepth = 7
    hub.sheenOffset = CGPoint(x: 30, y: 26)
    hub.sheenRadius = 60
    hub.bodyEndInset = 20
    drawSolid(ctx, circle(wheelCenter, pixels <= 32 ? 64 : 50), hub, scale: scale, weight: weight)
}

// MARK: - Output

func makeContext(width: Int, height: Int) throws -> CGContext {
    guard
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "render-icon", code: 1) }
    return ctx
}

func writePNG(_ ctx: CGContext, to url: URL) throws {
    guard let image = ctx.makeImage(),
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw NSError(domain: "render-icon", code: 2) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "render-icon", code: 3) }
}

func renderPNG(pixels: Int, to url: URL) throws {
    let ctx = try makeContext(width: pixels, height: pixels)
    drawIcon(in: ctx, pixels: pixels)
    try writePNG(ctx, to: url)
}

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try (data + Data("\n".utf8)).write(to: url)
}

let fm = FileManager.default
let info = ["author": "xcode", "version": 1] as [String: Any]

try fm.createDirectory(at: iconSetDir, withIntermediateDirectories: true)
try fm.createDirectory(at: docsDir, withIntermediateDirectories: true)
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try renderPNG(pixels: points * factor, to: iconSetDir.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(factor)x", "size": "\(points)x\(points)"])
    }
}
try writeJSON(["images": images, "info": info], to: iconSetDir.appendingPathComponent("Contents.json"))
try writeJSON(["info": info], to: catalogDir.appendingPathComponent("Contents.json"))
try renderPNG(pixels: 1024, to: docsDir.appendingPathComponent("icon-1024.png"))
print("Wrote \(images.count) icon images to \(iconSetDir.path)")
