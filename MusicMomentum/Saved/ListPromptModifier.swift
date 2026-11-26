//
//  ListPromptModifier.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Presents native New List, Rename List, and Delete List alerts against a
/// shared `ListPrompt?` binding so every screen enforces the same rules.
struct ListPromptModifier: ViewModifier {
    @Binding var prompt: ListPrompt?
    var onCreate: ((PracticeList, _ hadInitialSongs: Bool) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert(
                "New List",
                isPresented: isCreating
            ) {
                TextField("List name", text: $name)
                Button("Create") {
                    let list = PracticeList.create(name: name, in: modelContext)
                    var hadInitialSongs = false
                    if case let .create(songs) = prompt, !songs.isEmpty {
                        PracticeList.add(songs, to: list, in: modelContext)
                        hadInitialSongs = true
                    }
                    prompt = nil
                    onCreate?(list, hadInitialSongs)
                }
                Button("Cancel", role: .cancel) { prompt = nil }
            } message: {
                Text("Organize saved songs into lessons, setlists, or tags.")
            }
            .alert(
                "Rename List",
                isPresented: isRenaming
            ) {
                TextField("List name", text: $name)
                Button("Save") {
                    if case let .rename(list) = prompt {
                        PracticeList.rename(list, to: name, in: modelContext)
                    }
                    prompt = nil
                }
                Button("Cancel", role: .cancel) { prompt = nil }
            }
            .alert(
                deleteTitle,
                isPresented: isDeleting
            ) {
                Button("Delete List", role: .destructive) {
                    if case let .delete(list) = prompt {
                        PracticeList.delete(list, in: modelContext)
                    }
                    prompt = nil
                }
                Button("Cancel", role: .cancel) { prompt = nil }
            } message: {
                Text("Your saved songs, speeds, and markers will stay in Saved.")
            }
            .onChange(of: prompt?.id) { _, _ in
                switch prompt {
                case .create: name = ""
                case let .rename(list): name = list.name
                case .delete, nil: break
                }
            }
    }

    private var isCreating: Binding<Bool> {
        Binding(
            get: { if case .create = prompt { true } else { false } },
            set: { if !$0 { prompt = nil } }
        )
    }

    private var isRenaming: Binding<Bool> {
        Binding(
            get: { if case .rename = prompt { true } else { false } },
            set: { if !$0 { prompt = nil } }
        )
    }

    private var isDeleting: Binding<Bool> {
        Binding(
            get: { if case .delete = prompt { true } else { false } },
            set: { if !$0 { prompt = nil } }
        )
    }

    private var deleteTitle: String {
        guard case let .delete(list) = prompt else { return "Delete List?" }
        return "Delete \u{201C}\(list.name)\u{201D}?"
    }
}

extension View {
    func listPrompts(
        _ prompt: Binding<ListPrompt?>,
        onCreate: ((PracticeList, _ hadInitialSongs: Bool) -> Void)? = nil
    ) -> some View {
        modifier(ListPromptModifier(prompt: prompt, onCreate: onCreate))
    }
}
