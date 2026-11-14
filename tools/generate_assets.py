"""Generate the addon's original anti-aliased circular border (no external assets)."""
from pathlib import Path
import math
import struct

size = 64
pixels = bytearray()
for y in range(size):
    for x in range(size):
        r = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2)
        alpha = max(0.0, min(1.0, r - 25.0, 30.0 - r))
        pixels.extend((255, 255, 255, round(alpha * 255)))
header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
path = Path(__file__).resolve().parents[1] / 'Media/Ring.tga'
path.parent.mkdir(parents=True, exist_ok=True)
path.write_bytes(header + pixels)
print(f'Generated {path}: {size}x{size}, 32-bit BGRA, {path.stat().st_size} bytes')
