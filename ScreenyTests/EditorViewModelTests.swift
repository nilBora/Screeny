import XCTest
@testable import Screeny

final class EditorViewModelTests: XCTestCase {
    var viewModel: EditorViewModel!

    override func setUp() {
        super.setUp()
        viewModel = EditorViewModel()
    }

    // MARK: - Defaults

    func testDefaultTool() {
        XCTAssertEqual(viewModel.selectedTool, .rectangle)
    }

    func testDefaultColorIndex() {
        XCTAssertEqual(viewModel.selectedColorIndex, 0)
    }

    func testDefaultLineWidthIndex() {
        XCTAssertEqual(viewModel.selectedLineWidthIndex, 1)
    }

    // MARK: - Tool selection

    func testToolSwitching() {
        for tool in [AnnotationTool.arrow, .text, .fill, .pixelate, .rectangle] {
            viewModel.selectedTool = tool
            XCTAssertEqual(viewModel.selectedTool, tool)
        }
    }

    // MARK: - Colors

    func testPresetColorsCount() {
        XCTAssertEqual(viewModel.presetColors.count, 6)
    }

    func testSelectedColorMatchesIndex() {
        for i in viewModel.presetColors.indices {
            viewModel.selectedColorIndex = i
            XCTAssertEqual(viewModel.selectedColor, viewModel.presetColors[i])
        }
    }

    func testFirstColorIsRed() {
        viewModel.selectedColorIndex = 0
        XCTAssertEqual(viewModel.selectedColor, .systemRed)
    }

    // MARK: - Line widths

    func testLineWidthsCount() {
        XCTAssertEqual(viewModel.lineWidths.count, 3)
    }

    func testCurrentLineWidthMatchesIndex() {
        for i in viewModel.lineWidths.indices {
            viewModel.selectedLineWidthIndex = i
            XCTAssertEqual(viewModel.currentLineWidth, viewModel.lineWidths[i])
        }
    }

    func testDefaultLineWidthIsMedium() {
        XCTAssertEqual(viewModel.currentLineWidth, 3.0)
    }

    func testLineWidthsAreAscending() {
        let widths = viewModel.lineWidths
        XCTAssertTrue(widths[0] < widths[1] && widths[1] < widths[2])
    }
}
