//
//  AssignListsSheet.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Assigns one or many selected `SavedSong`s to `PracticeList`s in one pass,
/// preserving mixed memberships unless toggled.
struct AssignListsSheet: View {
    let songs: [SavedSong]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\PracticeList.sortOrder), SortDescriptor(\PracticeList.createdAt)])
    private var lists: [PracticeList]

    /// Explicit overrides made in this sheet (`nil` = leave mixed state untouched).
    @State private var decisions: [String: Bool] = [:]
    @State private var prompt: ListPrompt?

    private enum MembershipState {
        case all, some, none
    }

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("No lists yet", systemImage: "folder")
                    } description: {
                        Text("Create a list to organize your saved songs.")
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
                            let state = membershipState(for: list)
                            Button {
                                let shouldAdd = state != .all
                                decisions[list.listID] = shouldAdd
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon(for: state))
                                        .foregroundStyle(state == .none ? Color.secondary : Color.accentText)
                                    Text(list.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(list.songCount)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        prompt = .create()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("New List")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        applyChanges()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel("Save")
                }
            }
            .listPrompts($prompt) { newList, _ in
                decisions[newList.listID] = true
            }
        }
    }

    private var title: String {
        songs.count == 1 ? "Lists for \(songs[0].title)" : "Add \(songs.count) Songs to Lists"
    }

    private func membershipState(for list: PracticeList) -> MembershipState {
        if let decision = decisions[list.listID] {
            return decision ? .all : .none
        }
        let matches = songs.filter { $0.isInList(list) }.count
        if matches == 0 { return .none }
        return matches == songs.count ? .all : .some
    }

    private func icon(for state: MembershipState) -> String {
        switch state {
        case .all: "checkmark.circle.fill"
        case .some: "minus.circle.fill"
        case .none: "circle"
        }
    }

    private func applyChanges() {
        for list in lists {
            guard let decision = decisions[list.listID] else { continue }
            if decision {
                PracticeList.add(songs, to: list, in: modelContext)
            } else {
                PracticeList.remove(songs, from: list, in: modelContext)
            }
        }
    }
}

#Preview("Assign lists") {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let l1 = PracticeList.create(name: "Level 1", in: context)
    _ = PracticeList.create(name: "Gig Set", in: context)
    let s1 = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    PracticeList.add([s1], to: l1, in: context)

    return AssignListsSheet(songs: [s1])
        .modelContainer(container)
}
