import AppKit

let size = 1024
let colorSpace = NSColorSpace.deviceRGB
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("bitmap failed\n", stderr)
    exit(1)
}
rep.size = NSSize(width: size, height: size)

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(red: 0.16, green: 0.42, blue: 0.62, alpha: 1).setFill()
bounds.fill()

let inset: CGFloat = 90
let court = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let courtPath = NSBezierPath(roundedRect: court, xRadius: 36, yRadius: 36)
NSColor(red: 0.18, green: 0.48, blue: 0.70, alpha: 1).setFill()
courtPath.fill()

let kitchenHeight = court.height * (14.0 / 44.0)
let kitchen = NSRect(
    x: court.minX,
    y: court.midY - kitchenHeight / 2,
    width: court.width,
    height: kitchenHeight
)
NSColor(red: 0.72, green: 0.31, blue: 0.22, alpha: 1).setFill()
kitchen.fill()

let line = NSBezierPath()
line.lineWidth = 14
NSColor.white.withAlphaComponent(0.92).setStroke()

func hline(_ y: CGFloat) {
    line.move(to: NSPoint(x: court.minX, y: y))
    line.line(to: NSPoint(x: court.maxX, y: y))
}
hline(court.midY)
hline(kitchen.minY)
hline(kitchen.maxY)

line.move(to: NSPoint(x: court.midX, y: court.minY))
line.line(to: NSPoint(x: court.midX, y: kitchen.minY))
line.move(to: NSPoint(x: court.midX, y: kitchen.maxY))
line.line(to: NSPoint(x: court.midX, y: court.maxY))
line.stroke()

NSColor.white.setStroke()
courtPath.lineWidth = 18
courtPath.stroke()

let ballR: CGFloat = 78
let ball = NSRect(
    x: court.midX + 70,
    y: court.minY + court.height * 0.28 - ballR,
    width: ballR * 2,
    height: ballR * 2
)
NSColor(red: 0.85, green: 0.95, blue: 0.20, alpha: 1).setFill()
NSBezierPath(ovalIn: ball).fill()
NSColor.black.withAlphaComponent(0.45).setStroke()
let ballStroke = NSBezierPath(ovalIn: ball)
ballStroke.lineWidth = 8
ballStroke.stroke()

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}
try png.write(to: out)
