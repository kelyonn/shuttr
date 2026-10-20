#!/usr/bin/env python3
"""Synthesise the camera sounds (assets/sounds/). Procedural, so there's no
licensing question — each is built from clicks, noise bursts and motor
tones shaped to match how that kind of camera sounds.

    ./.venv-tools/bin/python3 tool/sounds/gen_sounds.py
"""

import wave
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "sounds"
rng = np.random.default_rng(3)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack=0.001, decay=0.03):
    x = np.arange(n) / SR
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / decay)


def click(dur=0.04, decay=0.006, tone=3000, noise=1.0, gain=1.0):
    n = int(SR * dur)
    x = t(dur)
    s = noise * rng.standard_normal(n) + 0.6 * np.sin(2 * np.pi * tone * x)
    return gain * s * env(n, 0.0005, decay)


def lowpass(s, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.zeros_like(s)
    y = 0.0
    for i, v in enumerate(s):
        y = (1 - a) * v + a * y
        out[i] = y
    return out


def place(total, *parts):
    buf = np.zeros(int(SR * total))
    for at, s in parts:
        i = int(SR * at)
        j = min(len(buf), i + len(s))
        buf[i:j] += s[: j - i]
    return buf


def motor(dur, f0=95, f1=140, grit=0.3):
    x = t(dur)
    f = np.linspace(f0, f1, len(x))
    phase = 2 * np.pi * np.cumsum(f) / SR
    s = np.sign(np.sin(phase)) * 0.4 + np.sin(2 * phase) * 0.3
    s += grit * rng.standard_normal(len(x))
    s = lowpass(s, 1800)
    fade = np.minimum(1, np.minimum(x / 0.03, (dur - x) / 0.05))
    return s * fade


def beep(freq, dur):
    x = t(dur)
    s = np.sign(np.sin(2 * np.pi * freq * x)) * 0.35  # square: piezo buzzer
    fade = np.minimum(1, np.minimum(x / 0.003, (dur - x) / 0.003))
    return lowpass(s * fade, 6000)


def write(name, s):
    s = s / (np.max(np.abs(s)) + 1e-9) * 0.85
    pcm = (s * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name)


SOUNDS = {
    # Digicam: the fake electronic shutter only (no beeps, @kalyan).
    "digicam_shutter": place(0.25,
                             (0.0, click(0.05, 0.01, 2200, gain=0.9)),
                             (0.04, click(0.06, 0.02, 1400, gain=0.7))),
    # Disposable: plasticky spring-shutter snap.
    "disposable_shutter": place(0.2, (0.0, lowpass(click(0.08, 0.012, 900, gain=1.2), 5000)),
                                (0.012, click(0.05, 0.02, 400, 0.6, 0.5))),
    # Thumbwheel: a run of ratchet ticks.
    "disposable_advance": place(0.75, *[(0.06 * i + rng.uniform(0, 0.012),
                                        click(0.02, 0.003, 4000, gain=0.5 + 0.2 * rng.random()))
                                       for i in range(11)]),
    # Instant: heavy shutter clack, then the motor ejecting the print.
    "instant_shutter": place(0.25, (0.0, lowpass(click(0.1, 0.02, 500, gain=1.3), 3500))),
    "instant_advance": place(1.3, (0.0, motor(1.2, 110, 150, 0.5))),
    # 35mm compact: crisp leaf shutter, then a short auto-winder whirr.
    "film_shutter": place(0.2, (0.0, click(0.05, 0.007, 2600, gain=1.0))),
    "film_advance": place(0.6, (0.02, motor(0.5, 180, 260, 0.25))),
    # Camera phone: the played-back "shutter" sample through a tiny speaker.
    "phone_shutter": lowpass(place(0.3, (0.0, click(0.06, 0.02, 1800)),
                                   (0.09, click(0.08, 0.03, 1200, gain=0.8))), 3000)
                     - lowpass(place(0.3, (0.0, click(0.06, 0.02, 1800)),
                                     (0.09, click(0.08, 0.03, 1200, gain=0.8))), 500),
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, s in SOUNDS.items():
        write(name, s)
