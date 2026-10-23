"""Генерация служебных семплов и собственных откликов. Для откликов нужен numpy.

city.wav — полевая запись; этот скрипт никогда её не перезаписывает.
"""
import math
import random
import wave
from pathlib import Path
from generate_feedback_audio import render

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
rng = random.Random(42)


def write(name, duration, generator, loop=False):
    count = int(RATE * duration)
    data = bytearray()
    for i in range(count):
        t = i / RATE
        fade = 1 if loop else min(1, t / .025, (duration - t) / .08)
        value = max(-1, min(1, generator(t) * fade))
        data.extend(int(value * 26000).to_bytes(2, 'little', signed=True))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data)


def noise():
    return rng.uniform(-1, 1)


def tone(t, frequency):
    return math.sin(math.tau * frequency * t)


write('siren', .65, lambda t: .07 * tone(t, 620 + 160 * math.sin(t * 14)))
write('engine', 2, lambda t: .10 * tone(t, 66) + .04 * tone(t, 132) + .015 * noise(), True)
write('water', 2, lambda t: .13 * noise() * (.6 + .25 * math.sin(t * math.tau * 5)), True)
write('repair', 2, lambda t: .12 * noise() * (1 if t % .32 < .08 else .08), True)
write('leaves', 1.8, lambda t: .12 * noise() * (.55 + .4 * math.sin(t * 5)))
write('warning', .3, lambda t: .08 * tone(t, 820) * math.exp(-t * 9))
render()
print('Generated service and feedback WAV files; field ambience preserved')
