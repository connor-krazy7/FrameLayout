import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Grid layout")
struct FLGridTests {
    private let context = FLContext(width: 320)

    private func swatches(_ heights: [CGFloat]) -> [FLFrame<FLColor>] {
        heights.map { FLColor(.systemBlue).frame(height: $0) }
    }

    @Test("equal columns split the offered extent minus the gaps")
    func equalColumnsSplitTheExtent() {
        let layout = FLVGrid(columns: 3, spacing: 4) {
            FLForEach(Array(0..<3), id: \.self) { _ in
                FLColor(.systemBlue).frame(height: 20)
            }
        }
        .layout(in: context)

        #expect(layout.size == CGSize(width: 320, height: 20))
        #expect(layout.childFrames.map(\.width) == [104, 104, 104])
        #expect(layout.childFrames.map(\.minX) == [0, 108, 216])
    }

    @Test("children fill row-major and break onto new lines")
    func childrenBreakIntoLines() {
        let layout = FLVGrid(columns: 3, spacing: 4) {
            FLForEach(Array(0..<5), id: \.self) { _ in
                FLColor(.systemBlue).frame(height: 20)
            }
        }
        .layout(in: context)

        #expect(layout.size.height == 44)
        #expect(layout.childFrames.map(\.minY) == [0, 0, 0, 24, 24])
        #expect(layout.childFrames[3].minX == 0)
    }

    @Test("a cell is proposed its column width and no height, so a ratio makes squares")
    func cellsDeriveHeightFromWidth() {
        let layout = FLVGrid(columns: 2, spacing: 10) {
            FLForEach(Array(0..<2), id: \.self) { _ in
                FLColor(.systemBlue).aspectRatio(1, contentMode: .fit)
            }
        }
        .layout(in: context)

        #expect(layout.childFrames[0].size == CGSize(width: 155, height: 155))
        #expect(layout.size.height == 155)
    }

    @Test("a line is as tall as its tallest cell, and shorter cells align within it")
    func raggedLinesTakeTheTallestCell() {
        let layout = FLVGrid(columns: 3, spacing: 0) {
            FLColor(.systemBlue).frame(height: 10)
            FLColor(.systemBlue).frame(height: 40)
            FLColor(.systemBlue).frame(height: 20)
        }
        .layout(in: context)

        #expect(layout.size.height == 40)
        #expect(layout.childFrames[0].minY == 15)
        #expect(layout.childFrames[1].minY == 0)
        #expect(layout.childFrames[2].minY == 10)
    }

    @Test("fixed and flexible columns share what is left")
    func fixedAndFlexibleColumns() {
        let layout = FLVGrid(columns: [.fixed(96), .flexible()], columnSpacing: 10) {
            FLColor(.systemBlue).frame(height: 20)
            FLColor(.systemBlue).frame(height: 20)
        }
        .layout(in: context)

        #expect(layout.childFrames.map(\.width) == [96, 214])
        #expect(layout.childFrames.map(\.minX) == [0, 106])
    }

    @Test("a column's own spacing overrides the grid's")
    func perColumnSpacingOverrides() {
        let layout = FLVGrid(columns: [.fixed(96, spacing: 20), .flexible()], columnSpacing: 10) {
            FLColor(.systemBlue).frame(height: 20)
            FLColor(.systemBlue).frame(height: 20)
        }
        .layout(in: context)

        #expect(layout.childFrames.map(\.width) == [96, 204])
        #expect(layout.childFrames[1].minX == 116)
    }

    @Test("adaptive columns repeat as often as they fit")
    func adaptiveColumnsRepeat() {
        let layout = FLVGrid(columns: .adaptive(minimum: 96), spacing: 8) {
            FLForEach(Array(0..<6), id: \.self) { _ in
                FLColor(.systemBlue).frame(height: 20)
            }
        }
        .layout(in: context)

        #expect(layout.childFrames.map(\.minY).max() == 28)
        #expect(layout.childFrames.filter { $0.minY == 0 }.count == 3)
    }

    @Test("fixed columns narrower than the offer make the grid hug them")
    func fixedColumnsHug() {
        let layout = FLVGrid(columns: [.fixed(60), .fixed(60)], columnSpacing: 10) {
            FLColor(.systemBlue).frame(height: 20)
            FLColor(.systemBlue).frame(height: 20)
        }
        .layout(in: context)

        #expect(layout.size.width == 130)
    }

    @Test("a horizontal grid declares rows and accumulates columns")
    func horizontalGridMirrorsTheVerticalOne() {
        let layout = FLHGrid(rows: 2, spacing: 8) {
            FLColor(.systemPink).frame(width: 50)
            FLColor(.systemPink).frame(width: 60)
            FLColor(.systemPink).frame(width: 70)
        }
        .layout(in: FLContext(width: .unspecified, height: .exact(168)))

        #expect(layout.childFrames.map(\.height) == [80, 80, 80])
        #expect(layout.childFrames.map(\.minY) == [0, 88, 0])
        #expect(layout.size.height == 168)
        #expect(layout.size.width == CGFloat(60 + 8 + 70))
    }
}
