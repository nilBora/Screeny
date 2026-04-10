import AppKit
import Combine

class EditorViewModel: ObservableObject {
    @Published var selectedTool: AnnotationTool = .rectangle
    @Published var selectedColorIndex: Int = 0
    @Published var selectedLineWidthIndex: Int = 1

    // Order must match ToolbarView.presetColors
    let presetColors: [NSColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .white,
    ]
    let lineWidths: [CGFloat] = [1.5, 3.0, 6.0]

    var selectedColor: NSColor { presetColors[selectedColorIndex] }
    var currentLineWidth: CGFloat { lineWidths[selectedLineWidthIndex] }
}
