# Generates the game's chiptune music loops as 16-bit mono WAV files with a
# loop marker (smpl chunk), so Godot plays them looped.
# Usage: gen_music.py <sounds dir>
import struct, sys, wave
import numpy as np

RATE = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(3)

NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def freq(name):
    """'A4', 'C#5', 'Bb3' -> Hz"""
    letter, rest = name[0], name[1:]
    semis = NOTE_INDEX[letter]
    while rest[0] in "#b":
        semis += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + semis
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- Instruments -------------------------------------------------------------

def envelope(n, attack=0.004, decay=0.08, sustain=0.7, release=0.03):
    env = np.full(n, sustain)
    a, d, r = int(RATE * attack), int(RATE * decay), int(RATE * release)
    a = min(a, n)
    env[:a] = np.linspace(0, 1, a)
    d = min(d, n - a)
    env[a:a + d] = np.linspace(1, sustain, d)
    r = min(r, n)
    env[n - r:] *= np.linspace(1, 0, r)
    return env


def pulse(f, n, duty=0.5, vibrato=0.0):
    t = np.arange(n) / RATE
    fm = f * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 4 - 0.6, 0, 1))
    phase = np.cumsum(fm) / RATE
    return np.where(phase % 1.0 < duty, 1.0, -1.0)


def triangle(f, n):
    phase = np.cumsum(np.full(n, f)) / RATE
    return 4 * np.abs(phase % 1.0 - 0.5) - 1


def kick(n):
    n = min(n, int(RATE * 0.16))
    t = np.arange(n) / RATE
    f = 55 + 110 * np.exp(-t * 35)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 18)


def snare(n):
    n = min(n, int(RATE * 0.14))
    t = np.arange(n) / RATE
    return (rng.uniform(-1, 1, n) * 0.8 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 26)


def hat(n):
    n = min(n, int(RATE * 0.035))
    noise = rng.uniform(-1, 1, n)
    noise = noise - np.convolve(noise, np.ones(4) / 4, "same")  # keep the hiss
    return noise * np.exp(-np.arange(n) / RATE * 120)


# --- Song --------------------------------------------------------------------

