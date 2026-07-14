import AppKit
import Foundation

let pixels = 1024
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift tool/generate_app_icon.swift <output.png>\n", stderr)
    exit(2)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create icon canvas")
}

guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create graphics context")
}

func color(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
    NSColor(
        calibratedRed: CGFloat(red) / 255,
        green: CGFloat(green) / 255,
        blue: CGFloat(blue) / 255,
        alpha: 1
    )
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
color(18, 20, 22).setFill()
NSBezierPath(rect: canvas).fill()

let bubble = NSBezierPath(
    roundedRect: NSRect(x: 150, y: 285, width: 724, height: 510),
    xRadius: 190,
    yRadius: 190
)
bubble.lineWidth = 70
bubble.lineCapStyle = .round
bubble.lineJoinStyle = .round
color(184, 200, 245).setStroke()
bubble.stroke()

let tail = NSBezierPath()
tail.move(to: NSPoint(x: 590, y: 300))
tail.curve(
    to: NSPoint(x: 335, y: 205),
    controlPoint1: NSPoint(x: 515, y: 170),
    controlPoint2: NSPoint(x: 390, y: 190)
)
tail.lineWidth = 70
tail.lineCapStyle = .round
tail.lineJoinStyle = .round
color(184, 200, 245).setStroke()
tail.stroke()

color(113, 214, 200).setFill()
NSBezierPath(ovalIn: NSRect(x: 340, y: 500, width: 92, height: 92)).fill()
NSBezierPath(ovalIn: NSRect(x: 570, y: 500, width: 92, height: 92)).fill()

graphicsContext.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
