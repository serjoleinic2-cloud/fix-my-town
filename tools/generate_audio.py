"""Генерация временных оригинальных семплов. Только стандартная библиотека Python."""
import math
import random
import wave
from pathlib import Path

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


write('click', .10, lambda t: .14 * tone(t, 540) * math.exp(-t * 40))
write('select', .16, lambda t: .14 * tone(t, 660 + t * 700) * math.exp(-t * 16))
write('deny', .22, lambda t: .12 * tone(t, 160) * math.exp(-t * 10))
write('cancel', .16, lambda t: .12 * tone(t, 520 - t * 1300) * math.exp(-t * 16))
write('success', .65, lambda t: .14 * tone(t, [523, 659, 784][min(2, int(t * 5))]) * math.exp(-t * 2))
write('level_up', 1.1, lambda t: .15 * (tone(t, 523) + tone(t, 659) + tone(t, 784)) / 3 * math.sin(math.pi * t / 1.1))
write('siren', .65, lambda t: .07 * tone(t, 620 + 160 * math.sin(t * 14)))
write('engine', 2, lambda t: .10 * tone(t, 66) + .04 * tone(t, 132) + .015 * noise(), True)
write('water', 2, lambda t: .13 * noise() * (.6 + .25 * math.sin(t * math.tau * 5)), True)
write('repair', 2, lambda t: .12 * noise() * (1 if t % .32 < .08 else .08), True)
write('build', .65, lambda t: .15 * noise() * math.exp(-(t % .2) * 30))
write('leaves', 1.8, lambda t: .12 * noise() * (.55 + .4 * math.sin(t * 5)))
write('reaction', .8, lambda t: .06 * (tone(t, 290 + 25 * math.sin(t * 15)) + tone(t, 440 + 18 * math.sin(t * 12))))
write('city', 4, lambda t: .03 * noise() + .025 * tone(t, 55) * (.6 + .4 * math.sin(math.tau * t / 4)), True)
write('birds', 4, lambda t: .045 * tone(t, 1700 + 400 * math.sin(t * math.tau * 5)) * max(0, math.sin(t * math.tau / 2)) ** 12, True)
write('warning', .3, lambda t: .08 * tone(t, 820) * math.exp(-t * 9))
print('Generated 16 original temporary WAV files')
