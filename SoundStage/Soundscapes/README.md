# Soundscapes — real audio loops

Drop seamless, royalty-free **field recordings** here and the app plays them
instead of the synthesized versions. Each file is looped continuously and mixed
through the room reverb. If a file is missing, that layer falls back to the
built-in synthesis automatically — so you can add them one at a time.

## Filenames (exact, lowercase)

| Soundscape   | File        |
|--------------|-------------|
| Rain         | `rain.m4a`  |
| Ocean        | `ocean.m4a` |
| Forest       | `forest.m4a`|
| Wind         | `wind.m4a`  |
| Thunder      | `thunder.m4a`|
| Fire         | `fire.m4a`  |
| Café         | `cafe.m4a`  |
| Stream       | `stream.m4a`|
| White Noise  | `noise.m4a` |

`.m4a` is preferred, but `.wav`, `.caf`, `.aif`/`.aiff` and `.mp3` also work
(the loader tries them in that order).

## What makes a good file

- **Seamless loop**: the end should flow back into the start with no click or
  obvious "seam". 30–90 seconds is plenty; longer = less repetitive.
- **Stereo**, 44.1 kHz, normalized (not clipping). Steady-state texture works
  best (avoid a big one-off event near the loop point).
- Keep them reasonably small (a minute of AAC `.m4a` is ~1 MB).

## Where to get them (royalty-free / CC0)

- **Pixabay Sound Effects** — https://pixabay.com/sound-effects/ (no attribution)
- **Freesound** — https://freesound.org (filter license to **Creative Commons 0**)
- **mixkit** — https://mixkit.co/free-sound-effects/

Search terms: "rain loop", "ocean waves loop", "campfire crackle loop",
"forest ambience", "wind loop", "thunderstorm", "coffee shop ambience",
"stream water loop", "white noise".

## How to add to the app

Drag the files into this `Soundscapes` folder in Xcode (or into the project's
SoundStage group). Make sure they're included in the **SoundStage** target's
"Copy Bundle Resources". Rebuild — done.
