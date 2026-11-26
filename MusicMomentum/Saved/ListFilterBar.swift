//
//  ListFilterBar.swift
//  MusicMomentum
//
//  Created by Stephen Denekamp on 26/11/2026.
//

import SwiftData
import SwiftUI

/// Saved's scope on iPhone and iPad: one list at a time. Combining lists is
/// left to the Mac, where there's room to show what a combination means.
struct ListFilterBar: View {
    @Binding var filter: ListFilter
    let lists: [PracticeList]
    let unfiledCount: Int
    var isBesidePractice = false
    let onNewList: () -> Void
    let onRenameList: (PracticeList) -> Void
    let onAddSongsToList: (PracticeList) -> Void
    let onDeleteList: (PracticeList) -> Void

    @State private var clipped: (leading: Bool, trailing: Bool) = (false, false)

    /// Beside the card the strip is neither clipped nor faded: glass under
    /// any clipping layer, the scroll view's own or the fade's mask, frosts
    /// that whole layer, a grey rectangle behind the pills. Chips scrolled
    /// past an end slide under the card or off the window instead.
    /// `isBesidePractice` holds while the bar is up, so the branch never
    /// resets the scroll position.
    @ViewBuilder
    var body: some View {
        if isBesidePractice {
            strip.scrollClipDisabled()
        } else {
            strip.edgeFade(leading: clipped.leading, trailing: clipped.trailing, width: 28)
        }
    }

    private var strip: some View {
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
                        filter = filter.toggling(listID: list.listID, multiSelect: false)
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
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .chipSurface(isSelected: false, isBesidePractice: isBesidePractice)
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
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentText) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .chipSurface(isSelected: isSelected, isBesidePractice: isBesidePractice)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    /// Beside the card the chips are glass, as Practice's pills are, so they
    /// take on the cover's glow; a system fill there read as disabled.
    @ViewBuilder
    func chipSurface(isSelected: Bool, isBesidePractice: Bool) -> some View {
        if isBesidePractice {
            glassEffect(
                isSelected ? Glass.regular.tint(Color.accentColor.opacity(0.3)).interactive() : Glass.regular.interactive(),
                in: .capsule
            )
        } else if isSelected {
            background {
                Capsule()
                    .fill(Color.accentColor.opacity(0.16))
                    .overlay { Capsule().strokeBorder(Color.accentColor.opacity(0.32), lineWidth: 1) }
            }
        } else {
            background(Color.tertiarySystemFill, in: .capsule)
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

    return ListFilterBar(
        filter: .constant(.lists(ids: [l1.listID], match: .all)),
        lists: [l1, l2],
        unfiledCount: 2,
        onNewList: {},
        onRenameList: { _ in },
        onAddSongsToList: { _ in },
        onDeleteList: { _ in }
    )
    .padding()
    .modelContainer(container)
}
