//
//  MarkerContextMenu.swift
//  MusicMomentum
//

#if os(macOS)
import AppKit

/// A native menu with a shortcut hint down the right of each row, which
/// SwiftUI's `contextMenu` can't draw for a gesture like "Double-click".
/// Popped up by hand, since SwiftUI has no right-click event to hang one on.
@MainActor
enum MarkerContextMenu {
    enum Entry {
        case item(_ title: String, hint: String? = nil, isEnabled: Bool = true, action: () -> Void)
        case separator
    }

    private static let width: CGFloat = 236

    static func popUp(_ entries: [Entry], with event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.minimumWidth = width
        // Held until the menu closes, which is when `popUpContextMenu` returns.
        let target = Target()
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())
            case .item(let title, let hint, let isEnabled, let action):
                let item = NSMenuItem(title: title, action: #selector(Target.fire(_:)), keyEquivalent: "")
                item.target = target
                item.tag = target.handlers.count
                item.isEnabled = isEnabled
                target.handlers.append(action)
                if let hint { item.attributedTitle = attributedTitle(title, hint: hint) }
                menu.addItem(item)
            }
        }
        guard let view = event.window?.contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    /// The hint right-aligned to a tab stop, in secondary text.
    private static func attributedTitle(_ title: String, hint: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: width - 16)]
        let text = NSMutableAttributedString(
            string: "\(title)\t\(hint)",
            attributes: [.font: NSFont.menuFont(ofSize: 0), .paragraphStyle: style]
        )
        text.addAttribute(
            .foregroundColor,
            value: NSColor.secondaryLabelColor,
            range: NSRange(location: title.utf16.count + 1, length: hint.utf16.count)
        )
        return text
    }

    private final class Target: NSObject {
        var handlers: [() -> Void] = []

        @objc func fire(_ item: NSMenuItem) {
            handlers[item.tag]()
        }
    }
}
#endif
