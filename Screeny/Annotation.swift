import AppKit

enum AnnotationTool: Equatable {
    case rectangle
    case arrow
    case text
    case fill       // суцільна заливка (замазати кольором)
    case pixelate   // пікселізація (blur-замазка)
}

enum Annotation {
    case rectangle(rect: CGRect, color: NSColor, lineWidth: CGFloat)
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat)
    case text(string: String, position: CGPoint, color: NSColor, fontSize: CGFloat)
    case fill(rect: CGRect, color: NSColor)
    case pixelate(rect: CGRect)
}
