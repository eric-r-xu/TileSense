# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["mlx-audio==0.6.1", "soundfile"]
# ///
"""Generate Nagomi's synthetic calls locally on Apple Silicon.

Run: uv run --python 3.11 tools/mknagomi.py
Requires ffmpeg. Downloads model weights on the first run; no API key.
The supplied, recorded match-win line is used as the reference and preserved.
"""
from pathlib import Path
import subprocess
import tempfile

import mlx.core as mx
import numpy as np
import soundfile as sf
from mlx_audio.tts.utils import load_model

MODEL = 'mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit'
LINES = {
    'Chi': 'チー！',
    'Pon': 'ポン！',
    'Kan': 'カン！',
    'Riichi': 'リーチ！',
    'ron': 'ロン。',
    'Tsumo': 'ツモ！',
    'Yeah': 'やった！',
    'Acquiescement': '仕方ありませんね。',
}


def main():
    assets = Path(__file__).resolve().parents[1] / 'assets' / 'nagomi'
    model = load_model(MODEL)
    for index, (name, text) in enumerate(LINES.items()):
        mx.random.seed(42 if name == 'ron' else 42 + index)
        print(f'Generating {name}: {text}', flush=True)
        results = list(model.generate(
            text=text,
            lang_code='Japanese',
            ref_audio=str(assets / 'Nagomi_Win.wav'),
            ref_text='もう一局、私と打ってくれませんか？',
            max_tokens=180,
        ))
        samples = np.concatenate([np.asarray(r.audio) for r in results])
        rate = results[0].sample_rate
        duration = len(samples) / rate
        if not 0.15 < duration < 7:
            raise ValueError(f'Unexpected duration for {name}: {duration}')
        with tempfile.TemporaryDirectory() as temp:
            raw = Path(temp) / 'raw.wav'
            sf.write(raw, samples, rate)
            subprocess.run([
                'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
                '-i', str(raw), '-af',
                'loudnorm=I=-18:TP=-2:LRA=7,afade=t=in:d=0.01,'
                f'afade=t=out:st={max(0, duration - 0.025)}:d=0.025',
                '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le',
                '-map_metadata', '-1', str(assets / f'Nagomi_{name}.wav'),
            ], check=True)
        print(f'Saved {name} ({duration:.2f}s)', flush=True)


if __name__ == '__main__':
    main()
