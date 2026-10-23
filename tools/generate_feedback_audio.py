"""Собственные короткие UI/строительные звуки. CC0-1.0, без сторонних семплов.

Нужен numpy только при генерации, не при запуске Godot.
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'


def render():
    rng = np.random.default_rng(231026)

    def timeline(duration):
        return np.arange(int(duration * RATE)) / RATE

    def mallet(time, onset, frequency, strength=1):
        local = np.maximum(0, time - onset)
        envelope = (1 - np.exp(-local * 500)) * np.exp(-local * 9)
        partials = (np.sin(2 * np.pi * frequency * local)
                    + .22 * np.sin(2 * np.pi * 2 * frequency * local) * np.exp(-local * 12)
                    + .06 * np.sin(2 * np.pi * 3 * frequency * local) * np.exp(-local * 20))
        return strength * envelope * partials * (time >= onset)

    def air(time, cutoff=2400):
        noise = rng.normal(0, 1, len(time))
        frequencies = np.fft.rfftfreq(len(noise), 1 / RATE)
        response = 1 / (1 + (frequencies / cutoff) ** 4)
        return np.fft.irfft(np.fft.rfft(noise) * response, n=len(noise))

    def write(name, audio, peak):
        audio -= audio.mean()
        audio *= peak / max(.0001, np.max(np.abs(audio)))
        # Конец и начало каждого одиночного отклика точно затухают.
        edge = min(120, len(audio) // 6)
        audio[:edge] *= np.linspace(0, 1, edge)
        audio[-edge:] *= np.linspace(1, 0, edge)
        with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes((audio * 32767).astype('<i2').tobytes())

    for name, body in [('click', 240), ('select', 310)]:
        t = timeline(.085)
        tap = (air(t, 1700) * .25 + np.sin(2 * np.pi * body * t))
        write(name, tap * (1 - np.exp(-t * 1600)) * np.exp(-t * 75), .19)

    t = timeline(.95)
    # Лёгкое арпеджио и короткий воздушный акцент после размещения.
    place = sum(mallet(t, onset, note, strength) for onset, note, strength in
                [(0, 523.251, .8), (.09, 659.255, .65), (.19, 1046.502, .5)])
    place += .08 * air(t) * np.sin(np.pi * np.minimum(t / .35, 1)) ** 2 * np.exp(-t * 5)
    write('place', place, .34)

    t = timeline(.7)
    construction = .05 * air(t, 1400) * (1 - np.exp(-t * 35)) * np.exp(-t * 8)
    for onset, frequency in [(0, 150), (.13, 205), (.28, 180)]:
        local = np.maximum(0, t - onset)
        construction += .35 * np.sin(2 * np.pi * frequency * local) * np.exp(-local * 40) * (t >= onset)
    write('build', construction, .13)

    t = timeline(.65)
    write('success', mallet(t, 0, 659.255) + mallet(t, .11, 783.991, .7), .25)
    t = timeline(1.15)
    write('level_up', sum(mallet(t, onset, note, strength) for onset, note, strength in
                         [(0, 523.251, .8), (.1, 659.255, .7), (.2, 783.991, .6), (.32, 1046.502, .5)]), .3)
    t = timeline(.10)
    write('cancel', air(t, 1200) * np.exp(-t * 45), .12)
    t = timeline(.17)
    write('deny', np.sin(2 * np.pi * 155 * t) * np.sin(np.pi * t / .17) ** 2 * np.exp(-t * 16), .15)
    t = timeline(.65)
    # Негромкий хлопок/шорох реакции вместо синтетического «голоса».
    reaction = sum(air(t, 2100) * np.exp(-np.maximum(0, t - onset) * 65) * (t >= onset)
                   for onset in [.03, .19, .4])
    write('reaction', reaction, .12)
    print('Generated 9 original feedback WAV files; city.wav is left untouched')


if __name__ == '__main__':
    render()
