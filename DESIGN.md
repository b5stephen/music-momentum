# Design

The palette and visual language for the app and its website. The app's colours come from the asset catalog and the website's from `docs/styles.css`; this file explains them. When a change shifts the language described here, update this file in the same commit.

## Palette

| Name | Hex | Role |
|---|---|---|
| Coral | `#FF6640` | The accent. `AccentColor` in the asset catalog, Display P3 `1.00 0.33 0.16` light and `1.00 0.40 0.24` dark (lighter so it doesn't go muddy on black). `#FF6640` is the sRGB stand-in the website uses. |
| On-accent | `#1A0A05` | Text and glyphs on a solid coral fill. `OnAccent` in the asset catalog; the website's text on coral buttons. |
| Amber | `#FFB23E` | Taken from the app icon's orange. Website only so far. |
| Rose | `#FF4F8B` | Website only so far. |
| Violet | `#9C8CFF` | Website only so far; the website uses it for iCloud sync. |
| Ground | `#0D0A0F` | Website background, a near-black plum. The app uses the system backgrounds. |
| Surface / Raised | `#17121A` / `#231B24` | Website cards and raised panels. |
| Line | `#2E2530` | Website borders and dividers. |
| Text / Muted | `#F6EFEA` / `#B9ACB4` | Website body text and secondary text. |

On the website, each feature gets its own accent: coral for speed, amber for markers, rose for loops and violet for sync. Colour comes from solid blocks and accents, never from gradient washes.

## How the app uses colour

- **One tint.** Coral is the only accent in the app, applied through `.tint`. Amber, rose and violet belong to the website and marketing. Before bringing one into the app, give it a job the tint can't do, and record that job here.
- **Coral means "on" or "act on this".** It marks the loop when it's running, a looping clip, the chip that prompts you to save, and play/pause. Don't use it for decoration, or it stops meaning anything.
- **Fill carries state; glyph carries kind.** A marker pill is idle in `.quaternary`, cued at `.tint` 12%, and looping in solid `.tint` with `OnAccent` text. A dot marks a point and `SpanGlyph` marks a clip, so the fill never has to explain what a marker is.
- **Only one state shouts.** Looping is the one solid-tint state. Cued keeps the primary text colour and only hints through its fill and glyph.
- **Chips:** a chip that prompts you to act is `.tint` at 14% with tinted text; a settled chip is `.quaternary` with secondary text.
- **Round controls** (loop, mark) are 46pt circles: `.tint` fill with an `OnAccent` glyph when on, and `.quaternary` with a secondary glyph when off.
- **Scrubber:** the played part is `.tint` at 45%, clips are `.primary` at 25%, and a looping clip is solid `.tint`, ringed in the background colour so the played fill can't swallow it.
- **Banners stay away from coral's hue.** Warnings are yellow. Errors sit on neutral grey with a coral icon. Banner text is always the primary label colour, so only the icon and background carry colour. Don't use orange or red near the accent; they read as the same colour.

## Type

- **App:** system type throughout. Use SF Pro Rounded, bold, for the speed readout, `.monospacedDigit()` for anything that ticks (times, percentages, clip lengths), and footnote medium for pills and chips. No custom fonts in the app.
- **Website:** Bricolage Grotesque (700/800) for headings, Instrument Sans for body text and JetBrains Mono for eyebrows, numbers and placeholders.

## Contrast

- Coral on black is about 7:1, so tinted text and icons on the dark background are fine.
- White on coral is only about 2.9:1, under the 4.5:1 that small text needs. Text on a solid coral fill uses `OnAccent` (about 6.5:1 on the dark-mode coral), as the looping pill, the loop button when it's on, the marker editor's selected Point/Clip switch and the website's buttons do. Don't put white on coral.
- Touch targets are at least 44pt.

## Website

The website is `docs/`: plain HTML with one shared `styles.css`, served by GitHub Pages. Its colours are CSS custom properties on `:root` at the top of that file. If the accent changes in the app, change `--coral` there too.
