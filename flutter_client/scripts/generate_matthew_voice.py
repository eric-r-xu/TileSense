# /// script
# requires-python = ">=3.11,<3.13"
# dependencies = ["mlx-audio==0.6.1", "soundfile"]
# ///
"""Generate Matthew's voice clips locally: uv run --python 3.11 scripts/generate_matthew_voice.py REFERENCE OUTPUT_DIR.

The reference is the supplied mattS.wav recording, despite its AAC container.
Requires Apple Silicon, ffmpeg, and the Qwen model (downloaded on first use).
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

import mlx.core as mx
import numpy as np
import soundfile as sf
from mlx_audio.tts.utils import load_model

MODEL = 'mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit'
REFERENCE_TEXT = "Alright Eric, well it's been good catching up. I'm gonna go back to studying."
LINES = {
    'Chi': 'Chee!',
    'Pon': 'Pon!',
    'Kan': 'Kan!',
    'Riichi': 'Reechee!',
    'ron': 'Ron!',
    'Tsumo': 'Tsoo-moh!',
    'Yeah': 'Yeah!',
    'Acquiescement': 'Okay.',
    'Win': 'I win!',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference', type=Path)
    parser.add_argument('output_dir', type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    model = load_model(MODEL)
    with tempfile.TemporaryDirectory() as temp:
        reference = Path(temp) / 'reference.wav'
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
                        '-i', str(args.reference), '-ac', '1', '-ar', '24000',
                        str(reference)], check=True)
        for index, (name, line) in enumerate(LINES.items()):
            mx.random.seed(42 + index)
            print(f'Generating {name}: {line}', flush=True)
            results = list(model.generate(text=line, lang_code='English',
                                         ref_audio=str(reference), ref_text=REFERENCE_TEXT,
                                         max_tokens=180))
            samples = np.concatenate([np.asarray(result.audio) for result in results])
            rate = results[0].sample_rate
            duration = len(samples) / rate
            if not 0.15 < duration < 7:
                raise ValueError(f'Unexpected duration for {name}: {duration}')
            raw = Path(temp) / 'raw.wav'
            sf.write(raw, samples, rate)
            subprocess.run([
                'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(raw),
                '-af', 'loudnorm=I=-18:TP=-2:LRA=7,afade=t=in:d=0.01,'
                       f'afade=t=out:st={max(0, duration - 0.025)}:d=0.025',
                '-ar', '48000', '-ac', '1', '-c:a', 'pcm_s16le', '-map_metadata', '-1',
                str(args.output_dir / f'Matthew_{name}.wav'),
            ], check=True)
            print(f'Saved {name} ({duration:.2f}s)', flush=True)


if __name__ == '__main__':
    main()
