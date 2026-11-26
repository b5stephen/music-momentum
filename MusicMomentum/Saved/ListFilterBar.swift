//
//  ListFilterBar.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Horizontal filter strip for Saved on iPhone and iPad, matching Practice's
/// quiet pill language while keeping coral reserved for the active filter.
struct ListFilterBar: View {
    @Binding var filter: ListFilter
    @Binding var multiSelect: Bool
    let lists: [PracticeList]
    let totalCount: Int
    let unfiledCount: Int
    var isBesidePractice = false
    let onNewList: () -> Void
    let onManageLists: () -> Void
    let onRenameList: (PracticeList) -> Void
    let onAddSongsToList: (PracticeList) -> Void
    let onDeleteList: (PracticeList) -> Void

    @State private var clipped: (leading: Bool, trailing: Bool) = (false, false)

    var body: some View {
        HStack(spacing: 8) {
            listsMenu

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(title: "All", isSelected: filter == .all) {
                        filter = .all
                    }

                    if unfiledCount > 0 || filter == .unfiled {
                        chip(title: "Unfiled", count: unfiledCount, isSelected: filter == .unfiled) {
                            filter = filter == .unfiled ? .all : .unfiled
                        }
                    }

                    ForEach(lists) { list in
                        chip(
                            title: list.name,
                            count: list.songCount,
                            isSelected: filter.contains(listID: list.listID)
                        ) {
                            filter = filter.toggling(listID: list.listID, multiSelect: multiSelect)
                        }
                        .contextMenu {
                            Button { onAddSongsToList(list) } label: {
                                Label("Add Songs\u{2026}", systemImage: "plus.circle")
                            }
                            Button { onRenameList(list) } label: {
                                Label("Rename\u{2026}", systemImage: "pencil")
                            }
                            Divider()
                            Button(role: .destructive) { onDeleteList(list) } label: {
                                Label("Delete List", systemImage: "trash")
                            }
                        }
                    }

                    Button(action: onNewList) {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background { idleBackground }
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New List")
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.x > -geometry.contentInsets.leading + 1
            } action: { _, isClipped in
                clipped.leading = isClipped
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.x + geometry.containerSize.width
                    < geometry.contentSize.width + geometry.contentInsets.trailing - 1
            } action: { _, isClipped in
                clipped.trailing = isClipped
            }
            .edgeFade(leading: clipped.leading, trailing: clipped.trailing, width: 28)
        }
    }

    private var listsMenu: some View {
        Menu {
            Button {
                filter = .all
            } label: {
                menuItemLabel("All Songs (\(totalCount))", selected: filter == .all)
            }

            if unfiledCount > 0 || filter == .unfiled {
                Button {
                    filter = .unfiled
                } label: {
                    menuItemLabel("Unfiled (\(unfiledCount))", selected: filter == .unfiled)
                }
            }

            if !lists.isEmpty {
                Divider()
                ForEach(lists) { list in
                    Button {
                        filter = filter.toggling(listID: list.listID, multiSelect: multiSelect)
                    } label: {
                        menuItemLabel("\(list.name) (\(list.songCount))", selected: filter.contains(listID: list.listID))
                    }
                }
            }

            Divider()

            Toggle("Combine Filters", isOn: $multiSelect)

            if filter.selectedListIDs.count > 1 {
                Picker("Match Mode", selection: Binding(
                    get: { filter.matchMode },
                    set: { filter = filter.withMatchMode($0) }
                )) {
                    ForEach(ListFilter.MatchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Divider()

            Button { onNewList() } label: {
                Label("New List\u{2026}", systemImage: "plus")
            }
            Button { onManageLists() } label: {
                Label("Manage Lists\u{2026}", systemImage: "list.bullet")
            }
        } label: {
            Image(systemName: multiSelect && filter.selectedListIDs.count > 1
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
                .font(.body)
                .foregroundStyle(filter.isActive ? Color.accentText : .secondary)
                .frame(width: 32, height: 32)
                .background { idleBackground }
        }
        .accessibilityLabel("Filter lists")
    }

    @ViewBuilder
    private func menuItemLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func chip(title: String, count: Int? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                if let count {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .opacity(0.65)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.16))
                        .overlay {
                            Capsule().strokeBorder(Color.accentColor.opacity(0.32), lineWidth: 1)
                        }
                } else {
                    idleBackground
                }
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var idleBackground: some View {
        if isBesidePractice {
            Capsule()
                .fill(.primary.opacity(0.08))
                .overlay { Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 1) }
        } else {
            Capsule().fill(Color.tertiarySystemFill)
        }
    }
}

#Preview("Filter bar") {
    let container = try! AppSchema.inMemoryContainer()
    let context = container.mainContext
    let l1 = PracticeList.create(name: "Level 1", in: context)
    let l2 = PracticeList.create(name: "Gig Setlist", in: context)
    let s1 = SavedSong.save(songID: "1", title: "Blackbird", artistName: "The Beatles", artworkData: nil, speed: 0.75, in: context)
    PracticeList.add([s1], to: l1, in: context)

    return VStack(spacing: 20) {
        ListFilterBar(
            filter: .constant(.lists(ids: [l1.listID], match: .all)),
            multiSelect: .constant(false),
            lists: [l1, l2],
            totalCount: 3,
            unfiledCount: 2,
            onNewList: {},
            onManageLists: {},
            onRenameList: { _ in },
            onAddSongsToList: { _ in },
            onDeleteList: { _ in }
        )
    }
    .padding()
    .modelContainer(container)
}
