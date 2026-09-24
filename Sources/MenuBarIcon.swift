import AppKit

enum MenuBarIcon {
    private static let size = NSSize(width: 16, height: 20)
    private static let pointSize: CGFloat = 19
    private static let tilt: CGFloat = 20
    private static let arcGap: CGFloat = 3
    // Moves the tilted drawing so its visible outline sits in the middle of the box.
    private static let centering = CGPoint(x: -0.7, y: -1.6)
    private static let arcLength: CGFloat = 0.26
    private static let lineWidth: CGFloat = 1.3

    // Where the stem sits inside the airpodpro.right symbol, measured from its
    // rendered pixels on macOS 26. Remeasure if Apple redraws the symbol.
    private static let stemLeft: CGFloat = 0.504
    private static let stemRight: CGFloat = 0.656
    private static let stemTop: CGFloat = 0.599
    private static let stemBottom: CGFloat = 0.932

    static func make() -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            draw()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pinch"
        return image
    }

    private static func draw() {
        let oversample: CGFloat = 8
        let config = NSImage.SymbolConfiguration(pointSize: pointSize * oversample, weight: .regular)
            .applying(.init(paletteColors: [.black]))
        guard let symbol = NSImage(systemSymbolName: "airpodpro.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(config),
            let context = NSGraphicsContext.current?.cgContext else { return }
        var full = NSRect(origin: .zero, size: symbol.size)
        guard let bitmap = symbol.cgImage(forProposedRect: &full, context: nil, hints: nil) else { return }

        let symbolSize = NSSize(width: symbol.size.width / oversample, height: symbol.size.height / oversample)
        let origin = NSPoint(x: -symbolSize.width / 2, y: -symbolSize.height / 2)
        context.translateBy(x: size.width / 2 + centering.x, y: size.height / 2 + centering.y)
        context.rotate(by: tilt * .pi / 180)

        context.saveGState()
        context.translateBy(x: origin.x, y: origin.y + symbolSize.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(bitmap, in: CGRect(origin: .zero, size: symbolSize))
        context.restoreGState()

        let left = origin.x + stemLeft * symbolSize.width
        let right = origin.x + stemRight * symbolSize.width
        let top = origin.y + stemTop * symbolSize.height
        let bottom = origin.y + stemBottom * symbolSize.height
        let middle = top + (bottom - top) * 0.62
        let half = (bottom - top) * arcLength

        NSColor.black.setStroke()
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = side < 0 ? left - arcGap : right + arcGap
            let arc = NSBezierPath()
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            arc.move(to: NSPoint(x: x, y: middle - half))
            arc.curve(to: NSPoint(x: x, y: middle + half),
                      controlPoint1: NSPoint(x: x - side * half * 0.6, y: middle - half * 0.4),
                      controlPoint2: NSPoint(x: x - side * half * 0.6, y: middle + half * 0.4))
            arc.stroke()
        }
    }
}
