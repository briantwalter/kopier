# Keyboard sound credits

These six short, edited key taps come from **Keyboard Typing** by **Trollarch2 (Freesound)**, provided by **freesound_community** on Pixabay.

- Source: https://pixabay.com/sound-effects/technology-keyboard-typing-5997/
- License: Pixabay Content License, https://pixabay.com/service/license-summary/
- Full license: https://pixabay.com/service/terms/
- Downloaded November 6, 2026.
- Original file: `freesound_community-keyboard-typing-5997.mp3`
- Original SHA-256: `ac74e5a22d87e2617f5545d29d605774e4ddaca6de4551e61d004d3c0be80054`

The bundled WAV files are modified excerpts for Kopier's synchronized typing feedback. Each is 90 ms, mono, 44.1 kHz PCM, level-matched with short edge fades to avoid clicks. Playback is further attenuated in the app. The original recording is not bundled.

To reproduce, download the source above and convert it to mono 44.1 kHz 16-bit PCM WAV (for example with the optional developer tool FFmpeg), then run:

```sh
ffmpeg -i freesound_community-keyboard-typing-5997.mp3 -ar 44100 -ac 1 -c:a pcm_s16le /private/tmp/kopier-keyboard.wav
python3 Scripts/PrepareKeyboardSounds.py /private/tmp/kopier-keyboard.wav
```

Normal app builds use the committed WAV assets and require no audio conversion tool or network access for sounds.
