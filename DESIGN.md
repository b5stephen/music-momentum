# Design

The palette and visual language for the app and its website. The app's colours come from the asset catalog and the website's from `docs/styles.css`; this file explains them. When a change shifts the language described here, update this file in the same commit.

## Palette

| Name | Hex | Role |
|---|---|---|
| Coral | `#FF6640` | The accent. `AccentColor` in the asset catalog, the same sRGB `#FF6640` in light and dark, as on the website and in the designs. Keep it sRGB: Display P3 components with the same numbers render a redder, more saturated coral on an iPhone. |
| On-accent | `#1A0A05` | Text and glyphs on a solid coral fill. `OnAccent` in the asset catalog; the website's text on coral buttons. |
| Accent text | `#C43A12` light, `#FF6640` dark | Coral used as text on a plain background. `AccentText` in the asset catalog: coral itself is under 3:1 on white, so light mode darkens it. |
| Amber | `#FFB23E` | Taken from the app icon's orange. Website only so far. |
| Rose | `#FF4F8B` | Website only so far. |
| Violet | `#9C8CFF` | Website only so far; the website uses it for iCloud sync. |
| Ground | `#0D0A0F` | Website background, a near-black plum. The app uses the system backgrounds. |
| Surface / Raised | `#17121A` / `#231B24` | Website cards and raised panels. |
| Line | `#2E2530` | Website borders and dividers. |
| Text / Muted | `#F6EFEA` / `#B9ACB4` | Website body text and secondary text. |

On the website, each feature gets its own accent: coral for speed, amber for markers, rose for loops and violet for sync. Colour comes from solid blocks and accents, never from gradient washes.

## How the app uses colour

