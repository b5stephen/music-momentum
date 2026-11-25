# CLAUDE.md

## Commands

```sh
xcodebuild build -scheme MusicMomentum -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
xcodebuild test  -scheme MusicMomentum -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:MusicMomentumTests
xcodebuild build -scheme MusicMomentum -destination 'platform=macOS'
# narrower: -only-testing:MusicMomentumTests/LoopChainTests[/testName]
```

The simulator must run iOS ≥ 26.4 or the build is rejected with "doesn't match deployment target"; `xcrun simctl list devices available` if the one above is gone. Playback, `SongLookup` and the pickers need a real device with a subscription; the simulator builds and runs unit tests only, and unit tests must never need MusicKit. The app target also builds natively for macOS; unit tests run on the iOS simulator only. Guard iOS-only API with `#if os(iOS)` (or `canImport(UIKit)` beside an existing guard), and UIKit's semantic colours go through `Color+System`.

Simulators are slimmed with [simslim](https://github.com/MobAI-App/simslim) profiles in `simslim/`. `test.json` turns off every optional service, which is safe because unit tests use in-memory stores; `simslim verify <udid> --profile simslim/test.json || simslim on <udid> --profile simslim/test.json` before a test run, and `simslim watch --profile simslim/test.json` alongside parallel testing, whose per-worker clones start stock. `icloud.json` keeps the iCloud and Apple Account daemons for the one simulator signed in to push the CloudKit schema; check it with `simslim doctor <udid> --requires icloud,keychain-sync`. If iCloud sign-in still fails, add `store` to its `except`, since the two share the Apple Media Services daemons. A slim simulator can also get iCloud back without a reboot: `simslim enable <udid> icloud`.

## Layout

`App/` entry point and tab shell · `Model/` SwiftData models · `Music/` everything that talks to MusicKit outside the UI · one folder per screen (`Practice/`, `Saved/`), with a flow only one screen presents nested inside it (`Practice/SongPicker/`). Promote a nested flow when a second screen presents it. No `Components/`, `Utilities/` or `Helpers/` folder until two screens actually share something, and then name the folder for what it holds, not for being shared. Folders are Xcode synchronized groups, so moving a file on disk is the whole job. Tests mirror the source folders. Don't list screens here; the folder is the documentation.

## Rules the code can't enforce

- `RootTabView` owns the one `PlaybackController`; it's the only thing that talks to `ApplicationMusicPlayer`. Its comments record MusicKit quirks (seek settling, unplayed queues dropping writes, rate changes starting a paused player) — read them before changing it.
- Choosing something (a song, a marker) never starts playback. The exceptions are "Play on Loop" and setting A·B's A (its first press, or Start A·B Here), since B is found by listening; their comments explain why. Setting B never starts it.
- Only the loop button turns looping on or off, bar A·B: its B starts its unsaved loop, and discarding that loop stops it. Pills reshape scope, and running out of clips widens to whole-song rather than stopping.
- Speeds are persisted only on explicit save, never from `playbackRate`'s `didSet`.
- All model mutation goes through `SongMarker.add/set/clearEnd/delete` and `SavedSong.save/touch/markPracticed/setArtwork`, which enforce the invariants and save. New models go in `AppSchema.models`; the app, previews and tests all build from it.
- Storage APIs take plain values, with a `Song` overload on top, because `Song`/`Artwork` have no public initialisers and tests can't construct them.

## iCloud sync

- SwiftData mirrors the store into the private database of `iCloud.dev.etched.music-momentum`, named in `MusicMomentum.entitlements`, `MusicMomentum-macOS.entitlements` and `AppSchema.cloudKitContainer`. CloudKit forbids `#Unique` and needs every relationship optional and every attribute optional or defaulted; `SavedSong.mergeDuplicates` stands in for the missing uniqueness on `songID`.
- The schema is additive-only once it's in Production: add models and properties, never rename, delete or retype one, or builds already installed stop syncing. Change a shape by adding a new property beside the old one.
- **Remind the user to deploy the CloudKit schema** whenever a change adds or alters a model property or `AppSchema.models`: say so when committing it, and again before any TestFlight/App Store build that follows it. Production never creates record types or fields itself, and Development only learns a field once a record carrying a non-nil value for it has been exported, so a property left nil throughout testing is missing from both and Development-vs-Production shows no diff. Steps, from a debug build signed into iCloud (the simulator is fine): Saved tab → hammer menu → **Validate CloudKit Schema** (dry run, prints the schema to the Xcode console), then **Push CloudKit Schema (Dev)**, which uploads every entity and attribute from the model via `CloudKitSchemaInitializer`, then CloudKit Console → Schema → **Deploy Schema Changes**. Skipping it shows up on the client as a bare `CKErrorDomain error 2` (`partialFailure`).
- The simulator gets no CloudKit pushes; remote changes only arrive on real devices.

## CI and releases

Xcode Cloud builds and tests every pushed branch; on `main`, a passing run archives and ships to internal TestFlight. Workflows live in App Store Connect, not the repo; they build the shared `MusicMomentum` scheme, whose test action runs `MusicMomentumTests` only (the UI tests are the template, so they're skipped). Xcode Cloud stamps each archive's build number from its own counter, so `CURRENT_PROJECT_VERSION` is no longer bumped by hand. `ci_scripts/` must sit beside the `.xcodeproj` (an Xcode Cloud requirement); `ci_post_xcodebuild.sh` writes the TestFlight "What to Test" notes from recent commit subjects. A model change still needs the CloudKit schema deploy before it reaches TestFlight. Xcode Cloud's runners are not slimmed.

## Conventions

- One non-private type per file, named after it. `private` helper views stay with the screen that owns them; if a second file needs one, drop `private` and move it to its own file.
- Comments record only what the code can't say — a MusicKit quirk, a past bug, a non-obvious invariant. Don't narrate the code; when touching a file, delete comments that fail that test.
- Anything pure or model-only whose failure would silently corrupt data or misplace a marker gets a unit test: `Loop.step`, the model mutators, `PlayParameterIDs`, `PreciseTime`. `PlaybackController` and views are not unit-tested; don't mock the player to get there. Tests are Swift Testing (`@Test`, `#expect`), each building its own in-memory `ModelContext` in `init()`; the UI test target is still the Xcode template.
- Pure helpers are `nonisolated` so tests can call them off the main actor.
- `DESIGN.md` is the palette and principles for the app and the `docs/` website, plus what was tried and dropped. Read it before changing how anything looks. Update it when the palette or a principle changes, or a look is tried and dropped; per-screen sizes and details belong in the code, not there.
- Every view file has a `#Preview` per meaningful state (empty, loaded, error), built on `AppSchema.inMemoryContainer()`; trivial glyphs and rows can skip it.
- Commit messages: sentence-case imperative title, then prose paragraphs on the behaviour change and what was wrong before (see `git log`). Commit and push directly on `main`.
