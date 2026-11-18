import CoreGraphics

enum WiFiGlyph {
    static let size = CGSize(width: 21, height: 18)

    static func draw(in context: CGContext, color: CGColor, warning: Bool = false) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        let center = CGPoint(x: 7.8, y: 1.7)
        let angle: CGFloat = .pi * 0.28
        context.setLineWidth(1.45)
        for radius: CGFloat in [3.7, 6.4, 9.1] {
            context.move(to: CGPoint(x: center.x + radius * cos(angle),
                                     y: center.y + radius * sin(angle)))
            context.addArc(center: center, radius: radius, startAngle: angle,
                           endAngle: .pi - angle, clockwise: false)
        }
        context.strokePath()
        context.fillEllipse(in: CGRect(x: 6.65, y: 0.55, width: 2.3, height: 2.3))

        func stroke(_ points: [CGPoint], width: CGFloat) {
            context.setLineWidth(width)
            context.addLines(between: points)
            context.strokePath()
        }

        if warning {
            stroke([CGPoint(x: 17.3, y: 15.7), CGPoint(x: 17.3, y: 10.8)], width: 1.7)
            context.fillEllipse(in: CGRect(x: 16.45, y: 8.1, width: 1.7, height: 1.7))
        } else {
            stroke([CGPoint(x: 10.9, y: 16.6), CGPoint(x: 15.7, y: 16.6),
                    CGPoint(x: 10.9, y: 11.9), CGPoint(x: 15.7, y: 11.9)], width: 1.35)
            stroke([CGPoint(x: 16.65, y: 10.2), CGPoint(x: 20, y: 10.2),
                    CGPoint(x: 16.65, y: 6.9), CGPoint(x: 20, y: 6.9)], width: 1.15)
        }
    }
}
