//
//  MacPracticeLayoutTests.swift
//  MusicMomentumTests
//

import CoreGraphics
import Testing
@testable import MusicMomentum

@Suite("Mac practice layout")
struct MacPracticeLayoutTests {
    private func layout(_ width: CGFloat, _ height: CGFloat) -> MacPracticeLayout {
        MacPracticeLayout(size: CGSize(width: width, height: height))
    }

    @Test("A 1180pt window with the sidebar showing leaves Practice wide")
    func sidebarShowing() {
        #expect(layout(908, 700).isWide)
    }

    @Test("A narrow window gets the compact layout")
    func narrow() {
        let compact = layout(720, 700)
        #expect(!compact.isWide)
        #expect(compact.knobDiameter == 216)
        #expect(compact.coverSide == 112)
    }

    @Test("Wide switches on at its minimum width and not before")
    func widthEdge() {
        #expect(!layout(MacPracticeLayout.wideMinimum.width - 1, 800).isWide)
        #expect(layout(MacPracticeLayout.wideMinimum.width, 800).isWide)
    }

    @Test("A short window is compact however wide")
    func short() {
        #expect(!layout(1400, MacPracticeLayout.wideMinimum.height - 1).isWide)
        #expect(layout(1400, MacPracticeLayout.wideMinimum.height).isWide)
    }

    @Test("Wide sizes are the larger set")
    func sizes() {
        let wide = layout(1200, 800)
        #expect(wide.knobDiameter == 284)
        #expect(wide.coverSide == 172)
        #expect(wide.titleSize == 34)
        #expect(wide.volumeWidth == 213)
    }
}
