"""Обработка разрешённой полевой записи. Для сборки игры Python не нужен.

Python + numpy + soundfile; исходный HQ MP3:
https://cdn.freesound.org/previews/135/135074_658546-hq.mp3
Автор mzui, Freesound 135074, CC0-1.0; см. assets/audio/LICENSES.md.
"""
import argparse
import hashlib
import wave
from pathlib import Path

import numpy as np
import soundfile as sf


def prepare(source, destination):
    audio, rate = sf.read(source, always_2d=True)
    audio = audio[int(3 * rate):int(73 * rate), :2]
    audio -= audio.mean(axis=0)
    frequencies = np.fft.rfftfreq(len(audio), 1 / rate)
    # Убираем инфранизкий гул и смягчаем резкие верхние частоты.
    response = (1 / (1 + (80 / np.maximum(frequencies, .01)) ** 4)
                / (1 + (frequencies / 8500) ** 8))
    audio = np.fft.irfft(np.fft.rfft(audio, axis=0) * response[:, None],
                        n=len(audio), axis=0)
    overlap = int(6 * rate)
    phase = np.linspace(0, np.pi / 2, overlap, endpoint=True)[:, None]
    seam = audio[-overlap:] * np.cos(phase) + audio[:overlap] * np.sin(phase)
    audio = np.concatenate((audio[overlap:-overlap], seam))
    gain = min(.09 / np.sqrt(np.mean(audio ** 2)), .4 / np.max(np.abs(audio)))
    audio *= gain
    output_rate = 22050
    indices = np.arange(int(len(audio) * output_rate / rate)) * rate / output_rate
    audio = np.stack([np.interp(indices, np.arange(len(audio)), channel)
                      for channel in audio.T], axis=1)
    with wave.open(str(destination), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(output_rate)
        out.writeframes((audio * 32767).astype('<i2').tobytes())
    print(f'city.wav: {len(audio) / output_rate:.2f}s stereo; '
          f'peak {np.max(np.abs(audio)):.3f}; seam jump '
          f'{np.max(np.abs(audio[-1] - audio[0])):.6f}')
    print('source SHA256:', hashlib.sha256(Path(source).read_bytes()).hexdigest())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    arguments = parser.parse_args()
    prepare(arguments.source, Path(__file__).resolve().parents[1] / 'assets/audio/city.wav')
