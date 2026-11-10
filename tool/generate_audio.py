"""Original Muskaan procedural tones. Outputs dedicated to CC0-1.0."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
def render(path, notes, duration):
    rate = 22050
    samples = []
    for frequency in notes:
        count = int(rate * duration)
        for i in range(count):
            t = i / rate
            envelope = min(1, i / 220, (count - 1 - i) / 440)
            samples.append(int(7000 * envelope * math.sin(2 * math.pi * frequency * t)))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))

sounds = ['catchFood','miss','hazard','combo','bonus','countdown','start','pause','resume','gameOver','best','achievement','challenge','level','cosmetic','tap']
for index, sound in enumerate(sounds):
    render(ROOT / 'sfx' / (sound + '.wav'), [330 + index * 22, 440 + index * 22], .07)
render(ROOT / 'music/menu.wav', [261.63,329.63,392,329.63,293.66,349.23,440,349.23]*4, .4)
render(ROOT / 'music/gameplay.wav', [392,493.88,587.33,493.88,440,523.25,659.25,523.25]*4, .25)
render(ROOT / 'music/results.wav', [523.25,659.25,783.99,659.25,587.33,698.46,880,698.46]*4, .35)
