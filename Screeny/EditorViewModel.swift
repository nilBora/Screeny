import AppKit
import Combine

class EditorViewModel: ObservableObject {
    @Published var selectedTool: AnnotationTool = .rectangle
    @Published var selectedColorIndex: Int = 0
    @Published var selectedLineWidthIndex: Int = 1

    let presetColors: [NSColor] = [
        .systemRed, .systemBlue, .systemGreen,
        .systemYellow, .systemOrange, .white
    ]
    let lineWidths: [CGFloat] = [1.5, 3.0, 6.0]

    var selectedColor: NSColor { presetColors[selectedColorIndex] }
    var currentLineWidth: CGFloat { lineWidths[selectedLineWidthIndex] }
}
