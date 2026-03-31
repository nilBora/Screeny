import AppKit

enum AnnotationTool: Equatable {
    case rectangle
    case arrow
    case text
}

enum Annotation {
    case rectangle(rect: CGRect, color: NSColor, lineWidth: CGFloat)
    case arrow(start: CGPoint, end: CGPoint, color: NSColor, lineWidth: CGFloat)
    case text(string: String, position: CGPoint, color: NSColor, fontSize: CGFloat)
}
