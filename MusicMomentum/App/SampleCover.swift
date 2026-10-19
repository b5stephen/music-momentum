//
//  SampleCover.swift
//  MusicMomentum
//

import SwiftUI

#if DEBUG
/// A made-up cover for a `SampleSong`, drawn rather than shipped as an image,
/// over the sample's ground colour so it matches Practice's background.
struct SampleCover: View {
    enum Design {
        case lanterns, sun, waves, road, fretboard, moon
    }

    let design: Design
    let ground: Color

    var body: some View {
        Canvas { context, size in
            let s = size.width
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s, width: 2 * r * s, height: 2 * r * s))
            }
            let all = Path(CGRect(origin: .zero, size: size))
            let dark = ground.mix(with: .black, by: 0.45)
            let light = ground.mix(with: .white, by: 0.25)
            context.fill(all, with: .linearGradient(Gradient(colors: [dark, ground, light]), startPoint: .zero, endPoint: p(0.3, 1)))

            switch design {
            case .lanterns:
                let glow = Color(red: 1.0, green: 0.74, blue: 0.36)
                for (x, y, r) in [(0.27, 0.40, 0.12), (0.62, 0.28, 0.09), (0.75, 0.62, 0.14), (0.40, 0.74, 0.08), (0.12, 0.80, 0.05)] {
                    var string = Path()
                    string.move(to: p(x, 0))
                    string.addLine(to: p(x, y - r))
                    context.stroke(string, with: .color(glow.opacity(0.35)), lineWidth: max(0.5, s * 0.004))
                    context.fill(circle(x, y, r * 1.9), with: .radialGradient(
                        Gradient(colors: [glow.opacity(0.45), .clear]), center: p(x, y), startRadius: 0, endRadius: r * 1.9 * s
                    ))
                    let body = CGRect(x: (x - r * 0.8) * s, y: (y - r) * s, width: r * 1.6 * s, height: r * 2 * s)
                    context.fill(Path(ellipseIn: body), with: .radialGradient(
                        Gradient(colors: [.white, glow, glow.mix(with: ground, by: 0.4)]),
                        center: p(x, y), startRadius: 0, endRadius: r * s
                    ))
                }
            case .sun:
                let copper = Color(red: 0.90, green: 0.52, blue: 0.28)
                let sun = circle(0.5, 0.58, 0.26)
                context.fill(sun, with: .linearGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.78, blue: 0.45), copper]), startPoint: p(0.5, 0.32), endPoint: p(0.5, 0.84)
                ))
                for i in 0..<5 {
                    let y = 0.60 + Double(i) * 0.05
                    context.fill(Path(CGRect(x: 0, y: y * s, width: s, height: s * (0.008 + Double(i) * 0.006))), with: .color(ground))
                }
                context.fill(Path(CGRect(x: 0, y: 0.80 * s, width: s, height: 0.2 * s)), with: .color(dark))
            case .waves:
                let foam = Color(red: 0.62, green: 0.86, blue: 0.84)
                for i in 0..<9 {
                    let baseline = 0.18 + Double(i) * 0.085
                    var wave = Path()
                    wave.move(to: p(0, baseline))
                    for step in 1...48 {
                        let x = Double(step) / 48
                        wave.addLine(to: p(x, baseline + 0.03 * sin((x * 2.2 + Double(i) * 0.35) * .pi * 2)))
                    }
                    context.stroke(wave, with: .color(foam.opacity(0.85 - Double(i) * 0.08)), lineWidth: s * 0.012)
                }
            case .road:
                let sky = ground.mix(with: .white, by: 0.45)
                context.fill(Path(CGRect(x: 0, y: 0, width: s, height: 0.48 * s)), with: .linearGradient(
                    Gradient(colors: [sky, ground]), startPoint: .zero, endPoint: p(0, 0.48)
                ))
                var road = Path()
                road.move(to: p(0.47, 0.48))
                road.addLine(to: p(0.53, 0.48))
                road.addLine(to: p(0.95, 1))
                road.addLine(to: p(0.05, 1))
                context.fill(road, with: .color(dark))
                for i in 0..<5 {
                    let t = Double(i) / 5, next = t + 0.1
                    let top = 0.48 + 0.52 * t * t, bottom = 0.48 + 0.52 * next * next
                    let half = 0.003 + 0.012 * next
                    context.fill(Path(CGRect(x: (0.5 - half) * s, y: top * s, width: half * 2 * s, height: (bottom - top) * s)),
                                 with: .color(Color(red: 1.0, green: 0.93, blue: 0.75)))
                }
                for x in [0.485, 0.515] {
                    context.fill(circle(x, 0.475, 0.012), with: .color(Color(red: 1.0, green: 0.42, blue: 0.32)))
                }
            case .fretboard:
                let wood = ground.mix(with: .black, by: 0.6)
                context.fill(Path(CGRect(x: 0, y: 0.28 * s, width: s, height: 0.44 * s)), with: .color(wood))
                for x in stride(from: 0.08, to: 1.0, by: 0.2) {
                    context.fill(Path(CGRect(x: x * s, y: 0.28 * s, width: s * 0.02, height: 0.44 * s)),
                                 with: .color(Color(white: 0.85).opacity(0.8)))
                }
                for x in [0.28, 0.68] {
                    context.fill(circle(x, 0.5, 0.025), with: .color(Color(white: 0.95)))
                }
                for i in 0..<6 {
                    let y = 0.31 + Double(i) * 0.076
                    context.fill(Path(CGRect(x: 0, y: y * s, width: s, height: s * (0.004 + Double(i) * 0.0015))),
                                 with: .color(Color(red: 1.0, green: 0.88, blue: 0.68)))
                }
            case .moon:
                let cream = Color(red: 0.98, green: 0.93, blue: 0.80)
                var half = Path()
                half.addArc(center: p(0.66, 0.30), radius: 0.17 * s, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                half.closeSubpath()
                context.fill(circle(0.66, 0.30, 0.17), with: .color(cream.opacity(0.12)))
                context.fill(half, with: .color(cream))
                let neon = Color(red: 1.0, green: 0.45, blue: 0.62)
                let sign = Path(roundedRect: CGRect(x: 0.12 * s, y: 0.62 * s, width: 0.52 * s, height: 0.18 * s), cornerRadius: 0.04 * s)
                context.stroke(sign, with: .color(neon.opacity(0.35)), lineWidth: s * 0.03)
                context.stroke(sign, with: .color(neon), lineWidth: s * 0.01)
                context.draw(
                    Text("MOTEL").font(.system(size: s * 0.1, weight: .heavy, design: .rounded)).foregroundStyle(neon),
                    at: p(0.38, 0.71)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("Sample covers") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
        ForEach(SampleSong.covers.indices, id: \.self) { index in
            SampleSong.covers[index].clipShape(.rect(cornerRadius: 16))
        }
    }
    .padding()
}
#endif

extension View {
    /// Draws a `SampleSong`'s cover over the no-artwork placeholder.
    func sampleCover(songID: String, cornerRadius: CGFloat) -> some View {
        #if DEBUG
        overlay {
            if let cover = SampleSong.cover(for: songID) {
                cover.clipShape(.rect(cornerRadius: cornerRadius))
            }
        }
        #else
        self
        #endif
    }
}
