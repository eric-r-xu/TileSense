"""Build Astaroth call-out wavs from his existing mood takes.

No TTS exists for this voice, so each call is derived from the closest mood
recording: trim silence, a small pitch/tempo shift for character, clamp length,
short fades, peak-normalise. Output matches the folder format (48 kHz mono s16).
"""
import array
import os
import wave

SRC = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "astaroth",
)

# out name <- (source, pitch factor >1 = higher/faster, max seconds)
JOBS = {
    "Astaroth_Chi.wav":    ("Astaroth_Acquiescement.wav", 1.05, 0.85),
    "Astaroth_Pon.wav":    ("Astaroth_Colere.wav",        0.95, 0.80),
    "Astaroth_Kan.wav":    ("Astaroth_Colere_2.wav",      0.93, 0.90),
    "Astaroth_Riichi.wav": ("Astaroth_Negation.wav",      0.98, 1.00),
    "Astaroth_ron.wav":    ("Astaroth_Rire.wav",          1.00, 1.40),
    "Astaroth_Tsumo.wav":  ("Astaroth_Joie.wav",          1.03, 0.90),
}

RATE = 48000
SIL = 260          # |sample| below this counts as silence for trimming
PAD = int(0.02 * RATE)   # keep 20 ms of run-up/tail around the trimmed region


def read(path):
    w = wave.open(path, "rb")
    assert w.getnchannels() == 1 and w.getsampwidth() == 2, path
    data = array.array("h")
    data.frombytes(w.readframes(w.getnframes()))
    w.close()
    return data


def trim(s):
    n = len(s)
    a = 0
    while a < n and abs(s[a]) < SIL:
        a += 1
    b = n - 1
    while b > a and abs(s[b]) < SIL:
        b -= 1
    a = max(0, a - PAD)
    b = min(n - 1, b + PAD)
    return s[a:b + 1]


def resample(s, factor):
    """factor > 1 => shorter + higher pitched (out[i] = in[i*factor])."""
    if abs(factor - 1.0) < 1e-3:
        return s
    out_len = int(len(s) / factor)
    out = array.array("h", bytes(2 * out_len))
    for i in range(out_len):
        pos = i * factor
        j = int(pos)
        frac = pos - j
        s0 = s[j] if j < len(s) else 0
        s1 = s[j + 1] if j + 1 < len(s) else s0
        out[i] = int(s0 + (s1 - s0) * frac)
    return out


def clamp(s, max_sec):
    lim = int(max_sec * RATE)
    if len(s) > lim:
        s = s[:lim]
    return s


def fades(s, fin=0.006, fout=0.045):
    n = len(s)
    fi = min(int(fin * RATE), n // 2)
    fo = min(int(fout * RATE), n // 2)
    for i in range(fi):
        s[i] = int(s[i] * i / fi)
    for i in range(fo):
        s[n - 1 - i] = int(s[n - 1 - i] * i / fo)
    return s


def normalize(s, target=0.89):
    peak = max((abs(v) for v in s), default=1)
    if peak == 0:
        return s
    g = (target * 32767) / peak
    if g >= 1.0:  # only bring loud clips down / quiet ones up a touch
        g = min(g, 4.0)
    for i in range(len(s)):
        v = int(s[i] * g)
        s[i] = 32767 if v > 32767 else -32768 if v < -32768 else v
    return s


def write(path, s):
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(s.tobytes())
    w.close()


for out_name, (src_name, factor, max_sec) in JOBS.items():
    s = read(os.path.join(SRC, src_name))
    s = trim(s)
    s = resample(s, factor)
    s = clamp(s, max_sec)
    s = fades(s)
    s = normalize(s)
    write(os.path.join(SRC, out_name), s)
    print(f"{out_name:22s} <- {src_name:28s} {len(s)/RATE:.3f}s")
