import XCTest
@testable import Screeny

final class AnnotationCanvasTests: XCTestCase {
    var canvas: AnnotationCanvas!

    override func setUp() {
        super.setUp()
        canvas = AnnotationCanvas(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    // MARK: - Initial state

    func testInitialAnnotationsAreEmpty() {
        XCTAssertTrue(canvas.annotations.isEmpty)
    }

    func testNoActiveTextFieldInitially() {
        XCTAssertFalse(canvas.activeTextFieldHasSelection)
    }

    // MARK: - Undo

    func testUndoOnEmptyCanvasDoesNotCrash() {
        canvas.undo()
        XCTAssertTrue(canvas.annotations.isEmpty)
    }

    func testUndoRemovesLastAnnotation() {
        let vm = EditorViewModel()
        canvas.viewModel = vm

        // Simulate mouseDown + mouseUp to create a rectangle annotation
        let downEvent = makeMouseEvent(at: CGPoint(x: 10, y: 10))
        let dragEvent = makeMouseEvent(at: CGPoint(x: 100, y: 100))
        let upEvent   = makeMouseEvent(at: CGPoint(x: 100, y: 100))

        canvas.mouseDown(with: downEvent)
        canvas.mouseDragged(with: dragEvent)
        canvas.mouseUp(with: upEvent)

        XCTAssertEqual(canvas.annotations.count, 1)

        canvas.undo()
        XCTAssertTrue(canvas.annotations.isEmpty)
    }

    func testUndoMultipleTimes() {
        let vm = EditorViewModel()
        canvas.viewModel = vm

        for start in [10, 50, 90] as [CGFloat] {
            canvas.mouseDown(with: makeMouseEvent(at: CGPoint(x: start, y: start)))
            canvas.mouseDragged(with: makeMouseEvent(at: CGPoint(x: start + 40, y: start + 40)))
            canvas.mouseUp(with: makeMouseEvent(at: CGPoint(x: start + 40, y: start + 40)))
        }

        XCTAssertEqual(canvas.annotations.count, 3)

        canvas.undo()
        XCTAssertEqual(canvas.annotations.count, 2)

        canvas.undo()
        XCTAssertEqual(canvas.annotations.count, 1)

        canvas.undo()
        XCTAssertTrue(canvas.annotations.isEmpty)

        // Extra undo should not crash or go negative
        canvas.undo()
        XCTAssertTrue(canvas.annotations.isEmpty)
    }

    // MARK: - Commit text field

    func testCommitTextFieldIfNeededWithNoField() {
        canvas.commitTextFieldIfNeeded()
        XCTAssertTrue(canvas.annotations.isEmpty)
    }

    // MARK: - flattenToImage

    func testFlattenToImageWithScreenshotDoesNotCrash() {
        let image = NSImage(size: CGSize(width: 800, height: 600))
        canvas.screenshot = image
        _ = canvas.flattenToImage()
    }

    func testFlattenToImageWithNoScreenshotDoesNotCrash() {
        _ = canvas.flattenToImage()
    }

    // MARK: - Helpers

    private func makeMouseEvent(at point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: point,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}