class Song:
    def __init__(self, bpm, bars):
        self.step = 60.0 / bpm / 4  # a 16th note
        self.length = int(round(bars * 16 * self.step * RATE))
        self.mix = np.zeros(self.length + RATE * 2)  # room for tails, folded back

    def at(self, step):
        return int(round(step * self.step * RATE))

    def add(self, start_step, samples, volume):
        i = self.at(start_step)
        self.mix[i:i + len(samples)] += samples * volume

    def melody(self, notes, volume, duty=0.5, vibrato=0.004, echo=0.0, octave=0, staccato=0.92):
        """notes: list of (name or None, length in 16ths)"""
        step = 0
        for name, length in notes:
            if name:
                n = self.at(length * staccato)
                f = freq(name) * 2 ** octave
                s = pulse(f, n, duty, vibrato) * envelope(n)
                self.add(step, s, volume)
                if echo:
                    self.add(step + 3, s, volume * echo)
            step += length

    def bass(self, chords, pattern, volume, octave=2):
        """chords: one root per bar (or (root, root) for two per bar); pattern
        of (step, octave up?, length) inside half a bar"""
        for bar, chord in enumerate(chords):
            roots = chord if isinstance(chord, tuple) else (chord, chord)
            for half, root in enumerate(roots):
                for step, up, length in pattern:
                    f = freq(f"{root}{octave + up}")
                    n = self.at(length * 0.9)
                    self.add(bar * 16 + half * 8 + step, triangle(f, n) * envelope(n, sustain=0.9), volume)

    def arp(self, chords, volume, octave=4, duty=0.125):
        """16th-note arpeggio over each chord (a list of note names per bar)"""
        for bar, notes in enumerate(chords):
            for i in range(16):
                name = notes[i % len(notes)]
                n = self.at(0.8)
                self.add(bar * 16 + i, pulse(freq(f"{name}{octave}"), n, duty) * envelope(n, sustain=0.5), volume)

    def drums(self, bars, kicks, snares, hats, volume=1.0):
        for bar in range(bars):
            for s in kicks:
                self.add(bar * 16 + s, kick(RATE), 0.55 * volume)
            for s in snares:
                self.add(bar * 16 + s, snare(RATE), 0.3 * volume)
            for s in hats:
                self.add(bar * 16 + s, hat(RATE), 0.12 * volume)

    def save(self, name):
        # Tails that go past the end come back in at the start: seamless loop
        out = self.mix[:self.length].copy()
        tail = self.mix[self.length:]
        out[:len(tail)] += tail
        out = out / max(0.001, np.abs(out).max()) * 0.85
        data = (out * 32000).astype("<i2").tobytes()
        path = f"{OUT}/{name}.wav"
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(data)
        # smpl chunk: one forward loop over the whole file
        frames = len(out)
        smpl = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
        with open(path, "r+b") as f:
            f.seek(0, 2)
            f.write(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
            size = f.tell()
            f.seek(4)
            f.write(struct.pack("<I", size - 8))
        print(path, f"{frames / RATE:.1f}s")


def seq(text):
    """'E5:2 G5:2 -:4' -> [('E5', 2), ('G5', 2), (None, 4)]"""
    out = []
    for token in text.split():
        name, length = token.split(":")
        out.append((None if name == "-" else name, int(length)))
    return out


# --- Menu: happy and bouncy, C major ------------------------------------------

def menu():
    song = Song(bpm=120, bars=16)
    lead = seq("""
        E5:2 G5:2 C6:4 B5:2 G5:2 E5:4
        D5:2 G5:2 B5:4 A5:2 G5:2 D5:4
        C5:2 E5:2 A5:4 G5:2 E5:2 C5:4
        F5:4 A5:2 G5:2 F5:2 E5:2 D5:4
        E5:2 G5:2 C6:4 B5:2 G5:2 E5:4
        D5:2 G5:2 B5:4 D6:4 B5:4
        A5:4 C6:4 B5:4 D6:4
        C6:12 -:4
        A5:2 A5:2 C6:2 A5:2 G5:4 F5:4
        G5:2 G5:2 B5:2 G5:2 F5:4 D5:4
        E5:2 G5:2 B5:2 E6:2 D6:4 B5:4
        C6:4 A5:4 E5:4 A5:4
        F5:2 A5:2 C6:2 F6:2 E6:4 C6:4
        D6:2 B5:2 G5:2 B5:2 D6:4 G6:4
        E6:4 C6:4 G5:4 E5:4
        D5:2 E5:2 F5:2 G5:2 A5:2 B5:2 D6:4
    """)
    song.melody(lead, 0.22, duty=0.25, echo=0.25)
    roots = ["C", "G", "A", "F", "C", "G", ("F", "G"), "C",
             "F", "G", "E", "A", "F", "G", "C", "G"]
    song.bass(roots, [(0, 0, 2), (2, 1, 2), (4, 0, 2), (6, 1, 2)], 0.35)
    chords = [["C", "E", "G"], ["G", "B", "D"], ["A", "C", "E"], ["F", "A", "C"]] * 2
    chords += [["F", "A", "C"], ["G", "B", "D"], ["E", "G", "B"], ["A", "C", "E"],
               ["F", "A", "C"], ["G", "B", "D"], ["C", "E", "G"], ["G", "B", "D"]]
    song.arp(chords[8:], 0.06, octave=5)
    song.arp(chords[:8], 0.035, octave=4)
    song.drums(16, kicks=[0, 8], snares=[4, 12], hats=[0, 2, 4, 6, 8, 10, 12, 14], volume=0.8)
    song.save("music_menu")


# --- Race: fast and driving, A minor ------------------------------------------

def race():
    song = Song(bpm=150, bars=16)
    lead = seq("""
        A5:2 A5:2 C6:2 A5:2 E6:4 D6:2 C6:2
        C6:2 A5:2 F5:2 A5:2 C6:4 D6:2 C6:2
        G5:2 C6:2 E6:2 C6:2 G6:4 E6:2 D6:2
        D6:4 B5:4 G5:4 B5:2 D6:2
        A5:2 A5:2 C6:2 A5:2 E6:4 D6:2 C6:2
        C6:2 A5:2 F5:2 A5:2 F6:4 E6:2 D6:2
        E6:2 D6:2 C6:2 G5:2 E6:4 G6:4
        E5:2 G#5:2 B5:2 E6:2 D6:4 B5:4
        F5:4 A5:4 D6:4 F6:4
        E6:4 C6:4 A5:4 E5:4
        F5:2 A5:2 C6:2 F6:2 E6:2 C6:2 A5:4
        G#5:4 B5:4 E6:4 D6:4
        F6:4 E6:2 D6:2 A5:4 D6:4
        C6:4 B5:2 A5:2 E5:4 A5:4
        A5:2 C6:2 F6:2 C6:2 B5:2 D6:2 G6:2 D6:2
        E6:4 B5:4 G#5:4 E5:4
    """)
    song.melody(lead, 0.22, duty=0.5, vibrato=0.003, echo=0.2)
    roots = ["A", "F", "C", "G", "A", "F", "C", "E",
             "D", "A", "F", "E", "D", "A", ("F", "G"), "E"]
    song.bass(roots, [(0, 0, 1), (1, 0, 1), (2, 1, 1), (3, 0, 1), (4, 0, 1), (5, 0, 1), (6, 1, 1), (7, 0, 1)], 0.4)
    chords = [["A", "C", "E"], ["F", "A", "C"], ["C", "E", "G"], ["G", "B", "D"],
              ["A", "C", "E"], ["F", "A", "C"], ["C", "E", "G"], ["E", "G#", "B"],
              ["D", "F", "A"], ["A", "C", "E"], ["F", "A", "C"], ["E", "G#", "B"],
              ["D", "F", "A"], ["A", "C", "E"], ["F", "A", "C"], ["E", "G#", "B"]]
    song.arp(chords, 0.045, octave=4)
    song.drums(16, kicks=[0, 6, 8, 10], snares=[4, 12], hats=list(range(0, 16, 2)), volume=1.0)
    song.save("music_race")


# --- Dark: caves and night, D minor, mysterious but still moving -------------

def dark():
    song = Song(bpm=104, bars=16)
    lead = seq("""
        D5:6 F5:2 A5:4 G5:4
        F5:6 E5:2 D5:8
        D5:4 F5:4 Bb5:6 A5:2
        G5:4 E5:4 C5:8
        D5:6 F5:2 A5:4 D6:4
        C6:4 A5:4 F5:8
        G5:4 Bb5:4 D6:4 C6:2 Bb5:2
        A5:4 C#6:4 E6:8
        F6:4 D6:4 Bb5:8
        E6:4 C6:4 G5:8
        F5:2 E5:2 D5:2 F5:2 A5:4 D6:4
        A5:16
        Bb5:4 A5:4 G5:4 D5:4
        F5:4 G5:4 Bb5:4 D6:4
        C#6:4 E6:4 A5:4 C#6:4
        A5:8 -:8
    """)
    song.melody(lead, 0.2, duty=0.5, vibrato=0.006, echo=0.4, staccato=0.97)
    roots = ["D", "D", "Bb", "C", "D", "D", "G", "A",
             "Bb", "C", "D", "D", "G", "Bb", "A", "A"]
    song.bass(roots, [(0, 0, 3), (3, 0, 1), (4, 1, 2), (6, 0, 2)], 0.4)
    chords = [["D", "F", "A"], ["D", "F", "A"], ["Bb", "D", "F"], ["C", "E", "G"],
              ["D", "F", "A"], ["D", "F", "A"], ["G", "Bb", "D"], ["A", "C#", "E"],
              ["Bb", "D", "F"], ["C", "E", "G"], ["D", "F", "A"], ["D", "F", "A"],
              ["G", "Bb", "D"], ["Bb", "D", "F"], ["A", "C#", "E"], ["A", "C#", "E"]]
    song.arp(chords, 0.05, octave=4, duty=0.25)
    song.drums(16, kicks=[0, 8, 14], snares=[8], hats=[4, 12], volume=0.6)
    song.save("music_dark")


menu()
race()
dark()
