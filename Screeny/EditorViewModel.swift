import AppKit
import Combine

class EditorViewModel: ObservableObject {
    @Published var selectedTool: AnnotationTool = .rectangle
    @Published var selectedColorIndex: Int = 0

    let presetColors: [NSColor] = [
        .systemRed, .systemBlue, .systemGreen,
        .systemYellow, .systemOrange, .white
    ]

    var selectedColor: NSColor { presetColors[selectedColorIndex] }
}
