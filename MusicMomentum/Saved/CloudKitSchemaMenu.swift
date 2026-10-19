//
//  CloudKitSchemaMenu.swift
//  MusicMomentum
//

#if DEBUG
import SwiftUI

/// Debug-build toolbar menu for checking and uploading the CloudKit schema,
/// whose steps are in CLAUDE.md under "iCloud sync", and for `SampleSong`.
struct CloudKitSchemaMenu: View {
    @State private var running = false
    @State private var outcome: Outcome?
    @State private var sampleSongRelaunch = false
    @AppStorage(SampleSong.loadedKey) private var loadedSample = SampleSong.tracks[0].id

    private struct Outcome: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        Menu {
            Button("Validate CloudKit Schema", systemImage: "checkmark.icloud") { run(dryRun: true) }
            Button("Push CloudKit Schema (Dev)", systemImage: "icloud.and.arrow.up") { run(dryRun: false) }
            Section {
                Picker("Sample Song", systemImage: "music.note", selection: sampleSelection) {
                    Text("Your Library").tag("")
                    ForEach(SampleSong.tracks, id: \.id) { track in
                        Text(track.title).tag(track.id)
                    }
                }
                .pickerStyle(.menu)
            }
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
        .alert(SampleSong.isRequested ? "Use your library?" : "Use the sample songs?", isPresented: $sampleSongRelaunch) {
            Button("Quit") {
                SampleSong.setRequested(!SampleSong.isRequested)
                exit(0)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app quits to switch stores. Open it again from the Home Screen.")
        }
    }

    /// `""` is the library. Only going in or out of the samples relaunches.
    private var sampleSelection: Binding<String> {
        .init(
            get: { SampleSong.isRequested ? loadedSample : "" },
            set: { id in
                if !id.isEmpty { loadedSample = id }
                if id.isEmpty == SampleSong.isRequested { sampleSongRelaunch = true }
            }
        )
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
}
#endif
