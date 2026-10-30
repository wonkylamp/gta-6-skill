import CoreGraphics
let p = CGEvent(source: nil)!.location
for x in [p.x + 1, p.x] {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: p.y), mouseButton: .left)!.post(tap: .cghidEventTap)
}
