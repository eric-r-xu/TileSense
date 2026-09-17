# Erika assets

Erika is a female character with the same nine voice events as Eric. Runtime
assets are in `assets/erika/` and are registered in `lib/game/sfx.dart` and
`pubspec.yaml`. The multiplayer roster also includes `erika`.

## Voice

Generated with macOS `say`, using `Samantha (English (US))` consistently for
all nine clips — this machine only has the classic (non-neural) system
voices installed, not one of the newer premium/Siri ones. These are
synthetic female recordings, not a cloned voice.

| Filename suffix | Speech input |
| --- | --- |
| Chi | Chee! |
| Pon | Pon! |
| Kan | Kahn! |
| Riichi | Ree-chee! |
| ron | Ron! |
| Tsumo | Tsoo-moh! |
| Yeah | Yeah! |
| Acquiescement | Okay. |
| Win | I win! |

Phonetic English inputs preserve the intended mahjong pronunciations. Files
are mono, 48 kHz, signed 16-bit PCM WAV, matching Eric's audio format.

Regenerate all nine with `python3 tools/mkerika.py` (macOS + FFmpeg only; run
from `flutter_client/`). It speaks each line at 170 wpm (150 for
Acquiescement — 20 slower than the rest, same gap as before) and pitches the
result up by a factor of 1.05 (under one semitone) before the usual trim and
limiter — softer and less clipped/robotic than the original 185/165 wpm,
unshifted take, closer to a modern conversational TTS voice without sounding
cartoonish. `asetrate` must be scaled off `say`'s own 22050 Hz output rate,
not the 48 kHz target — get that backwards and the pitch shift also changes
the clip's speed. Silence is trimmed with FFmpeg, retaining 25 ms before and
80 ms after speech, with a 0.89 peak limiter and no automatic gain. Each clip
lasts about 0.4–0.7 s.

The script's filter chain (per line, `TEXT` and `RATE` from the table above):

```sh
say -v 'Samantha (English (US))' -r $RATE -o /tmp/Erika_Chi.aiff 'TEXT'
ffmpeg -i /tmp/Erika_Chi.aiff \
  -af 'asetrate=22050*1.05,aresample=48000,atempo=0.952381,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.025,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,areverse,alimiter=limit=0.89:level=false' \
  -ar 48000 -ac 1 -c:a pcm_s16le assets/erika/Erika_Chi.wav
```

## Portrait

Created with the built-in image generation tool. Saved as `assets/erika/erika.png`
with its generated transparency preserved. Eric's portrait was viewed as a
style reference. Generation prompt:

> Use case: stylized-concept. Create a new game character portrait for Erika, an adult East Asian woman, in the same bold geometric cartoon illustration style as the Eric portrait visible earlier in this conversation: chunky dark outlines, angular cel shading, warm skin, dark hair, smiling friendly confident expression, casual light blue top with dark backpack straps, dark sunglasses. Give her shoulder-length dark hair swept to one side and a feminine adult face. Head and upper shoulders, three-quarter view facing right, centered, entire hair silhouette within frame and generous small margin around it, tight avatar-friendly bust composition. Match the reference's clean graphic shapes and warm lighting. Single character only, no text, no border, no watermark, no props besides clothing and sunglasses. Actual transparent background with alpha, PNG. This is a new female character, not an edit of Eric.
