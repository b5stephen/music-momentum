//
//  PracticeLayoutTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Testing
@testable import MusicMomentum

/// A window dragged on an iPad passes through every size, so the layout has
/// to change smoothly everywhere except at its one switch.
@Suite("Practice layout")
struct PracticeLayoutTests {
    private func layout(_ width: CGFloat, _ height: CGFloat) -> PracticeLayout {
        PracticeLayout(size: CGSize(width: width, height: height), heights: .standard)
    }

    @Test("A phone with room gets the phone layout")
    func phone() {
        let phone = layout(402, 730)
        #expect(!phone.isCompact)
        #expect(phone.wheelDiameter == 260)
        #expect(phone.playSize == 68)
    }

    @Test("A short phone goes compact rather than shrinking the wheel")
    func shortPhone() {
        let short = layout(375, 580)
        #expect(short.isCompact)
        #expect(short.wheelDiameter == PracticeLayout.wheelCap(width: 375))
    }

    @Test("A roomy iPad grows past the phone sizes")
    func roomy() {
        let roomy = layout(834, 1090)
        #expect(roomy.wheelDiameter == 300)
        #expect(roomy.playSize > 68)
    }

    @Test("The wheel's width limit has no steps")
    func wheelCapIsContinuous() {
        for width in stride(from: CGFloat(320), to: 1100, by: 1) {
            #expect(abs(PracticeLayout.wheelCap(width: width + 1) - PracticeLayout.wheelCap(width: width)) <= 1)
        }
    }

    @Test("Getting shorter only grows the wheel at the compact switch")
    func shrinksSmoothly() {
        for width: CGFloat in [375, 402, 500, 640] {
            var previous = layout(width, 1000)
            for height in stride(from: CGFloat(999), through: 300, by: -1) {
                let next = layout(width, height)
                if next.isCompact == previous.isCompact {
                    #expect(next.wheelDiameter <= previous.wheelDiameter + 0.01, "\(width)×\(height)")
                    #expect(next.playSize <= previous.playSize + 0.01, "\(width)×\(height)")
                }
                previous = next
            }
        }
    }

    @Test("The wheel never drops below its floor", arguments: [
        (375.0, 300.0), (700.0, 300.0), (1000.0, 320.0),
    ])
    func floor(width: Double, height: Double) {
        #expect(layout(width, height).wheelDiameter >= 150)
    }
}
