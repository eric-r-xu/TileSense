# Matthew assets

Matthew is based on the foreground singer in the user-supplied
`WhatsApp Video 2025-08-19 at 21.02.14.mp4` (37.24 seconds).
The original video and extracted reference media are not bundled with the app.

## Portrait

`assets/matthew/matthew.png` was generated with the built-in imagegen tool.
The video frame at 24 seconds supplied appearance and clothing; the existing
Matityahu portrait supplied the illustration style only.

Final prompt:

> Use case: stylized-concept. Create a polished TileSense Mahjong character portrait named Matthew. Image 1 is the identity and clothing reference: the foreground man holding the microphone (short brown hair, full neatly trimmed brown beard, broad face, dark navy short-sleeved button-up shirt with small light scattered pattern). Image 2 is STYLE ONLY, an existing game portrait; do not copy that man's facial features, piercings, hair or blue tank top. Draw Matthew in the same bold outlined, faceted cel-shaded illustration style. Friendly confident expression, face turned slightly three-quarter toward the viewer, eyes open, warm natural skin tones correcting the purple bar lighting. Head and shoulders bust filling a square portrait with comfortable padding above hair. Preserve his recognizable face, hairline, beard and patterned collared shirt. Remove microphone, hands, other people and all background. True transparent background, no lettering, no border, no watermark, no jewelry added. Clean silhouette suitable for a small circular avatar. Output PNG.

## Voice generation

The nine game lines are synthetic, conditioned on the singer's separated vocals.
They are not recordings of him saying the game calls. A singing reference can
carry melodic delivery, room reverberation, or imperfect pronunciation into the
generated speech; voice likeness needs a listening review.

Preparation (ffmpeg, Python 3.11, Demucs 4.1.0):

```sh
ffmpeg -i "/path/to/WhatsApp Video 2025-08-19 at 21.02.14.mp4" \
  -vn -ac 1 -ar 24000 /path/to/source.wav
python -m demucs --two-stems vocals -n htdemucs -d cpu \
  --out /path/to/separated /path/to/source.wav
python flutter_client/tools/mkmatthew.py \
  --reference /path/to/separated/htdemucs/source/vocals.wav
```

The generator selects 3.30–12.15 seconds of that full-length vocal stem,
normalizes its RMS, and conditions F5-TTS MLX on the transcribed excerpt.
It uses `lucasnewman/f5-tts-mlx`, 32 midpoint steps and seeds starting at 526.
Pon, Kan, and Riichi use longer durations with seeds 931, 932, and 933.
Win uses the final phrase from a 12-second call sequence (seed 926), cropped
from 10.8 seconds onward; that gives the short phrase more speech context.
Outputs are trimmed, loudness-normalized mono 48 kHz PCM16 WAV files.
Use `--line Pon Kan` to regenerate selected calls and `--output` for audition
variants. The generator uses cached models by default; set `HF_HUB_OFFLINE=0`
on its first run if the model needs downloading.

Generation environment: f5-tts-mlx 0.2.6, mlx 0.32.2, numpy 2.4.6,
soundfile 0.14.0. F5-TTS 0.2.6 needs this compatibility fix in its installed
`cfm.py` when used with MLX 0.32.2:

```python
# Replace:
mx.random.normal((self.num_channels, dur))
# With:
mx.random.normal((self.num_channels, int(dur.item())))
```

Matthew uses the standard Tsumo fallback for Rinshan, matching the other
characters without a dedicated Rinshan recording.
