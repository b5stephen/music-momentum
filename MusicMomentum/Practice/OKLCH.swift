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
        let lab = Self.oklab(red: red, green: green, blue: blue)
        self.init(l: lab.l, a: lab.a, b: lab.b)
    }

    /// From OKLab's opposing axes, green to red and blue to yellow, which
    /// average without a hue's wrap-around at 360°.
    init(l: Double, a: Double, b: Double) {
        self.init(l: l, c: hypot(a, b), h: atan2(b, a) * 180 / .pi)
    }

    /// OKLab for gamma-encoded sRGB components, 0...1.
    static func oklab(red: Double, green: Double, blue: Double) -> (l: Double, a: Double, b: Double) {
        let (r, g, b) = (linear(red), linear(green), linear(blue))
        let lms = (
            cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b),
            cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b),
            cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        )
        return (
            0.2104542553 * lms.0 + 0.7936177850 * lms.1 - 0.0040720468 * lms.2,
            1.9779984951 * lms.0 - 2.4285922050 * lms.1 + 0.4505937099 * lms.2,
            0.0259040371 * lms.0 + 0.7827717662 * lms.1 - 0.8086757660 * lms.2
        )
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
        var rgb = Self.linearRGB(l: l, c: c, h: h)
        if !Self.isInGamut(rgb) {
            rgb = Self.linearRGB(l: l, c: Self.maxChroma(l: l, h: h), h: h)
        }
        return (Self.encode(rgb.0), Self.encode(rgb.1), Self.encode(rgb.2))
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

    /// The most chroma sRGB can show at this lightness and hue, to within
    /// 0.4 / 2¹⁶: far finer than an 8-bit channel can show.
    static func maxChroma(l: Double, h: Double) -> Double {
        guard l > 0, l < 1 else { return 0 }
        var (low, high) = (0.0, 0.4)
        for _ in 0..<16 {
            let mid = (low + high) / 2
            if isInGamut(linearRGB(l: l, c: mid, h: h)) { low = mid } else { high = mid }
        }
        return low
    }

    private static func isInGamut(_ rgb: (Double, Double, Double)) -> Bool {
        let range = -0.0001...1.0001
        return range.contains(rgb.0) && range.contains(rgb.1) && range.contains(rgb.2)
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
