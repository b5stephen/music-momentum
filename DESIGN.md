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
- **Fill carries state; glyph carries kind.** A marker pill is idle in `.quaternary`, cued at `.tint` 12%, and looping in solid `.tint` with `OnAccent` text. A dot marks a point and `SpanGlyph` marks a clip, so the fill never has to explain what a marker is.
- **Only one state shouts.** Looping is the one solid-tint state. Cued keeps the primary text colour and only hints through its fill and glyph.
- **Chips and buttons:** a chip or button that prompts you to act, or a selected choice like the marker editor's Point/Clip switch, is `.tint` at 14% with `AccentText` text (drawn by hand: `.bordered` turns grey once its text is recoloured); a settled one is `.quaternary` with secondary text. There's no solid coral control apart from the loop: beside the tinted chips a solid fill reads as a different, brighter coral, and in light mode it outshouts every other screen. The system's solid confirm button is swapped for `.glass` with an `AccentText` tick.
- **Solid coral is for graphics and looping only:** the speed arc, the clip on the marker timeline and its handles, the looping pill and the loop button.
- **Marker editor:** the clip and its handles are coral; the selected time sits in a `.tint` 16% panel with primary text rather than turning coral itself, so the big numerals stay legible in light mode. Its Now chip is the cell's colour with `AccentText`, so it stands off that panel. Nudge, cue and play buttons are neutral, on `tertiarySystemFill`.
- **Saved list:** markers are plain `.quaternary` pills and the Mark button is a grey circle with `MarkGlyph`, the practice screen's mark button in miniature. The speed pill is the only coral on a row.
- **Round controls** (loop, mark) are 46pt circles: `.tint` fill with an `OnAccent` glyph when on, and `.quaternary` with a secondary glyph when off.
- **Scrubber:** the played part is `.tint` at 45%, clips are `.primary` at 25%, and a looping clip is solid `.tint`, ringed in the background colour so the played fill can't swallow it.
- **Speed wheel:** a flat `.quaternary` rim, no bevel or gradient, so it takes whatever foreground it sits on.
- **Banners stay away from coral's hue.** Warnings are yellow. Errors sit on neutral grey with a coral icon. Banner text is always the primary label colour, so only the icon and background carry colour. Don't use orange or red near the accent; they read as the same colour. The same goes for inline warnings: a song gone from the library gets a yellow triangle and secondary text, not red text.

## Artwork colour on Practice

With a song loaded, the practice screen is painted in the cover's own colours, the way Apple Music's Now Playing is. `ArtworkPalette` samples the cover image for its dominant colour: the hue covering the most of it, weighted by saturation, so a vivid subject beats a pale border. `Artwork.backgroundColor` stands in only while the image loads, or when it can't be fetched (library artwork's `musicKit://` URLs), because it's often the border: Count on Me's is cream, which can only darken to olive.

The ground is derived in OKLCH, not used as sampled:

- **Always dark enough for light text, except where a hue is only rich when light.** Vivid colours keep their lightness up to just under their sRGB cusp, so a gold cover stays bright gold while reds and blues sit around 0.45–0.6. Muted covers go no lighter than 0.46. Grey stays grey.
- **Saturation is kept relative to what sRGB allows**, so a vivid cover stays vivid as it darkens and a muted one stays muted.
- **A vertical gradient darker towards the bottom**, the one gradient in the app. Yellows and oranges warm towards orange as they darken; darkening at the same hue turns them olive.
- **Light text always:** near-white tinted with the cover's hue. The screen is always in dark appearance, so every hierarchical style and `.quaternary` fill becomes the light text at low opacity, which reads as glass on any ground. Never fills of a dark text colour on a light ground: that's what made the first version look muddy.
- **"On"** (loop button, looping pill, speed arc, Play) is a solid fill of the text colour with the ground's midpoint on top.
- **The selected tab** takes the text colour while Practice is showing, because coral vanishes on a red or orange cover.

Coral steps aside on this screen. Covers without colours, and the screen with nothing loaded, keep the system background and the coral tint. The tuning was worked out on the Album Colour Study design canvas against Apple Music screenshots.

## Type

- **App:** system type throughout. Use SF Pro Rounded, bold, for the speed readout, `.monospacedDigit()` for anything that ticks (times, percentages, clip lengths), and footnote medium for pills and chips. No custom fonts in the app.
- **Website:** Bricolage Grotesque (700/800) for headings, Instrument Sans for body text and JetBrains Mono for eyebrows, numbers and placeholders.

## Contrast

- Coral on black is about 7:1, so tinted text and icons on the dark background are fine.
- Coral on white is also only about 2.9:1, so coral *text* on a plain background uses `AccentText`, which darkens to about 5.3:1 in light mode. Fills keep the bright coral in both modes.
- White on coral is only about 2.9:1, under the 4.5:1 that small text needs. Text on a solid coral fill uses `OnAccent` (about 6.5:1 on the dark-mode coral), as the looping pill, the loop button when it's on, and the website's buttons do. On an artwork-coloured practice screen the same job falls to the ground's midpoint. Don't put white on coral.
- Touch targets are at least 44pt.

## Website

The website is `docs/`: plain HTML with one shared `styles.css`, served by GitHub Pages. Its colours are CSS custom properties on `:root` at the top of that file. If the accent changes in the app, change `--coral` there too.
