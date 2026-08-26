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

NSGraphicsContext.saveGraphicsState()
let paddleTransform = NSAffineTransform()
paddleTransform.translateX(by: 485, yBy: 490)
paddleTransform.rotate(byDegrees: -18)
paddleTransform.concat()

let handle = NSBezierPath(
    roundedRect: NSRect(x: -58, y: -330, width: 116, height: 235),
    xRadius: 34,
    yRadius: 34
)
NSColor(red: 0.10, green: 0.25, blue: 0.34, alpha: 1).setFill()
handle.fill()

let grip = NSBezierPath(
    roundedRect: NSRect(x: -48, y: -315, width: 96, height: 145),
    xRadius: 28,
    yRadius: 28
)
NSColor(red: 0.72, green: 0.31, blue: 0.22, alpha: 1).setFill()
grip.fill()

let paddle = NSBezierPath(
    roundedRect: NSRect(x: -190, y: -140, width: 380, height: 480),
    xRadius: 120,
    yRadius: 120
)
NSColor(red: 0.91, green: 0.35, blue: 0.20, alpha: 1).setFill()
paddle.fill()
NSColor(red: 0.10, green: 0.25, blue: 0.34, alpha: 1).setStroke()
paddle.lineWidth = 14
paddle.stroke()

let paddleFace = NSBezierPath(
    roundedRect: NSRect(x: -160, y: -100, width: 320, height: 400),
    xRadius: 98,
    yRadius: 98
)
NSColor(red: 0.98, green: 0.90, blue: 0.73, alpha: 1).setFill()
paddleFace.fill()

NSColor(red: 0.10, green: 0.25, blue: 0.34, alpha: 0.72).setFill()
let holeCenters: [(CGFloat, CGFloat)] = [
    (-62, 170), (0, 195), (62, 170)
]
for (x, y) in holeCenters {
    NSBezierPath(ovalIn: NSRect(x: x - 15, y: y - 15, width: 30, height: 30)).fill()
}
NSGraphicsContext.restoreGraphicsState()

let ballR: CGFloat = 82
let ballCenter = NSPoint(x: 700, y: 750)
let ball = NSRect(
    x: ballCenter.x - ballR,
    y: ballCenter.y - ballR,
    width: ballR * 2,
    height: ballR * 2
)
NSColor(red: 0.85, green: 0.95, blue: 0.20, alpha: 1).setFill()
NSBezierPath(ovalIn: ball).fill()
NSColor(red: 0.10, green: 0.25, blue: 0.34, alpha: 1).setStroke()
let ballStroke = NSBezierPath(ovalIn: ball)
ballStroke.lineWidth = 10
ballStroke.stroke()

NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: CommandLine.arguments[1])
guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}
try png.write(to: out)
