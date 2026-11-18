import AppKit

enum StatusIcon {
    static func make(warning: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(1.5)

            let screen = CGRect(x: 3.25, y: 4.2, width: 13.5, height: 11)
            context.addPath(CGPath(roundedRect: screen, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
            context.strokePath()
            context.addLines(between: [CGPoint(x: 1.5, y: 2.15), CGPoint(x: 18.5, y: 2.15)])
            context.strokePath()

            if warning {
                context.addLines(between: [CGPoint(x: 10, y: 12.1), CGPoint(x: 10, y: 9.6)])
                context.strokePath()
                context.fillEllipse(in: CGRect(x: 9.25, y: 7, width: 1.5, height: 1.5))
            } else {
                context.addLines(between: [CGPoint(x: 7.9, y: 11.9), CGPoint(x: 12.1, y: 11.9),
                                           CGPoint(x: 7.9, y: 7.6), CGPoint(x: 12.1, y: 7.6)])
                context.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
