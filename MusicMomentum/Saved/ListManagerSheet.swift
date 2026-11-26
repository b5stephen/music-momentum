//
//  ListManagerSheet.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Reorder, rename, create, or delete `PracticeList`s on iPhone and iPad.
struct ListManagerSheet: View {
    @Binding var filter: ListFilter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PracticeList.sortOrder), SortDescriptor(\PracticeList.createdAt)])
    private var lists: [PracticeList]

    @State private var prompt: ListPrompt?

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("No lists yet", systemImage: "folder")
                    } description: {
                        Text("Create lists for lessons, levels, setlists, or technique tags.")
                    } actions: {
                        Button {
                            prompt = .create()
                        } label: {
                            Label("New List", systemImage: "plus")
                        }
                        .buttonStyle(CallToActionButtonStyle())
                    }
                } else {
                    List {
                        ForEach(lists) { list in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name)
                                        .font(.body)
                                    Text(songCountLabel(list.songCount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                filter = .lists(ids: [list.listID], match: filter.matchMode)
                                dismiss()
                            }
                            .contextMenu {
                                Button { prompt = .rename(list) } label: {
                                    Label("Rename\u{2026}", systemImage: "pencil")
                                }
                                Divider()
                                Button(role: .destructive) { prompt = .delete(list) } label: {
                                    Label("Delete List", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    prompt = .delete(list)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    prompt = .rename(list)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                            }
                        }
                        .onMove { source, destination in
                            var reordered = lists
                            reordered.move(fromOffsets: source, toOffset: destination)
                            PracticeList.reorder(reordered, in: modelContext)
                        }
                    }
                }
            }
            .navigationTitle("Manage Lists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(lists.isEmpty ? .inactive : .active))
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        prompt = .create()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("New List")
                }
            }
            .listPrompts($prompt)
        }
    }

    private func songCountLabel(_ count: Int) -> String {
        count == 1 ? "1 song" : "\(count) songs"
    }
}

#Preview("With lists") {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let l1 = PracticeList.create(name: "Level 1", in: context)
    let l2 = PracticeList.create(name: "Friday Gig", in: context)
    let song = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    PracticeList.add([song], to: l1, in: context)
    _ = l2

    return ListManagerSheet(filter: .constant(.all))
        .modelContainer(container)
}

#Preview("Empty") {
    ListManagerSheet(filter: .constant(.all))
        .modelContainer(try! AppSchema.inMemoryContainer())
}
