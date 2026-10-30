//
//  LoopCaptionTests.swift
//  MusicMomentumTests
//

import Testing
@testable import MusicMomentum

@Suite("Loop caption")
struct LoopCaptionTests {
    @Test("Off says so, whatever the clips")
    func off() {
        #expect(LoopCaption.text(isOn: false, clips: []) == "Loop off")
        #expect(LoopCaption.text(isOn: false, clips: [.init(name: "Chorus", length: 34)]) == "Loop off")
    }

    @Test("On with no clips is the whole song")
    func wholeSong() {
        #expect(LoopCaption.text(isOn: true, clips: []) == "Looping whole song")
    }

    @Test("One clip is named, with its length")
    func oneClip() {
        #expect(LoopCaption.text(isOn: true, clips: [.init(name: "Chorus", length: 34)]) == "Looping Chorus \u{00B7} 0:34")
        #expect(LoopCaption.text(isOn: true, clips: [.init(name: "Solo", length: 75)]) == "Looping Solo \u{00B7} 1:15")
    }

    @Test("A clip that is no longer in the song is still a clip")
    func unnamed() {
        #expect(LoopCaption.text(isOn: true, clips: [.init(name: nil, length: 20)]) == "Looping one clip \u{00B7} 0:20")
    }

    @Test("A chain counts its clips and adds their lengths")
    func chain() {
        let clips: [LoopCaption.Clip] = [.init(name: "A", length: 20), .init(name: "B", length: 45)]
        #expect(LoopCaption.text(isOn: true, clips: clips) == "Looping 2 clips \u{00B7} 1:05")
    }
}
