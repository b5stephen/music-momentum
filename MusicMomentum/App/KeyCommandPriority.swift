//
//  KeyCommandPriority.swift
//  MusicMomentum
//

#if os(iOS)
import UIKit

/// UIKit gives a scroll view and keyboard focus the arrow keys and Space
/// ahead of the menu, so on an iPad ↑ scrolled Practice instead of speeding
/// up. SwiftUI has no say in that, so once the menu is built its bare and
/// ⌥ arrow and Space commands are marked to go first. A text field still gets
/// its keys: UIKit offers typing to the field before any key command.
final class KeyCommandPriority: UIResponder, UIApplicationDelegate {
    private static let inputs: Set<String> = [
        UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow,
        UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow, " ",
    ]

    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        Self.prioritise(builder.menu(for: .root)?.children ?? [])
    }

    private static func prioritise(_ elements: [UIMenuElement]) {
        for element in elements {
            if let menu = element as? UIMenu {
                prioritise(menu.children)
            } else if let command = element as? UIKeyCommand,
                      command.modifierFlags.isDisjoint(with: [.command, .control]),
                      let input = command.input, inputs.contains(input) {
                command.wantsPriorityOverSystemBehavior = true
            }
        }
    }
}
#endif
