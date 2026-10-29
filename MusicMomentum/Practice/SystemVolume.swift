//
//  SystemVolume.swift
//  MusicMomentum
//

#if os(macOS)
import AudioToolbox
import CoreAudio
import Observation

/// The Mac's output volume, the level the volume keys set. MusicKit has no
/// volume of its own and the Mac has no `MPVolumeView`, so this reads and
/// writes the default output device directly, following it when the user
/// switches to headphones or a display.
@MainActor
@Observable
final class SystemVolume {
    private(set) var level: Float = 0
    /// HDMI and some USB outputs have no software volume; the hardware owns it.
    private(set) var isSettable = false

    @ObservationIgnored private var device = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var deviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var volumeListener: AudioObjectPropertyListenerBlock?

    init() {
        let deviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.follow(Self.defaultDevice()) }
        }
        var address = Self.defaultDeviceAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        self.deviceListener = deviceListener
        follow(Self.defaultDevice())
    }

    isolated deinit {
        stopListening()
        if let deviceListener {
            var address = Self.defaultDeviceAddress
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, deviceListener)
        }
    }

    func set(_ level: Float) {
        guard isSettable else { return }
        var value = Float32(min(max(level, 0), 1))
        var address = Self.volumeAddress
        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value
        )
        if status == noErr { self.level = value }
    }

    private func follow(_ newDevice: AudioObjectID) {
        guard newDevice != device else { return }
        stopListening()
        device = newDevice
        var address = Self.volumeAddress
        var settable: DarwinBoolean = false
        isSettable = AudioObjectHasProperty(device, &address)
            && AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
        refresh()
        guard AudioObjectHasProperty(device, &address) else { return }
        let volumeListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        AudioObjectAddPropertyListenerBlock(device, &address, .main, volumeListener)
        self.volumeListener = volumeListener
    }

    private func stopListening() {
        guard let volumeListener else { return }
        var address = Self.volumeAddress
        AudioObjectRemovePropertyListenerBlock(device, &address, .main, volumeListener)
        self.volumeListener = nil
    }

    private func refresh() {
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = Self.volumeAddress
        if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
            level = value
        }
    }

    private static func defaultDevice() -> AudioObjectID {
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = defaultDeviceAddress
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return device
    }

    private static var defaultDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    /// The volume System Settings shows: one level across every channel.
    private static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
#endif
