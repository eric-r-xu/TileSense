"""Generate Matthew's synthetic game calls from a vocal stem isolated from the supplied singing video.

Requires ffmpeg and a Python environment with f5-tts-mlx, numpy and soundfile,
the cached lucasnewman/f5-tts-mlx model, and access to the Mac GPU.
Pass the full-length isolated vocal WAV with --reference; it is not included
in the repository. See matthew_assets.md for source preparation and limitations.
"""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile

os.environ.setdefault("HF_HUB_OFFLINE", "1")

REFERENCE_TEXT = (
    "And the world is spinning, and she keeps on winning, "
    "but tell me what happens when it stops?"
)

LINES = {
    "Chi": ("Chee!", 0.85),
    "Pon": ("Pawn!", 1.5),
    "Kan": ("Kahn!", 1.5),
    "Riichi": ("Ree chee!", 1.9),
    "ron": ("Ron!", 1.05),
    "Tsumo": ("Tsoo moh!", 1.35),
    "Yeah": ("Yeah!", 1.05),
    "Acquiescement": ("Okay.", 1.25),
    "Win": ("I win!", 1.35),
}
RETAKE_SEEDS = {"Pon": 931, "Kan": 932, "Riichi": 933}
WIN_CONTEXT = (
    "Chee! Pawn! Kahn! Ree chee! Ron! Tsoo moh! Yeah! Okay. I win!"
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--line", choices=LINES, nargs="+",
                        help="Regenerate only these lines")
    parser.add_argument(
        "--output", type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "matthew",
    )
    args = parser.parse_args()

    import mlx.core as mx
    import numpy as np
    import soundfile as sf
    from f5_tts_mlx.cfm import F5TTS
    from f5_tts_mlx.utils import convert_char_to_pinyin

    args.output.mkdir(parents=True, exist_ok=True)
    model = F5TTS.from_pretrained("lucasnewman/f5-tts-mlx")
    with tempfile.TemporaryDirectory(prefix="matthew-") as scratch:
        reference = Path(scratch) / "reference.wav"
        subprocess.run([
            "ffmpeg", "-y", "-v", "error", "-i", str(args.reference),
            "-ss", "3.3", "-t", "8.85", "-ar", "24000", "-ac", "1",
            str(reference),
        ], check=True)
        samples, sr = sf.read(reference)
        audio = mx.array(samples)
        audio *= 0.1 / mx.sqrt(mx.mean(mx.square(audio)))
        for index, (name, (text, seconds)) in enumerate(LINES.items()):
            if args.line and name not in args.line:
                continue
            # The final phrase is clearer at the end of a longer utterance.
            seed = RETAKE_SEEDS.get(name, 526 + index)
            if name == "Win":
                text, seconds, seed = WIN_CONTEXT, 12.0, 926
            wave, _ = model.sample(
                mx.expand_dims(audio, axis=0),
                text=convert_char_to_pinyin([REFERENCE_TEXT + " " + text]),
                duration=int((len(audio) / sr + seconds) * sr / 256),
                steps=32, method="midpoint",
                seed=seed,
            )
            wave = wave[len(audio):]
            if name == "Win":
                wave = wave[int(10.8 * sr):]
            mx.eval(wave)
            raw = Path(scratch) / f"{name}.wav"
            sf.write(raw, np.array(wave), sr, subtype="FLOAT")
            target = args.output / f"Matthew_{name}.wav"
            subprocess.run([
                "ffmpeg", "-y", "-v", "error", "-i", str(raw),
                "-af", (
                    "highpass=f=65,"
                    "silenceremove=start_periods=1:start_threshold=-42dB:"
                    "start_silence=0.025,areverse,"
                    "silenceremove=start_periods=1:start_threshold=-42dB:"
                    "start_silence=0.07,areverse,"
                    "loudnorm=I=-18:TP=-2:LRA=7,"
                    "afade=t=in:d=0.005"
                ),
                "-ar", "48000", "-ac", "1", "-c:a", "pcm_s16le", str(target),
            ], check=True)
            print(f"Wrote {target.name}", flush=True)
            mx.clear_cache()


if __name__ == "__main__":
    main()
