//
//  LibrarySidebarSection.swift
//  MusicMomentum
//

#if os(macOS)
import MusicKit
import SwiftUI

/// The top of the Mac sidebar: the song being practised, which brings
/// Practice back, then the library's pages, which take its place. Saved
/// follows underneath with its own header.
struct LibrarySidebarSection: View {
    let controller: PlaybackController
    /// Stands in for `controller.selectedSong` in previews.
    var previewTitle: String?
    @Binding var showsLibrary: Bool
    @Binding var page: LibraryPage

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            heading("Practising")
            practisingRow
            heading("Library")
                .padding(.top, 8)
            ForEach(LibraryPage.allCases) { item in
                SidebarItemRow(isSelected: showsLibrary && page == item) {
                    page = item
                    showsLibrary = true
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tint)
                        .frame(width: 22)
                    Text(item.title)
                        .font(.system(size: 13))
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
            .padding(.bottom, 3)
            .accessibilityAddTraits(.isHeader)
    }

    private var title: String? { controller.selectedSong?.title ?? previewTitle }

    private var subtitle: String? {
        if let song = controller.selectedSong { return song.artistName }
        return title == nil ? "No song loaded" : nil
    }

    private var practisingRow: some View {
        SidebarItemRow(isSelected: !showsLibrary) {
            showsLibrary = false
        } label: {
            Group {
                if let artwork = controller.selectedSong?.artwork {
                    ArtworkImage(artwork, width: 28, height: 28)
                } else {
                    Rectangle().fill(.quaternary)
                        .overlay {
                            Image(systemName: "guitars")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(.rect(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 0) {
                Text(title ?? "Practice")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if controller.selectedSong != nil {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, isActive: controller.isPlaying)
            }
        }
        .help("Back to Practice")
    }
}

/// Hover is the only fill a row gets unless it's the page on show, as with
/// Saved's rows.
private struct SidebarItemRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { label }
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    .primary.opacity(isSelected ? 0.14 : isHovered ? 0.07 : 0),
                    in: .rect(cornerRadius: 7)
                )
                .contentShape(.rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Library sidebar", traits: .fixedLayout(width: 272, height: 300)) {
    @Previewable @State var showsLibrary = true
    @Previewable @State var page = LibraryPage.albums
    LibrarySidebarSection(
        controller: PlaybackController(),
        previewTitle: "Slow Burn Avenue",
        showsLibrary: $showsLibrary,
        page: $page
    )
    .padding(.vertical)
}
#endif
