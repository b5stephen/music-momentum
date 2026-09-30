//
//  ArtworkRepair.swift
//  MusicMomentum
//

import Foundation
import MusicKit
import SwiftData
import os

/// Swaps device-local library artwork for the catalog's, so a song saved
/// from one device's library shows its cover on the others. Whichever device
/// runs it first writes the catalog artwork, and sync carries it everywhere.
enum ArtworkRepair {
    private static let log = Logger(subsystem: "dev.etched.music-momentum", category: "ArtworkRepair")

    /// Returns one line per song and per bail-out, for the debug menu; every
    /// line is logged too.
    @discardableResult
    static func run(in context: ModelContext) async -> [String] {
        var report: [String] = []
        func note(_ line: String) {
            log.notice("\(line, privacy: .public)")
            report.append(line)
        }

        guard MusicAuthorization.currentStatus == .authorized else {
            note("Skipped: Apple Music access is \(MusicAuthorization.currentStatus)")
            return report
        }
        guard let all = try? context.fetch(FetchDescriptor<SavedSong>()) else {
            note("Skipped: couldn't fetch saved songs")
            return report
        }
        for song in all {
            let url = song.artwork?.url(width: 48, height: 48)?.absoluteString ?? "no artwork"
            note("\(song.title): catalog \(song.catalogID ?? "none"), \(url)")
        }
        let broken = all.filter { $0.catalogID != nil && !$0.hasPortableArtwork }
        guard !broken.isEmpty else {
            note("Nothing to repair")
            return report
        }

        let ids = Set(broken.compactMap(\.catalogID)).map { MusicItemID($0) }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: ids)
        let catalog: MusicItemCollection<Song>
        do {
            catalog = try await request.response().items
        } catch {
            note("Catalog request failed: \(error)")
            return report
        }

        for song in broken {
            guard let match = catalog.first(where: { $0.id.rawValue == song.catalogID }) else {
                note("Not in catalog: \(song.title)")
                continue
            }
            guard let artwork = match.artwork,
                  let data = try? JSONEncoder().encode(artwork)
            else {
                note("No catalog artwork: \(song.title)")
                continue
            }
            SavedSong.setArtwork(data, for: song, in: context)
            note("Repaired \(song.title): \(artwork.url(width: 48, height: 48)?.absoluteString ?? "no URL")")
        }
        return report
    }
}
