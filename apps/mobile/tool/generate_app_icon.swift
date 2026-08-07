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
let oceanGradient = NSGradient(colors: [
    color(3, 23, 29),
    color(13, 58, 68),
    color(56, 45, 114),
])!
oceanGradient.draw(in: canvas, angle: -42)

color(105, 227, 216).withAlphaComponent(0.16).setFill()
NSBezierPath(ovalIn: NSRect(x: -150, y: -110, width: 620, height: 620)).fill()
color(255, 144, 190).withAlphaComponent(0.12).setFill()
NSBezierPath(ovalIn: NSRect(x: 630, y: 650, width: 520, height: 520)).fill()

let bubble = NSBezierPath(
    roundedRect: NSRect(x: 150, y: 285, width: 724, height: 510),
    xRadius: 190,
    yRadius: 190
)
bubble.lineWidth = 70
bubble.lineCapStyle = .round
bubble.lineJoinStyle = .round
color(194, 181, 255).setStroke()
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
color(194, 181, 255).setStroke()
tail.stroke()

let upperWave = NSBezierPath()
upperWave.move(to: NSPoint(x: 285, y: 555))
upperWave.curve(
    to: NSPoint(x: 520, y: 555),
    controlPoint1: NSPoint(x: 365, y: 635),
    controlPoint2: NSPoint(x: 440, y: 475)
)
upperWave.curve(
    to: NSPoint(x: 735, y: 555),
    controlPoint1: NSPoint(x: 595, y: 635),
    controlPoint2: NSPoint(x: 665, y: 485)
)
upperWave.lineWidth = 40
upperWave.lineCapStyle = .round
color(105, 227, 216).setStroke()
upperWave.stroke()

let lowerWave = NSBezierPath()
lowerWave.move(to: NSPoint(x: 305, y: 435))
lowerWave.curve(
    to: NSPoint(x: 650, y: 435),
    controlPoint1: NSPoint(x: 420, y: 525),
    controlPoint2: NSPoint(x: 535, y: 345)
)
lowerWave.lineWidth = 36
lowerWave.lineCapStyle = .round
color(255, 144, 190).setStroke()
lowerWave.stroke()

color(255, 255, 255).setFill()
NSBezierPath(ovalIn: NSRect(x: 580, y: 650, width: 86, height: 86)).fill()
let pearlOutline = NSBezierPath(ovalIn: NSRect(x: 580, y: 650, width: 86, height: 86))
pearlOutline.lineWidth = 12
color(255, 144, 190).withAlphaComponent(0.72).setStroke()
pearlOutline.stroke()

graphicsContext.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
