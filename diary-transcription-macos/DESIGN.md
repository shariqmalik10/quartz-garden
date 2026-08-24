# Yap — Design Direction

## Product mode

Operate. This is a small native macOS utility for capturing a thought quickly and confidently. A restrained local stats ledger supports the habit without turning the utility into an analytics product or an automatic publishing surface.

## Visual thesis

The menu-bar window is a quiet listening field. Deep ink is the default, with seven intentional alternative palettes spanning light and dark environments. Sea-glass marks active audio; warm coral is reserved for the one consequential action: start or stop recording. Typography is native, compact, and calm. Layout uses open space and fine rules rather than a stack of cards.

## Signature interaction

The chosen waveform, signal rings, pixel meter, ribbon, radial signal, or dither field is the visual center. While recording, real microphone levels feed the bounded signal, so movement confirms that the Mac can hear the user. When capture stops, the last signal settles into a static fingerprint. Reduced Motion removes interpolation and decorative drift while preserving the same level information and state changes.

The Dither Signal theme adapts the ordered-pixel chart language of Dither Kit: data-bound dots, restrained bloom, crisp lines, and pointer focus. It does not imitate web controls or apply pixel effects to body text.

## Interaction rules

- The first viewport tells one story: listening state, live signal, elapsed time, primary action.
- Recording, transcription, and saving have distinct language and progress states.
- Audio and any completed transcript are retained in Application Support until the Markdown append completes successfully.
- Vault configuration remains visible but secondary to capture.
- Speak, Write, and Stats are visible in one top-level segmented control; recording locks mode changes until the current operation is safe.
- One shared destination studio makes voice and writing continue the same file. It reveals Diary, Blog, Notes, and Any file before asking for a new file, new folder + file, or existing file.
- Daily capture is private by default. Blog drafts begin private and require an explicit publication metadata change.
- Permission and error states appear in place; the root hierarchy does not jump.
- No gradients, glass effects, ornamental containers, or continuous animation unrelated to actual input.
- The dithered ledger uses real fourteen-day word totals and supports pointer scrubbing; it is not decorative texture.

## Tokens

- Canvas: near-black graphite (`#111820`)
- Raised field: ink (`#18232C`)
- Primary text: warm white (`#F4F0E8`)
- Secondary text: mist (`#A8B5B6`)
- Signal: sea glass (`#78C7B0`)
- Record/stop: coral (`#F0785E`)
- Hairline: white at 10–14% opacity
- Corner radius: 14 pt for the window field, 9 pt for controls, circular only for recording
- Motion: 180–280 ms localized transitions; only live microphone input drives continuous movement

## Accessibility

- Every state is expressed with text and shape, never color alone.
- The waveform exposes a single descriptive accessibility value instead of 31 noisy elements.
- Controls use native focus behavior and have at least a 36 pt hit target.
- Reduced Motion is respected, keyboard focus remains visible, and status copy does not rely on transient animation.
