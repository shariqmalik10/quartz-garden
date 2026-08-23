# Diary Transcription — Design Direction

## Product mode

Operate. This is a small native macOS utility for capturing a private thought quickly and confidently, not a dashboard or publishing surface.

## Visual thesis

The menu-bar window is a quiet listening field. Deep ink surfaces reduce glare and make the live signal legible; sea-glass marks active audio; warm coral is reserved for the one consequential action: start or stop recording. Typography is native, compact, and calm. Layout uses open space and fine rules rather than a stack of cards.

## Signature interaction

A 31-bar waveform is the visual center. While recording, real microphone levels feed a bounded rolling signal, so the movement confirms that the Mac can hear the user. When capture stops, the last signal settles into a static fingerprint. Reduced Motion removes spring interpolation and decorative drift while preserving the same level information and state changes.

## Interaction rules

- The first viewport tells one story: listening state, live signal, elapsed time, primary action.
- Recording is impossible to confuse with saving. Captured audio is labelled as local and pending transcription.
- Audio is retained in Application Support until the user explicitly discards it or a later transcription pipeline completes successfully.
- Vault configuration remains visible but secondary to capture.
- Manual writing is a fallback, not a competing primary action.
- Permission and error states appear in place; the root hierarchy does not jump.
- No gradients, glass effects, ornamental containers, or continuous animation unrelated to actual input.

## Tokens

- Canvas: near-black graphite (`#111820`)
- Raised field: ink (`#18232C`)
- Primary text: warm white (`#F4F0E8`)
- Secondary text: mist (`#A8B5B6`)
- Signal: sea glass (`#78C7B0`)
- Record/stop: coral (`#F0785E`)
- Hairline: white at 10–14% opacity
- Corner radius: 14 pt for the window field, 9 pt for controls, circular only for recording
- Motion: 180–280 ms localized transitions; no looping movement without live audio

## Accessibility

- Every state is expressed with text and shape, never color alone.
- The waveform exposes a single descriptive accessibility value instead of 31 noisy elements.
- Controls use native focus behavior and have at least a 36 pt hit target.
- Reduced Motion is respected, keyboard focus remains visible, and status copy does not rely on transient animation.
