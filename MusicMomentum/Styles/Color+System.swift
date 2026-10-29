//
//  Color+System.swift
//  MusicMomentum
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// UIKit's semantic colours, which AppKit names differently or not at all.
extension Color {
    #if canImport(UIKit)
    static var systemBackground: Color { Color(uiColor: .systemBackground) }
    static var secondarySystemGroupedBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var label: Color { Color(uiColor: .label) }
    static var tertiaryLabel: Color { Color(uiColor: .tertiaryLabel) }
    static var tertiarySystemFill: Color { Color(uiColor: .tertiarySystemFill) }
    #else
    static var systemBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var secondarySystemGroupedBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var label: Color { Color(nsColor: .labelColor) }
    static var tertiaryLabel: Color { Color(nsColor: .tertiaryLabelColor) }
    static var tertiarySystemFill: Color { Color(nsColor: .tertiarySystemFill) }
    #endif
}
