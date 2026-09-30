//
//  AppSchema.swift
//  MusicMomentum
//

import SwiftData

/// The one list of stored models; the app, previews and tests all build
/// their containers from it.
nonisolated enum AppSchema {
    static let models: [any PersistentModel.Type] = [SavedSong.self, SongMarker.self]
    static let cloudKitContainer = "iCloud.dev.etched.music-momentum"

    static func appContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(cloudKitDatabase: .private(cloudKitContainer))
        )
    }

    /// Opts out of CloudKit explicitly: tests run inside the app, whose
    /// entitlements would otherwise switch sync on.
    static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }
}
