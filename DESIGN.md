# Design

The palette and visual language for the app and its website. The app's colours come from the asset catalog and the website's from `docs/styles.css`; this file explains them. Exact sizes and per-screen details live in the code.

## Palette

| Name | Hex | Role |
|---|---|---|
| Coral | `#FF6640` | The accent. `AccentColor` in the asset catalog, the same sRGB `#FF6640` in light and dark, as on the website. Keep it sRGB: Display P3 components with the same numbers render a redder coral on an iPhone. |
| On-accent | `#1A0A05` | Text and glyphs on a solid coral fill. `OnAccent` in the asset catalog. |
| Accent text | `#C43A12` light, `#FF6640` dark | Coral used as text on a plain background. `AccentText` in the asset catalog. |
| Amber | `#FFB23E` | Website only. |
| Rose | `#FF4F8B` | Website only. |
| Violet | `#9C8CFF` | Website only. |
| Ground | `#0D0A0F` | Website background, a near-black plum. The app uses the system backgrounds. |
| Surface / Raised | `#17121A` / `#231B24` | Website cards and raised panels. |
| Line | `#2E2530` | Website borders and dividers. |
| Text / Muted | `#F6EFEA` / `#B9ACB4` | Website body text and secondary text. |

On the website, each feature gets its own accent: coral for speed, amber for markers, rose for loops and violet for sync. Colour comes from solid blocks and accents, never gradient washes.

## Principles

- **One tint.** Coral is the app's only accent. Amber, rose and violet stay on the website; bring one into the app only for a job the tint can't do.
- **Coral means "on" or "act on this".** The running loop, a looping clip, a prompt to save, the speed you saved. Never decoration, or it stops meaning anything. Play/pause is the primary colour.
- **Only one state shouts.** Solid coral is for looping and for graphics (the speed knob's lit scale, the looping clip on the timeline). Everything else that's coral is a tint: `.tint` at 12–16% with `AccentText`. Settled things are `.quaternary` with secondary text.
- **Fill carries state; glyph carries kind.** A dot is a point and `SpanGlyph` is a clip; the fill says whether it's idle, cued or looping. On Saved, idle pills are a one-pixel `.quaternary` hairline with no fill: a grey pill under every song outweighed the titles.
- **Neutral controls stay neutral.** Nudge, cue, skip and the like use system fills, not coral. Toolbar glyphs that act on the screen (Saved's add and sort, a sheet's save tick) are `AccentColor` on the toolbar's own glass.
- **Banners stay away from coral's hue.** Warnings are yellow; errors are neutral grey with a coral icon. No orange or red near the accent; they read as the same colour.
- **Give text in buttons a concrete colour.** A hierarchical style like `.secondary` resolves against the button's tint and comes out a faded coral. `.bordered` turns grey once its text is recoloured, so tinted chips are drawn by hand.

## Artwork colour

With a song loaded, Practice is painted in the cover's own colours, the way Apple Music's Now Playing is: the cover blurred into a mesh gradient, darkened, always with light text. Coral steps aside there, since it vanishes on a red or orange cover; "on" becomes a solid fill of the text colour. Covers without colours, and the screen with nothing loaded, keep the system background and coral. How the colours are tuned is recorded in `ArtworkPalette`.

## Wide iPad

A landscape window with room for Saved beside the narrowest card drops the tab bar: Practice becomes a resizable card hovering over Saved, which runs the full width of the window behind it. It's one page, not a split: no divider, and the cover's colour glows on the page around the card. Saved drops what the card already says: no large title, and a minimal empty state.

Saved's speed and marker chips are clear Liquid Glass with primary text and no coral, on the phone as well as here, so beside the card they take on the glow instead of clashing with it.

Practice's save and change-song buttons are glass too, so they take on the cover like the knob does. The save prompt is the same glass tinted, never a solid fill.

## Type

- **App:** system type. SF Pro Rounded bold for the speed readout, `.monospacedDigit()` for anything that ticks, footnote medium for pills and chips. No custom fonts.
- **Website:** Bricolage Grotesque (700/800) for headings, Instrument Sans for body text, JetBrains Mono for eyebrows, numbers and placeholders.

## Contrast

- Coral is about 7:1 on black but 2.9:1 on white, so coral *text* uses `AccentText`, which darkens to about 5.3:1 in light mode. Fills keep the bright coral.
- White on coral is 2.9:1, too faint for small text. Text on solid coral uses `OnAccent` (about 6.5:1). On an artwork-coloured screen the same job falls to a darker shade of the ground.
- Touch targets are at least 44pt.

## Tried and dropped

- **Amber for markers:** read as out of place beside coral.
- **A solid coral confirm button:** beside tinted chips it read as a different, brighter coral. Sheets use a plain toolbar tick in `AccentColor` instead.
- **The cover drawn into Practice's background,** faded from the top: no fade looked right across every cover.
- **The single colour MusicKit ships with artwork** as the ground: it's often the cover's border, not its average.
- **Coral or grey chips beside the floating card:** coral clashed with the cover; grey read as disabled. Hence glass.
- **Highlighting the loaded song in Saved** with a panel, coral or the cover's colour.
- **A Mark pill pinned to the end of Practice's clip row:** it took a pill's width, leaving room for two and a half clips on a phone. Mark is a link on the caption line under the row instead.
- **The save and change-song chips beside a short window's wheel,** with a one-line title above, to give the wheel the header's height: mocked up, they didn't sit right beside the dial.
- **Mark in the compact header beside Change song:** the top corner is the hardest reach for a thumb, and Mark is pressed on the beat, mid-song. Compact puts it at the end of the clip row instead.
- **A speed wheel that spun past its limits,** with an arc around the rim reporting the value and a plate, teeth and hub in three greys: the greys muddied each other on a dark cover, and the saved speed appeared nowhere on it. It's an amp knob now: it points at the speed and stops dead at each end.
- **Grey save and change-song chips under the title:** they read as disabled, and "Saved at 70%" repeated the number the knob shows. The saved speed is a dot on the knob's scale instead.
- **A save prompt that pushed the title aside** reflowed it mid-drag, and **one floating over the title** smeared the letters through its glass. The title keeps room for two circles and fades out under the prompt.
- **Markers drawn on the timeline's track:** a clip at track height read as buffering, and a looping one needed a halo to survive the played fill. They have a lane of their own above it.
- **⏮ for restart:** a triangle-and-bar beside the skip buttons' circular arrows looked like a different set, and reads as "previous track". Restart uses `gobackward`, the skip arrow without a number.

## Website

The website is `docs/`: plain HTML with one shared `styles.css`, served by GitHub Pages. Its colours are CSS custom properties on `:root` at the top of that file. If the accent changes in the app, change `--coral` there too.
