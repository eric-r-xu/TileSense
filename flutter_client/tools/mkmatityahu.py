"""Generate Matityahu's synthetic game calls from the supplied voice message.

Requires ffmpeg and a Python environment with f5-tts-mlx, numpy and soundfile,
the cached lucasnewman/f5-tts-mlx model, and access to the Mac GPU.
Pass the original audio with --reference; it is not included in the repository.
"""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile

os.environ.setdefault("HF_HUB_OFFLINE", "1")

REFERENCE_TEXT = (
    "But yeah, if you're going to be there eleven and leaving by three, yikes, "
    "because I'm probably going to get there a little bit later, knowing myself. "
    "Obviously, I'm sleeping in."
)
LINES = {
    "Chi": ("Chee!", 0.85),
    "Pon": ("Pon!", 1.05),
    "Kan": ("Kahn!", 1.05),
    "Riichi": ("Ree chee!", 1.35),
    "ron": ("Ron!", 1.05),
    "Tsumo": ("Tsoo moh!", 1.35),
    "Yeah": ("Yeah!", 1.05),
    "Acquiescement": ("Okay.", 1.25),
    "Win": ("I win!", 1.35),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--line", choices=LINES, help="Regenerate only this line")
    parser.add_argument(
        "--output", type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "matityahu",
    )
    args = parser.parse_args()

    import mlx.core as mx
    import numpy as np
    import soundfile as sf
    from f5_tts_mlx.cfm import F5TTS
    from f5_tts_mlx.utils import convert_char_to_pinyin

    args.output.mkdir(parents=True, exist_ok=True)
    model = F5TTS.from_pretrained("lucasnewman/f5-tts-mlx")
    with tempfile.TemporaryDirectory(prefix="matityahu-") as scratch:
        reference = Path(scratch) / "reference.wav"
        subprocess.run([
            "ffmpeg", "-y", "-v", "error", "-i", str(args.reference),
            "-ss", "19.35", "-t", "8.35", "-ar", "24000", "-ac", "1",
            str(reference),
        ], check=True)
        samples, sr = sf.read(reference)
        audio = mx.array(samples)
        audio *= 0.1 / mx.sqrt(mx.mean(mx.square(audio)))
        for index, (name, (text, seconds)) in enumerate(LINES.items()):
            if args.line and name != args.line:
                continue
            wave, _ = model.sample(
                mx.expand_dims(audio, axis=0),
                text=convert_char_to_pinyin([REFERENCE_TEXT + " " + text]),
                duration=int((len(audio) / sr + seconds) * sr / 256),
                steps=32, method="midpoint",
                seed=218 if name == "Chi" else 120 + index,
            )
            wave = wave[len(audio):]
            mx.eval(wave)
            raw = Path(scratch) / f"{name}.wav"
            sf.write(raw, np.array(wave), sr, subtype="FLOAT")
            target = args.output / f"Matityahu_{name}.wav"
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
