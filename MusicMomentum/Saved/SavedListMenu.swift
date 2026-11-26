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
