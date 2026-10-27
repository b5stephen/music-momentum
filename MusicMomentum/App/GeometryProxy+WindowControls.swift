//
//  GeometryProxy+WindowControls.swift
//  MusicMomentum
//

import SwiftUI

extension GeometryProxy {
    /// The area iPadOS's window controls take over this view's top-leading
    /// corner, or zero when there are none. `containerCornerInsets` also
    /// reports a window's rounded corner, so an inset no bigger than the
    /// corner's radius is only the corner: an iPhone Duo reports its 55pt
    /// screen corner there with no controls in it, and the floating card sat
    /// 35pt low and the header was indented in split screen. An iPad window's
    /// controls report 66×53 against a 22pt corner.
    nonisolated var windowControls: CGSize {
        #if os(macOS)
        // The traffic lights sit in the title bar, above the content.
        return .zero
        #else
        let inset = containerCornerInsets.topLeading
        if #available(iOS 27.0, *), let radius = concentricCornerRadii?.topLeading,
           inset.width <= radius, inset.height <= radius {
            return .zero
        }
        return inset
        #endif
    }
}
