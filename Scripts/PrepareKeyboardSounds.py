#!/usr/bin/env python3
"""Extract quiet key taps from the PCM WAV conversion of Pixabay sound 5997."""
import array
from pathlib import Path
import sys
import wave

source = Path(sys.argv[1])
output = Path(__file__).resolve().parent.parent / 'Assets' / 'Keyboard'
with wave.open(str(source)) as audio:
    assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 44100)
    samples = array.array('h', audio.readframes(audio.getnframes()))
if sys.byteorder != 'little':
    samples.byteswap()
output.mkdir(parents=True, exist_ok=True)
# Distinct key strikes from the selected recording; keep the original timbre.
for number, peak in enumerate([0.269, 1.470, 2.879, 3.724, 6.899, 9.057], 1):
    start = round((peak - 0.008) * 44100)
    excerpt = samples[start:start + round(0.090 * 44100)]
    gain = 0.25 * 32767 / max(abs(value) for value in excerpt)
    for index, value in enumerate(excerpt):
        fade = min(1, index / 66, (len(excerpt) - 1 - index) / 176)
        excerpt[index] = round(value * gain * fade)
    if sys.byteorder != 'little':
        excerpt.byteswap()
    with wave.open(str(output / f'Key-{number}.wav'), 'wb') as audio:
        audio.setparams((1, 2, 44100, 0, 'NONE', 'not compressed'))
        audio.writeframes(excerpt.tobytes())
