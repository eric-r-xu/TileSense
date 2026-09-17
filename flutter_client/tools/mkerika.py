"""Regenerate Erika's nine voice clips: same macOS `say` synthesis and
FFmpeg trim/limiter chain as before (see tools/audio_sources/erika/README.md),
plus a small pitch-up and a slower rate so the line reads as a warmer, more
natural young woman instead of the flat, clipped, robotic-sounding default —
closer to a modern conversational TTS voice. No chorus/reverb: this machine's
`say` only has the classic (non-neural) system voices installed, so the
safest lever available is pitch + pacing, not timbre synthesis.

`asetrate` reinterprets the *input's own* sample rate (`say` emits 22050 Hz
AIFF), not the 48 kHz output — get that wrong and the pitch shift also
speeds up or slows down the clip by whatever the ratio to 48000 happens to
be. `atempo` then undoes asetrate's speed side effect so only pitch moves.
"""
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "erika")

VOICE = "Samantha (English (US))"
SAY_RATE_HZ = 22050  # what macOS `say` actually emits; see the docstring.

# Pitch factor >1 = higher. 1.05 is under one semitone (2^(1/12) ~= 1.0595) —
# enough to read as younger/softer without sounding cartoonish.
PITCH = 1.05

# words per minute. 20 wpm slower than the original 185/165 pair — a calmer
# cadence reads as less clipped/robotic than a rushed one.
RATE = 170
ACQUIESCEMENT_RATE = 150

LINES = {
    "Erika_Chi.wav": ("Chee!", RATE),
    "Erika_Pon.wav": ("Pon!", RATE),
    "Erika_Kan.wav": ("Kahn!", RATE),
    "Erika_Riichi.wav": ("Ree-chee!", RATE),
    "Erika_ron.wav": ("Ron!", RATE),
    "Erika_Tsumo.wav": ("Tsoo-moh!", RATE),
    "Erika_Yeah.wav": ("Yeah!", RATE),
    "Erika_Acquiescement.wav": ("Okay.", ACQUIESCEMENT_RATE),
    "Erika_Win.wav": ("I win!", RATE),
}

FILTER = (
    f"asetrate={SAY_RATE_HZ}*{PITCH},aresample=48000,atempo={1 / PITCH:.6f},"
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.025,"
    "areverse,"
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08,"
    "areverse,"
    "alimiter=limit=0.89:level=false"
)

for name, (text, rate) in LINES.items():
    aiff = f"/tmp/{name}.aiff"
    subprocess.run(
        ["say", "-v", VOICE, "-r", str(rate), "-o", aiff, text], check=True
    )
    out = os.path.join(OUT, name)
    subprocess.run(
        [
            "ffmpeg", "-y", "-i", aiff,
            "-af", FILTER,
            "-ar", "48000", "-ac", "1", "-c:a", "pcm_s16le",
            out,
        ],
        check=True,
        capture_output=True,
    )
    os.remove(aiff)
    print(f"wrote {name}")
