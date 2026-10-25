"""Generate the original, language-neutral emergency radio alert cue."""
import math
import random
import wave
from pathlib import Path

RATE = 22050
random.seed(911)
samples = []
for index in range(int(RATE * 0.92)):
    time_value = index / RATE
    if time_value < 0.16 or 0.78 < time_value < 0.92:
        envelope = min(1.0, time_value / 0.025, (0.16 - time_value) / 0.025) if time_value < 0.16 else min(1.0, (time_value - 0.78) / 0.025, (0.92 - time_value) / 0.025)
        sample = random.uniform(-0.16, 0.16) * max(0.0, envelope)
    elif 0.2 <= time_value <= 0.72:
        pulse = (time_value - 0.2) / 0.52
        frequency = 720.0 if pulse < 0.52 else 940.0
        envelope = min(1.0, (time_value - 0.2) / 0.03, (0.72 - time_value) / 0.04)
        sample = 0.2 * max(0.0, envelope) * math.sin(math.tau * frequency * time_value)
    else:
        sample = 0.0
    samples.append(max(-1.0, min(1.0, sample)))

output = Path(__file__).resolve().parents[1] / "assets" / "audio" / "radio_call.wav"
with wave.open(str(output), "wb") as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(RATE)
    audio.writeframes(b"".join(int(value * 32767).to_bytes(2, "little", signed=True) for value in samples))
print(output)
