//
//  OKLCH.swift
//  MusicMomentum
//

import CoreGraphics
import Foundation

/// A colour as lightness, chroma and hue, where equal steps of lightness look
/// equal whatever the hue, so a cover colour can be darkened without turning grey.
nonisolated struct OKLCH: Equatable {
    /// 0 black to 1 white.
    var l: Double
    var c: Double
    /// Degrees, 0..<360.
    var h: Double

    init(l: Double, c: Double, h: Double) {
        self.l = l
        self.c = c
        self.h = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Gamma-encoded sRGB components, 0...1.
    init(red: Double, green: Double, blue: Double) {
        let (r, g, b) = (Self.linear(red), Self.linear(green), Self.linear(blue))
        let lms = (
            cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b),
            cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b),
            cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        )
        let lightness = 0.2104542553 * lms.0 + 0.7936177850 * lms.1 - 0.0040720468 * lms.2
        let a = 1.9779984951 * lms.0 - 2.4285922050 * lms.1 + 0.4505937099 * lms.2
        let b2 = 0.0259040371 * lms.0 + 0.7827717662 * lms.1 - 0.8086757660 * lms.2
        self.init(l: lightness, c: hypot(a, b2), h: atan2(b2, a) * 180 / .pi)
    }

    init?(_ color: CGColor) {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3
        else { return nil }
        self.init(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]))
    }

    /// Gamma-encoded sRGB, with chroma pulled in until the colour fits.
    var srgb: (red: Double, green: Double, blue: Double) {
        let fitted = Self.linearRGB(l: l, c: min(c, Self.maxChroma(l: l, h: h)), h: h)
        return (Self.encode(fitted.0), Self.encode(fitted.1), Self.encode(fitted.2))
    }

    var cgColor: CGColor {
        let (r, g, b) = srgb
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// How much of the chroma sRGB allows at this lightness and hue it uses, 0...1.
    var vividness: Double {
        let available = Self.maxChroma(l: l, h: h)
        return available > 0.0001 ? min(1, c / available) : 0
    }

    /// The most chroma sRGB can show at this lightness and hue.
    static func maxChroma(l: Double, h: Double) -> Double {
        guard l > 0, l < 1 else { return 0 }
        var (low, high) = (0.0, 0.4)
        for _ in 0..<24 {
            let mid = (low + high) / 2
            let rgb = linearRGB(l: l, c: mid, h: h)
            if [rgb.0, rgb.1, rgb.2].allSatisfy({ (-0.0001...1.0001).contains($0) }) { low = mid } else { high = mid }
        }
        return low
    }

    private static func linearRGB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
        let lms = (
            pow(l + 0.3963377774 * a + 0.2158037573 * b, 3),
            pow(l - 0.1055613458 * a - 0.0638541728 * b, 3),
            pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)
        )
        return (
            4.0767416621 * lms.0 - 3.3077115913 * lms.1 + 0.2309699292 * lms.2,
            -1.2684380046 * lms.0 + 2.6097574011 * lms.1 - 0.3413193965 * lms.2,
            -0.0041960863 * lms.0 - 0.7034186147 * lms.1 + 1.7076147010 * lms.2
        )
    }

    private static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func encode(_ c: Double) -> Double {
        let c = min(1, max(0, c))
        return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}