- **One tint.** Coral is the only accent in the app, applied through `.tint`. Amber, rose and violet belong to the website and marketing. Amber was tried for markers and read as out of place beside coral; before bringing one in, give it a job the tint can't do, and record that job here.
- **Coral means "on" or "act on this".** It marks the loop when it's running, a looping clip, the chip that prompts you to save, the speed you saved a song at, and the selected handle in the marker editor. Don't use it for decoration (icon tiles, nudge and cue buttons, a Mark button on every row), or it stops meaning anything. Play/pause is the primary colour, not coral.
- **Fill carries state; glyph carries kind.** A marker pill is idle in `.quaternary`, cued at `.tint` 12%, and looping in solid `.tint` with `OnAccent` text. A dot marks a point and `SpanGlyph` marks a clip, so the fill never has to explain what a marker is. The Mark button's `MarkGlyph` is that dot with a plus, so it reads as another of the pills beside it.
- **Only one state shouts.** Looping is the one solid-tint state. Cued keeps the primary text colour and only hints through its fill and glyph.
- **Chips and buttons:** a chip or button that prompts you to act, or a selected choice like the marker editor's Point/Clip switch, is `.tint` at 14% with `AccentText` text (drawn by hand: `.bordered` turns grey once its text is recoloured); a settled one is `.quaternary` with secondary text. There's no solid coral control apart from the loop: beside the tinted chips a solid fill reads as a different, brighter coral, and in light mode it outshouts every other screen. The system's solid confirm button is replaced by a plain toolbar button with a coral (`AccentColor`) tick, the bright coral a tinted toolbar button takes, which reads better on the glass than `AccentText`'s darker shade, so it takes the same toolbar glass as Close.
- **Solid coral is for graphics and looping only:** the speed arc, the clip on the marker timeline and its handles, the looping pill and the loop button.
- **Marker editor:** the clip and its handles are coral; the selected time sits in a `.tint` 16% panel with primary text rather than turning coral itself, so the big numerals stay legible in light mode. Its Playhead chip (a miniature of the strip's playhead glyph and the word) is the cell's colour with `AccentText`, so it stands off that panel. Nudge, cue, skip and play buttons are neutral, on `tertiarySystemFill`; back, play/pause and forward share one row in equal thirds, with the cue buttons beneath, each marked with the dot of the time it plays from. The playhead is a `.primary` line with a knob above the track, never coral, since it isn't part of the marker. When zoomed in, the track is drawn the length of the song and cut by the strip: rounded only at the song's real ends, and fading out at an edge with more to pan to. A playhead out of view becomes a small `.primary` arrow at the edge it's past. Below the track runs a ruler: `.secondary` marks at each labelled time, `.tertiary` minor marks between (tenths at the 5s zoom). While a handle or the playhead is dragged, its time shows in an inverted bubble (`label` fill, `systemBackground` text) above the strip, out from under the thumb; a handle snapped to the playhead adds "Playhead" to it, and a slowed drag (finger moved off the strip) adds its speed. Zoom is a neutral `.secondary` slider between magnifier glyphs, led by a `.quaternary` chip that names the span ("Whole song", "30s", "4.5s") and steps through Whole song, 30s and 5s when tapped.
- **Saved list:** markers are plain `.quaternary` pills and the Mark button is a grey circle with `MarkGlyph`, the practice screen's mark button in miniature. The speed pill is the only coral on a row. The song loaded in Practice carries a `.secondary` waveform after its title, animating while it plays. Sort is hidden, not disabled, while the list is empty: a greyed glyph beside Add read as a second, broken add button.
- **Round controls** (loop, mark) are 46pt circles: `.tint` fill with an `OnAccent` glyph when on, and `.quaternary` with a secondary glyph when off.
- **Scrubber:** the played part is `.tint` at 45%, clips are `.primary` at 25%, and a looping clip is solid `.tint`, ringed in the background colour so the played fill can't swallow it.
- **Speed wheel:** a flat `.quaternary` rim, no bevel or gradient, so it takes whatever foreground it sits on. On a bright cover it's smoked instead (see below).
- **Banners stay away from coral's hue.** Warnings are yellow. Errors sit on neutral grey with a coral icon. Banner text is always the primary label colour, so only the icon and background carry colour. Don't use orange or red near the accent; they read as the same colour. The same goes for inline warnings: a song gone from the library gets a yellow triangle and secondary text, not red text.

## Artwork colour on Practice

With a song loaded, the practice screen is painted in the cover's own colours, the way Apple Music's Now Playing is. `ArtworkPalette` averages the cover image, whole and in a 3×3 grid, and the screen draws those as a mesh gradient: the cover blurred into its colours. Library artwork's `musicKit://` URLs can't be fetched, so a library song is sampled from its catalog counterpart's cover. `Artwork.backgroundColor` stands in only while that loads, or when there's no cover to fetch, because it's a single colour and often the border: Count on Me's is cream where the cover is mostly gold.

The ground is tuned against Apple Music on the same iPhone, in OKLCH. The aim is Apple's colour and depth, not an exact match:

- **The average, led by the colourful pixels.** Picking the single strongest hue turned Weather With You's cover sky blue and Sunshine of Your Love's pink; a plain average let Count on Me's cream road turn its gold yellow-green. Lightness is averaged as the pixels are stored (gamma-encoded); hue and chroma are weighted by each pixel's chroma. A cover's warm and cool parts still cancel: Weather With You comes out grey, as Apple's does.
- **Bright and vivid.** Lightness drops by a step of 0.12, so a bright cover stays bright: Count on Me's gold sits at 0.78 against Apple's 0.77–0.82. Saturation goes up by a third relative to what sRGB allows. Pale and grey covers stop at 0.5, so light text still reads on them. Grey stays grey.
- **Yellows turn towards orange,** or darkening them reads as olive, and the bottom of the screen turns them further, as Apple's gold deepens to amber.
- **Nearly one colour.** Each mesh point keeps only a quarter of its region's own colour, and none is less colourful than the whole cover, so a cover's pale parts don't darken into grey patches.
- **Brightest behind the title and dial,** the mesh's middle row lifted a little, then darkening from a third of the way down towards a very dark shade of the cover's own colour: black greys it.
- **The mesh drifts while the song plays,** its inner points slowly wandering on unrelated periods, and holds still while it's paused or when Reduce Motion is on.
- **Light text always:** near-white tinted with the cover's hue. The screen is always in dark appearance, so every hierarchical style and `.quaternary` fill becomes the light text at low opacity, which reads as glass on any ground. Never fills of a dark text colour on a light ground: that's what made the first version look muddy.
- **Smoked glass on bright covers.** Where the ground is bright (Count on Me's gold), light glass washes out, so the chips and the speed wheel's rim take the ground's dark shadow colour at 24% instead. Darker grounds keep light glass.
- **"On"** (loop button, looping pill, speed arc, Play) is a solid fill of the text colour with a darker shade of the ground on top.
- **The selected tab** takes the text colour while Practice is showing, because coral vanishes on a red or orange cover.
- **The cover itself is shown,** so it's plain where the colours come from. On a phone it's a 64pt thumbnail beside the title and artist, the three centred as a group with the chips beneath. Wide, it heads the player column, up to 180pt and dropped when the height runs out, and the title stands alone over the dial. Drawing the cover into the ground, faded from the top as Apple Music does, was tried and dropped: no fade looked right across every cover.

Coral steps aside on this screen. Covers without colours, and the screen with nothing loaded, keep the system background and the coral tint. The first tuning was worked out on the Album Colour Study design canvas; the current one against Apple Music on a device.

## iPad, wide

A landscape window 1000pt or wider drops the tab bar: Practice becomes a card hovering over Saved, which runs the full width of the window behind it. Narrower or portrait windows keep the tabs.

- **The card is the phone layout,** 440pt wide by default (the widest iPhone), 28pt from the screen's top, bottom and leading edges, with 40pt corners, a hairline white edge and a deep shadow. With nothing loaded it's `secondarySystemGroupedBackground`, so it stands off the page in both appearances.
- **One page, not a split.** Saved sits on the plain system background up to the card, with no divider and no second background. The cover's centre colour glows on the page behind the card, blurred well past its edges: that, more than the shadow, makes it read as hovering.
- **Resizable.** A `.tertiary` grabber in the gap beside the card drags it between 375pt and 640pt, never leaving Saved under 480pt; a double tap restores 440pt. The width is per device. Past 640pt the card would flip into Practice's two-column layout.
- **Saved drops what the card already says:** no large title, and its empty state is the icon and one line, with no copy or button, since the card's own empty state offers Choose a Song.

## Type

- **App:** system type throughout. Use SF Pro Rounded, bold, for the speed readout, `.monospacedDigit()` for anything that ticks (times, percentages, clip lengths), and footnote medium for pills and chips. No custom fonts in the app.
- **Website:** Bricolage Grotesque (700/800) for headings, Instrument Sans for body text and JetBrains Mono for eyebrows, numbers and placeholders.

## Contrast

- Coral on black is about 7:1, so tinted text and icons on the dark background are fine.
- Coral on white is also only about 2.9:1, so coral *text* on a plain background uses `AccentText`, which darkens to about 5.3:1 in light mode. Fills keep the bright coral in both modes.
- White on coral is only about 2.9:1, under the 4.5:1 that small text needs. Text on a solid coral fill uses `OnAccent` (about 6.5:1 on the dark-mode coral), as the looping pill, the loop button when it's on, and the website's buttons do. On an artwork-coloured practice screen the same job falls to a darker shade of the ground. Don't put white on coral.
- Touch targets are at least 44pt.

## Website

The website is `docs/`: plain HTML with one shared `styles.css`, served by GitHub Pages. Its colours are CSS custom properties on `:root` at the top of that file. If the accent changes in the app, change `--coral` there too.
