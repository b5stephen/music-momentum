//
//  SavedListMenu.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Submenu items for toggling a song's membership across `PracticeList`s.
struct SavedListMenu: View {
    let song: SavedSong
    let lists: [PracticeList]
    let onNewList: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Menu {
            ForEach(lists) { list in
                let included = song.isInList(list)
                Button {
                    if included {
                        PracticeList.remove([song], from: list, in: modelContext)
                    } else {
                        PracticeList.add([song], to: list, in: modelContext)
                    }
                } label: {
                    if included {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        Text(list.name)
                    }
                }
            }
            if !lists.isEmpty { Divider() }
            Button {
                onNewList()
            } label: {
                Label("New List\u{2026}", systemImage: "plus")
            }
        } label: {
            Label("Add to List", systemImage: "folder.badge.plus")
        }
    }
}

#Preview("In one of two lists") {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let song = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    let acoustic = PracticeList.create(name: "Acoustic", in: context)
    let blues = PracticeList.create(name: "Blues", in: context)
    PracticeList.add([song], to: acoustic, in: context)

    return SavedListMenu(song: song, lists: [acoustic, blues]) {}
        .padding()
        .modelContainer(container)
}

#Preview("No lists") {
    let container = try! AppSchema.inMemoryContainer()
    let song = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: container.mainContext)

    return SavedListMenu(song: song, lists: []) {}
        .padding()
        .modelContainer(container)
}
