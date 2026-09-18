"""Match Melissa's spoken calls to the acoustics of her recorded laugh.

Install numpy scipy soundfile pyworld==0.3.5 'setuptools<81'. Run this file
from any directory. Original spoken articulation is retained in spoken_dry/;
Melissa_Yeah.wav is the acoustic reference and is never overwritten.
"""

import json
from pathlib import Path

import numpy as np
import pyworld as pw
import soundfile as sf
from scipy.interpolate import interp1d
from scipy.ndimage import gaussian_filter1d
from scipy.signal import find_peaks, resample

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/melissa'
SOURCES = ROOT / 'tools/audio_sources/melissa'
FRAME_MS = 5.0
SYLLABLES = {
    'Chi': 1, 'Pon': 1, 'Kan': 1, 'Riichi': 2, 'ron': 1,
    'Tsumo': 2, 'Acquiescement': 2, 'Win': 2,
}
# Very high laugh pitch obscures these vowels; use its lower register while
# retaining the same contour, coloration, breathiness and pulse timing.
PITCH_SCALE = {'Kan': .85, 'Tsumo': .70}


def analyze(path):
    x, rate = sf.read(path, dtype='float64')
    if rate != 48000 or x.ndim != 1 or len(x) < rate // 5:
        raise ValueError(f'{path}: expected nonempty mono 48 kHz speech')
    x = np.ascontiguousarray(x)
    f0, t = pw.harvest(x, rate, f0_floor=90, f0_ceil=550, frame_period=FRAME_MS)
    f0 = pw.stonemask(x, f0, t, rate)
    sp = pw.cheaptrick(x, f0, t, rate)
    ap = pw.d4c(x, f0, t, rate)
    env = np.sqrt(gaussian_filter1d(x * x, rate * .012))[
        np.minimum((t * rate).astype(int), len(x) - 1)]
    return x, rate, f0, t, sp, ap, env


def profile(reference):
    x, rate, f0, t, sp, ap, env = reference
    peaks, _ = find_peaks(env, distance=22, prominence=env.max() * .13)
    if len(peaks) < 3:
        raise ValueError('The laugh needs at least three measurable pulses')
    period = float(np.median(np.diff(t[peaks])))
    # Reject subharmonic tracks and quiet inter-breath regions of the laugh.
    reliable = (f0 > 250) & (env > env.max() * .12)
    pitch = float(np.median(f0[reliable]))
    contours, amplitudes = [], []
    phase = np.linspace(0, 1, 128)
    for peak in peaks:
        start = max(0, t[peak] - period * .45)
        end = min(t[-1], t[peak] + period * .55)
        chosen = reliable & (t >= start) & (t <= end)
        if chosen.sum() < 5:
            continue
        positions = start + phase * (end - start)
        contours.append(np.interp(positions, t[chosen], f0[chosen]))
        amplitudes.append(np.interp(positions, t, env) / env[peak])
    contour = gaussian_filter1d(np.median(contours, axis=0), 4)
    amplitude = gaussian_filter1d(np.median(amplitudes, axis=0), 3)
    # Broad timbre / microphone coloration, not the laugh's particular vowel.
    spectrum = np.median(10 * np.log10(sp[reliable] + 1e-12), axis=0)
    spectrum = gaussian_filter1d(spectrum, 450 / (rate / (2 * (sp.shape[1] - 1))))
    spectrum -= np.mean(spectrum)
    noise = np.median(ap[reliable], axis=0)
    return period, pitch, phase, contour, amplitude, spectrum, noise


