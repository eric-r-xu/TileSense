# Nagomi

`nagomi.png` is a generated anime avatar based on the supplied Nagomi reference,
with framing inspired by the existing Saeko portrait.

## Voice

`Nagomi_Win.wav` comes from the user-supplied `nogomi voice sample.m4a`
(Nodoka from *Saki*, as requested). The local automatic transcript reads roughly
“One more round—would you play with me?” It is used after a match win.

Processing: extract 0.80–4.45 seconds, high-pass at 80 Hz, loudness normalize to
-18 LUFS / -2 dBTP, apply 15 ms fade-in and 50 ms fade-out, and export mono
48 kHz 16-bit PCM WAV. The original recording is unchanged.

## Locally generated calls

The other eight clips are synthetic speech generated with
[`mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit`](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit)
using MLX Audio 0.6.1 on Apple Silicon. They are approximations conditioned on
`Nagomi_Win.wav`, not additional original anime recordings.

Reproduce from `flutter_client` with:

```sh
uv run --python 3.11 tools/mknagomi.py
```

The first run downloads the model. Generation is local and requires no API key.
The script preserves the original win line, generates Japanese calls and reactions,
and exports normalized mono 48 kHz 16-bit PCM WAVs. Reference transcript:
`もう一局、私と打ってくれませんか？`

| File suffix | Spoken text |
| --- | --- |
| Chi | チー！ |
| Pon | ポン！ |
| Kan | カン！ |
| Riichi | リーチ！ |
| ron | ロン。 |
| Tsumo | ツモ！ |
| Yeah | やった！ |
| Acquiescement | 仕方ありませんね。 |

Rinshan falls back to Tsumo. The short reference limits voice fidelity; generated
clips should be listened to when evaluating pronunciation and likeness.
