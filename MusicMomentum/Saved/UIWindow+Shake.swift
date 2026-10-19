//
//  UIWindow+Shake.swift
//  MusicMomentum
//

#if DEBUG
import SwiftUI
import UIKit

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

/// SwiftUI has no shake gesture; the window is where an unhandled shake ends
/// up. In the simulator it's Device ▸ Shake, ⌃⌘Z, or with no Simulator window
/// `xcrun simctl spawn booted notifyutil -p com.apple.UIKit.SimulatorShake`.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in action() }
    }
}
#endif