def transform(source, laugh_profile, syllables, pitch_scale=1.0, preserve_onset_s=0):
    x, rate, f0, t, sp, ap, env = source
    period, pitch, phase, contour, amplitude, target_spectrum, target_noise = laugh_profile
    duration = len(x) / rate
    # Move toward the measured laugh cadence while keeping consonants readable.
    desired = syllables * period + .12
    target_duration = float(np.clip(desired, duration * .85, duration * 1.08))
    frames = round(target_duration * 1000 / FRAME_MS) + 1
    positions = np.linspace(0, len(t) - 1, frames)
    nearest = np.rint(positions).astype(int)
    f = f0[nearest].copy()
    voiced = f > 0
    sp_new = interp1d(np.arange(len(t)), np.log(sp + 1e-12), axis=0)(positions)
    ap_new = interp1d(np.arange(len(t)), ap, axis=0)(positions)
    active = np.flatnonzero(voiced)
    if len(active) < 5:
        raise ValueError('Too little voiced articulation to transform')
    progress = np.clip((np.arange(frames) - active[0]) /
                       max(1, active[-1] - active[0]), 0, 1)
    pulse_phase = np.minimum(progress * syllables, syllables - 1e-6) % 1
    pitch_shape = np.interp(pulse_phase, phase, contour) * pitch_scale
    # Retain a small amount of linguistic intonation beneath the laugh contour.
    residual = np.ones(frames)
    residual[voiced] = np.clip(f[voiced] / np.median(f[voiced]), .8, 1.25) ** .18
    f[voiced] = np.clip(pitch_shape[voiced] * residual[voiced], 250, 490)
    f[voiced] = gaussian_filter1d(f[voiced], 1)

    source_spectrum = np.median(10 * np.log10(sp[f0 > 0] + 1e-12), axis=0)
    bin_hz = rate / (2 * (sp.shape[1] - 1))
    source_spectrum = gaussian_filter1d(source_spectrum, 450 / bin_hz)
    source_spectrum -= source_spectrum.mean()
    eq_db = np.clip(target_spectrum - source_spectrum, -6, 6)
    # Apply most coloration to vowels, protecting unvoiced word boundaries.
    weight = gaussian_filter1d(voiced.astype(float), 1.5)
    sp_new += (eq_db * np.log(10) / 10)[None, :] * (.25 + .75 * weight[:, None])
    # Transfer breathiness using the measured aperiodic excitation. Keep voiced
    # harmonics and the source's consonants instead of inserting literal laughter.
    ap_new[voiced] = np.clip(.6 * ap_new[voiced] + .4 * target_noise, .001, 1)
    pulse_gain = .68 + .32 * np.clip(np.interp(pulse_phase, phase, amplitude), 0, 1)
    sp_new += 2 * np.log(1 - weight + weight * pulse_gain)[:, None]
    y = pw.synthesize(np.ascontiguousarray(f), np.ascontiguousarray(np.exp(sp_new)),
                      np.ascontiguousarray(ap_new), rate, frame_period=FRAME_MS)
    # Preserve source loudness, with a hard headroom bound and click-free edges.
    rms = np.sqrt(np.mean(x * x))
    y *= rms / max(np.sqrt(np.mean(y * y)), 1e-9)
    # WORLD can smear plosive bursts. Keep original unvoiced articulation,
    # aligned to the new timing, and crossfade smoothly into transformed vowels.
    gate = np.interp(np.linspace(0, frames - 1, len(y)), np.arange(frames),
                     gaussian_filter1d(voiced.astype(float), 1))
    if preserve_onset_s:
        gate *= np.clip((np.arange(len(y)) / rate - preserve_onset_s) / .025, 0, 1)
    dry = resample(x, len(y))
    y = gate * y + (1 - gate) * dry
    y *= min(1, .84 / max(np.max(np.abs(y)), 1e-9))
    fade = min(round(rate * .008), len(y) // 2)
    y[:fade] *= np.linspace(0, 1, fade)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y, {
        'source_duration_s': round(duration, 3),
        'output_duration_s': round(len(y) / rate, 3),
        'source_voiced_pitch_median_hz': round(float(np.median(f0[f0 > 0])), 1),
        'target_voiced_pitch_median_hz': round(float(np.median(f[voiced])), 1),
        'laugh_pitch_scale': pitch_scale,
        'preserved_onset_s': preserve_onset_s,
        'peak_dbfs': round(float(20 * np.log10(np.max(np.abs(y)))), 1),
    }


def main():
    reference = analyze(OUT / 'Melissa_Yeah.wav')
    laugh_profile = profile(reference)
    report = {
        'reference': 'assets/melissa/Melissa_Yeah.wav',
        'laugh_pulse_interval_s': round(laugh_profile[0], 3),
        'laugh_reliable_pitch_median_hz': round(laugh_profile[1], 1),
        'method': 'WORLD pitch, broad spectral color, aperiodicity and pulse-envelope transfer',
        'clips': {},
    }
    for name, syllables in SYLLABLES.items():
        filename = f'Melissa_{name}.wav'
        result, metrics = transform(analyze(SOURCES / 'spoken_dry' / filename),
                                    laugh_profile, syllables, PITCH_SCALE.get(name, 1.0),
                                    .09 if name == 'Pon' else 0)
        sf.write(OUT / filename, result, 48000, subtype='PCM_16')
        report['clips'][filename] = metrics
        print(filename, metrics, flush=True)
    (SOURCES / 'acoustic_profile.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
