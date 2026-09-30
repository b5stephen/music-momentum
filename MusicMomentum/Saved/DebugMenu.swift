//
//  DebugMenu.swift
//  MusicMomentum
//

#if DEBUG
import SwiftData
import SwiftUI

/// Debug-build toolbar menu. The CloudKit schema steps it belongs to are in
/// CLAUDE.md under "iCloud sync".
struct DebugMenu: View {
    @Environment(\.modelContext) private var modelContext
    @State private var running = false
    @State private var outcome: Outcome?

    private struct Outcome: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        Menu {
            Button("Validate CloudKit Schema", systemImage: "checkmark.icloud") { run(dryRun: true) }
            Button("Push CloudKit Schema (Dev)", systemImage: "icloud.and.arrow.up") { run(dryRun: false) }
            Button("Repair Artwork", systemImage: "photo.badge.checkmark") { repairArtwork() }
        } label: {
            if running {
                ProgressView()
            } else {
                Label("Debug", systemImage: "hammer")
            }
        }
        .disabled(running)
        .alert(item: $outcome) { outcome in
            Alert(title: Text(outcome.title), message: Text(outcome.message))
        }
    }

    private func run(dryRun: Bool) {
        running = true
        Task {
            do {
                let message = try await CloudKitSchemaInitializer.run(dryRun: dryRun)
                outcome = Outcome(title: dryRun ? "Schema valid" : "Schema pushed", message: message)
            } catch {
                outcome = Outcome(title: "Schema failed", message: String(describing: error))
            }
            running = false
        }
    }

    private func repairArtwork() {
        running = true
        Task {
            let report = await ArtworkRepair.run(in: modelContext)
            outcome = Outcome(title: "Artwork", message: report.joined(separator: "\n\n"))
            running = false
        }
    }
}
#endif
