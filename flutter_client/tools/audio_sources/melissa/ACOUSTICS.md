# Melissa voice acoustics

`assets/melissa/Melissa_Yeah.wav` is the acoustic reference for the other eight
Melissa calls. The reference laugh is not rewritten by `tools/mkmelissa.py`.

The script uses [WORLD/PyWorld](https://github.com/JeremyCCHsu/Python-Wrapper-for-World-Vocoder)
to measure the laugh's pitch contour, pulse interval, broad spectral coloration
and aperiodic (breathy) excitation, then resynthesize the existing spoken calls.
Original articulation is preserved in the development-only `spoken_dry/` folder.

- Syllables follow the laugh's rise-and-fall pitch contour while retaining some
  of the words' original intonation. Kan and Tsumo use a lower pitch register
  to preserve vowel clarity.
- Duration moves toward the measured laugh cadence, bounded to keep consonants
  readable. A soft pulse envelope carries its laughing delivery.
- Broad spectral shaping is limited to ±6 dB, preserving individual vowels.
- Voiced excitation blends 40% of the laugh's measured breathiness. Unvoiced
  consonants are crossfaded from the original waveform to retain their attacks.
  Pon also preserves its first 90 ms and a 25 ms transition into the new voice.
- Output matches the original RMS where headroom allows, with peaks capped at
  0.84 and short edge fades. All clips remain mono 48 kHz 16-bit PCM WAV.

These are acoustic approximations based on laughter, not recordings of Melissa
speaking or a verified reconstruction of her speaking voice.
`acoustic_profile.json` records reference measurements and each transformation.

The original dry calls were generated with macOS `say`, Samantha, at 165 wpm
(145 for Okay), pitch factor 0.94 with tempo compensation. Speech inputs were
Chee!, Pon!, Kahn!, Ree-chee!, Ron!, Tsoo-moh!, Okay., and I win!.

Regenerate from `flutter_client/` in a Python environment with these dependencies:

```sh
python -m pip install numpy scipy soundfile pyworld==0.3.5 'setuptools<81'
python tools/mkmelissa.py
```

PyWorld 0.3.5 needs the setuptools compatibility pin. Processing uses local files
and CPU only. Keeping dry inputs avoids cumulative processing on repeated runs.
