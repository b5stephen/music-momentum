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
- **Coral means "on" or "act on this".** The running loop, a looping clip, the speed you saved. Never decoration, or it stops meaning anything. Play/pause is the primary colour.
- **Only one state shouts.** Solid coral is for looping and for graphics (the speed knob's lit scale, the looping clip on the timeline). Everything else that's coral is a tint: `.tint` at 12–16% with `AccentText`. Settled things are `.quaternary` with secondary text.
- **Fill carries state; glyph carries kind.** A dot is a point and a short bar (`SpanGlyph`) is a clip, as they're drawn in the timeline's marker lane; the fill says whether it's idle or looping. On Practice, idle pills are glass like its other buttons: grey beside the glass Change Song and Mark read as a different, disabled kind of control. On Saved, idle pills are a one-pixel `.quaternary` hairline with no fill: a grey pill under every song outweighed the titles.
- **Neutral controls stay neutral.** Nudge, cue, skip, the volume slider and the like use system fills, not coral. Toolbar glyphs that act on the screen (Saved's add and sort, a sheet's save tick) are `AccentColor` on the toolbar's own glass.
- **Banners stay away from coral's hue.** Warnings are yellow; errors are neutral grey with a coral icon. No orange or red near the accent; they read as the same colour.
- **Give text in buttons a concrete colour.** A hierarchical style like `.secondary` resolves against the button's tint and comes out a faded coral. `.bordered` turns grey once its text is recoloured, so tinted chips are drawn by hand.

## Artwork colour

With a song loaded, Practice is painted in the cover's own colours, the way Apple Music's Now Playing is: the cover blurred into a mesh gradient, darkened, always with light text. Coral steps aside there, since it vanishes on a red or orange cover; "on" becomes a solid fill of the text colour. Covers without colours, and the screen with nothing loaded, keep the system background and coral. How the colours are tuned is recorded in `ArtworkPalette`.

## Wide iPad

A landscape window with room for Saved beside the narrowest card, and tall enough for the phone layout in the card, drops the tab bar: Practice becomes a resizable card hovering over Saved, which runs the full width of the window behind it. It's one page, not a split: no divider, and the cover's colour glows on the page around the card. Saved drops what the card already says: no large title, and a minimal empty state.

Saved's speed and marker chips are clear Liquid Glass with primary text and no coral, on the phone as well as here, so beside the card they take on the glow instead of clashing with it.

Practice's save, change-song and Mark buttons and its clip pills are glass too, so they take on the cover like the knob does. Mark was bare text on the caption line until people didn't see it as a button. The save prompt is the same glass in the same colour as Change Song: tinted coral beside it, the pair read as two unrelated controls. The prompt is only there while there's a speed to save; once it's saved, the dot on the knob's scale says so. Mark, on its own line at the bottom, is the same 44pt capsule as the prompt, so glass on Practice means one thing at one size.

## Mac

The Mac window is the iPad's wide layout turned into a window rather than a new app. The cover's mesh fills the whole window, title bar and sidebar included, so loading a song re-tints everything; covers without colours and the empty state keep the system look and coral. Saved is the sidebar: translucent over the mesh, with a pill search field, a small "Saved" header carrying Sort and Add as bare glyphs, and 36pt rows with the saved speed as quiet trailing text. The loaded song gets a speaker glyph, not a highlight, for the same reason as on iOS. Hover is the only fill a row ever gets.

The toolbar has no title, since Practice's song title is the title. Change Song is a labelled glass capsule ("change" and "add" are different actions, so the label stays), the mini player is a glass icon at the trailing end, and the sidebar toggle joins them when the sidebar is collapsed. Below about 1180pt the sidebar slides over Practice with a 32% dim instead of squeezing it; the dim closes it.

A Mac sheet says what it will do: "Choose Song" with Open from Change Song, "Add Song to Saved" with Add from the sidebar's +. A click picks a row (a quiet fill, not the accent), Return or a double-click confirms. Browse stays above "Practising lately", as on iOS.

## Volume

Practice's volume is the system's, the level the side buttons set: Apple's own `MPVolumeView` under the transport in every layout, its native slider and thumb, tinted the text colour, not coral, since volume isn't a state; the transport sits midway between it and the scrubber, so the two bars frame it as a pair. Stacked, it's the first thing to go when the screen runs short of height, before the controls shrink: the side buttons do the same job, and the clips don't.

Wide, the cover sits beside the title as it does stacked, the pair centred over the wheel with the save prompt and Change Song centred on a row of their own under it: in a column that narrow, the prompt growing over the title left only its first word. The playback column holds nothing but playback, and spreads, within limits, to run from the header's top to the wheel's foot, but never closer than 16pt to the top of a landscape phone or its tab bar. Held short by the tab bar, it still starts level with the header and stops short at the bottom; only when that leaves too little room for its rows is it centred on the wheel's column instead. It sits on a glass panel, so the screen is two objects, the knob and the panel, under the title; bare, its rows floated apart and the volume thumb was the heaviest thing on screen. Inside the panel, pills and Mark are a flat fill and a hairline rather than glass on glass. The transport is held to 360pt there: spread across the column, its buttons were 190pt apart and read as a toolbar.

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
- **The floating card on a landscape iPhone Air or Pro Max,** which are just wide enough for Saved beside it: the card was under 400pt tall and Practice scrolled. A phone on its side keeps the tabs and Practice's two-column layout.
- **Highlighting the loaded song in Saved** with a panel, coral or the cover's colour.
- **A Mark pill pinned to the end of Practice's clip row:** it took a pill's width, leaving room for two and a half clips on a phone. Mark is a link on the caption line under the row instead.
- **The save and change-song chips beside a short window's wheel,** with a one-line title above, to give the wheel the header's height: mocked up, they didn't sit right beside the dial.
- **Mark in the compact header beside Change song:** the top corner is the hardest reach for a thumb, and Mark is pressed on the beat, mid-song. Compact puts it at the end of the clip row instead.
- **A speed wheel that spun past its limits,** with an arc around the rim reporting the value and a plate, teeth and hub in three greys: the greys muddied each other on a dark cover, and the saved speed appeared nowhere on it. It's an amp knob now: it points at the speed and stops dead at each end.
- **A glass "↺ 80%" chip in the speed knob's bottom gap** to lead back to the saved speed: it read as a control hanging off the knob, and on the small knob, whose ring is shallower than the chip, its glass merged into the skirt's rim. The way back is a bare ↺ under the readout instead; the saved dot already says where it goes.
- **Grey save and change-song chips under the title:** they read as disabled, and "Saved at 70%" repeated the number the knob shows. The saved speed is a dot on the knob's scale instead.
- **A coral-tinted save prompt** on glass tinted to match: beside the neutral Change Song it looked like the two buttons came from different screens.
- **A glass bookmark once the speed was saved:** beside Change Song it looked just as tappable, though tapping it did nothing.
- **A bare bookmark once the speed was saved:** beside the glass Change Song it looked like a button that had lost its glass, and the knob's saved dot already said the same thing.
- **A save prompt that pushed the title aside** reflowed it mid-drag, and **one floating over the title** smeared the letters through its glass. The title keeps room for Change Song and fades out under the prompt.
- **Markers drawn on the timeline's track:** a clip at track height read as buffering, and a looping one needed a halo to survive the played fill. They have a lane of their own above it.
- **A playhead line through the marker lane and the track:** on a song without markers it sat high above the track and the bar looked off-centre, and a short tick centred on the track read as a notch; on a song with them it was one more line across the timeline that the end of the fill already says. The end of the fill marks the position.
- **A ⊢ bracket for clips:** it read as a span, but nothing on the timeline looked like it once clips were drawn there as bars. The pills and the lane now use the same shapes.
- **Practice's stack centred on the screen:** the cover's distance from the top changed with every screen height, and slid about 50pt while a floating card was dragged wider. **Pinning the title and the controls to the edges and giving all spare height to the gap under the title** left a tall card lopsided. **Holding the controls to the bottom edge too** made an iPhone Air look bottom-heavy. The title holds the top; spare height is shared above the wheel, below it and under the controls; and only a screen taller than a phone centres the stack.
- **Moving Practice's cover in to 32pt** so its corner would be concentric with the floating card's left a short title wrapping on a 375pt screen. It's 24pt in with a rounder 16pt corner, and every row shares that margin.
- **Tinting the pill of the clip the playhead is in:** a 12% coral fill and a coral glyph were too faint to notice mid-song, and the section name under the timeline already says where you are.
- **A volume slider styled to match the scrubber:** a thin track and a small dot through `MPVolumeView`'s image setters still sat above its speaker icons on a device. It's the native slider now, though its thumb outweighs the scrubber.
- **A white capsule thumb on the scrubber, the size of the native slider's,** so the scrubber and volume read as a pair: a 38pt thumb hid the spot under the finger and made scrubbing less accurate. The track thickens while a finger is down instead.
- **A volume track of our own driving a hidden `MPVolumeView`:** it matched the scrubber exactly, but reading the level needed an audio session of our own, and setting it went through the hidden view's inner slider.
- **An upright volume slider beside the wheel in the wide layout:** it was `MPVolumeView` turned 90°, which Apple doesn't document or do itself.
- **`MPVolumeView`'s slider forced into iOS 26's thumbless style:** its private slider couldn't be dragged back up from zero, and centring it by hand came undone whenever it laid itself out again.
- **The wide header aligned to the column's leading edge,** with the buttons trailing under it: it fought the centred wheel, and Change Song sat apart from the song it changes.
- **Regrouping the wide transport by meaning:** Mark in the transport with the other on-the-beat buttons, and Loop as a chip leading the clip row it scopes. Mocked up, moving both off their familiar spots made no sense.
- **Taller glass pills,** 36–40pt to match Mark: the extra height cost an iPhone SE its full-size wheel.
- **The wide playback column as a tight block** centred beside the header and wheel: it looked stark. Stretched the whole height, an iPad window's rows drifted apart, so each gap grows by at most 28pt.
- **The cover over the playback column in the wide layout,** up to 180pt: it was the only thing the volume row could take height from, and on a landscape phone it shrank to 76pt.
- **⏮ for restart:** a triangle-and-bar beside the skip buttons' circular arrows looked like a different set, and reads as "previous track". Restart uses `gobackward`, the skip arrow without a number.

- **The mesh drawn behind the Mac's split view:** the columns cover anything behind them, so the window stayed white. It is the window's own container background instead.
- **A picked song in the Mac sheet filled with the accent or system blue:** coral there meant "on", and blue is a second tint. The pick is a neutral 14% fill.

## Website

The website is `docs/`: plain HTML with one shared `styles.css`, served by GitHub Pages. Its colours are CSS custom properties on `:root` at the top of that file. If the accent changes in the app, change `--coral` there too.
