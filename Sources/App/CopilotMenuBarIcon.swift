import AppKit

/// Draws a GitHub Copilot–style icon programmatically for use in the menu bar.
///
/// The icon is a 18×18 pt NSImage drawn with explicit status colors.
/// `isTemplate` is intentionally FALSE so the color is visible in the menu bar.
/// The icon redraws per status change (green/yellow/orange/red).
///
/// Usage:
///   button.image = CopilotMenuBarIcon.image(for: .green)
///   button.imagePosition = .imageLeft
enum CopilotMenuBarIcon {
    /// Returns an 18×18 pt NSImage colored with the given status color.
    static func image(for status: StatusColor) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let color = status.nsColor
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            CopilotMenuBarIcon.drawIcon(in: ctx, rect: rect, color: color)
            return true
        }
        // NOT a template — we want the actual status color to show
        image.isTemplate = false
        return image
    }

    // MARK: - Drawing

    /// Draws a Copilot-inspired visor/robot face icon in the given color:
    ///  - Rounded-rect outline (head)
    ///  - Wide filled bar across the center (visor)
    ///  - Two small filled dots below the visor (accent detail)
    private static func drawIcon(in ctx: CGContext, rect: CGRect, color: NSColor) {
        let w = rect.width
        let h = rect.height
        let lineWidth: CGFloat = 1.5

        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)

        // Outer rounded rectangle (head outline)
        let headInset: CGFloat = 1.5
        let headRect = rect.insetBy(dx: headInset, dy: headInset)
        let cornerRadius: CGFloat = 3.5
        let headPath = CGPath(roundedRect: headRect,
                              cornerWidth: cornerRadius,
                              cornerHeight: cornerRadius,
                              transform: nil)
        ctx.addPath(headPath)
        ctx.strokePath()

        // Visor bar — filled horizontal pill in the center
        let visorHeight: CGFloat = h * 0.22
        let visorInsetX: CGFloat = headInset + 3.0
        let visorY = (h - visorHeight) / 2.0 + 1.0   // slightly above center
        let visorRect = CGRect(x: visorInsetX,
                               y: visorY,
                               width: w - visorInsetX * 2,
                               height: visorHeight)
        let visorRadius = visorHeight / 2.0
        let visorPath = CGPath(roundedRect: visorRect,
                               cornerWidth: visorRadius,
                               cornerHeight: visorRadius,
                               transform: nil)
        ctx.addPath(visorPath)
        ctx.fillPath()

        // Two small dots below the visor (chin detail)
        let dotRadius: CGFloat = 1.0
        let dotY = visorY - dotRadius * 2.8
        let leftDotX  = w * 0.35
        let rightDotX = w * 0.65
        ctx.fillEllipse(in: CGRect(x: leftDotX  - dotRadius, y: dotY - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
        ctx.fillEllipse(in: CGRect(x: rightDotX - dotRadius, y: dotY - dotRadius,
                                   width: dotRadius * 2, height: dotRadius * 2))
    }
}
