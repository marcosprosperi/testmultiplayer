# Generates the game's 8-bit style sound effects as 16-bit mono WAV files
import sys, wave
import numpy as np

RATE = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(7)

def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE

def square(freq, seconds, duty=0.5):
    """freq can be a number or an array (for sweeps)"""
    n = int(RATE * seconds)
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    phase = np.cumsum(f) / RATE
    return np.where((phase % 1.0) < duty, 1.0, -1.0)

def envelope(n, attack=0.005, release=0.6):
    env = np.ones(n)
    a = max(1, int(RATE * attack))
    env[:a] = np.linspace(0, 1, a)
    r = int(n * release)
    if r:
        env[-r:] *= np.linspace(1, 0, r) ** 1.5
    return env

def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))

def lowpass(x, amount):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += amount * (v - acc)
        y[i] = acc
    return y

def note(freq, seconds, volume=0.5, duty=0.5, release=0.6):
    s = square(freq, seconds, duty)
    return s * envelope(len(s), release=release) * volume

def save(name, samples):
    samples = np.clip(samples, -1, 1)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((samples * 32000).astype("<i2").tobytes())

silence = lambda s: np.zeros(int(RATE * s))

# Start lights: a beep per red light, a higher longer one for "¡ARRANCA!"
save("beep", note(523, 0.18, 0.45, release=0.4))
save("go", note(1047, 0.55, 0.45, release=0.7))
# Jump: quick rising sweep
save("jump", note(np.linspace(320, 640, int(RATE * 0.12)), 0.12, 0.25, duty=0.25))
# Losing: falling sweep with some noise
fall = note(np.linspace(700, 90, int(RATE * 0.45)), 0.45, 0.4, duty=0.5, release=0.8)
save("death", fall + noise(0.45) * envelope(int(RATE * 0.45), release=0.9) * 0.12)
# Coin: the classic two-tone
save("coin", np.concatenate([note(988, 0.06, 0.35, release=0.1), note(1319, 0.2, 0.35, release=0.8)]))
# Crossing the finish line: arpeggio
save("finish", np.concatenate([note(f, 0.09, 0.4, release=0.3) for f in (523, 659, 784)] + [note(1047, 0.4, 0.4, release=0.8)]))
# Results table: two short chords
chord = lambda freqs, s: sum(note(f, s, 0.22, release=0.7) for f in freqs)
save("results", np.concatenate([chord((392, 494, 587), 0.16), silence(0.04), chord((523, 659, 784), 0.4)]))
# Champion: fanfare
fanfare = [(523, 0.12), (523, 0.12), (523, 0.12), (659, 0.36), (587, 0.12), (659, 0.12), (784, 0.6)]
save("champion", np.concatenate([np.concatenate([note(f, s * 0.9, 0.4, release=0.4), silence(s * 0.1)]) for f, s in fanfare]))
# Cannon shot: low-passed noise burst with a thump
boom = lowpass(noise(0.3), 0.15) * envelope(int(RATE * 0.3), release=0.9) * 1.6
save("cannon", boom + note(np.linspace(140, 50, int(RATE * 0.3)), 0.3, 0.3, release=0.9))
# Falling platform starting to give way: crackle
crack = noise(0.25) * (rng.uniform(0, 1, int(RATE * 0.25)) > 0.85) * envelope(int(RATE * 0.25), release=0.8)
save("crack", lowpass(crack, 0.5) * 1.5)
# Trap button: short click
save("click", np.concatenate([note(1800, 0.02, 0.4, release=0.5), note(900, 0.05, 0.3, release=0.8)]))
# Spikes coming out: quick metallic rising scrape
save("spikes", note(np.linspace(900, 1700, int(RATE * 0.12)), 0.12, 0.25, duty=0.125) + noise(0.12) * envelope(int(RATE * 0.12)) * 0.1)
# Crusher hitting the floor: heavy thud
thud = lowpass(noise(0.35), 0.08) * envelope(int(RATE * 0.35), release=0.95) * 2.2
save("slam", thud + note(np.linspace(90, 40, int(RATE * 0.35)), 0.35, 0.4, release=0.9))
# Fan: filtered noise swell
whoosh = lowpass(noise(1.0), 0.05) * 2.5
swell = np.concatenate([np.linspace(0, 1, int(RATE * 0.3)), np.ones(int(RATE * 0.4)), np.linspace(1, 0, int(RATE * 0.3))])
save("wind", whoosh * swell[:len(whoosh)] * 0.8)
# Squashing an enemy: soft boing
save("stomp", note(np.linspace(500, 180, int(RATE * 0.12)), 0.12, 0.35, duty=0.5, release=0.6))
# Menu button: a round little pop
pop = note(np.linspace(600, 1100, int(RATE * 0.05)), 0.05, 0.3, duty=0.5, release=0.7)
save("ui_click", np.concatenate([pop, note(1320, 0.04, 0.15, duty=0.25, release=0.9)]))
# Pointing at a button: a tiny tick
save("ui_hover", note(1700, 0.025, 0.15, duty=0.25, release=0.8))
print("ok")
