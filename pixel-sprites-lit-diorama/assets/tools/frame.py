# Crop each keyed figure to its silhouette and place it on a 32x48-proportioned frame at a
# scale where the figure is exactly `h` sprite pixels tall, feet on row 46 (0-based).
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
B = 24  # source pixels per sprite pixel in the framed image
targets = {'elder': 46, 'shopper': 43, 'vendor': 44, 'kid': 34}
for n, h in targets.items():
    im = Image.open(f'keyed/{n}.png').convert('RGBA'); a = np.array(im)
    m = a[..., 3] > 127
    lab, k = ndimage.label(m); sizes = ndimage.sum(m, lab, range(1, k + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 2000])
    a[~keep] = 0
    ys, xs = np.where(keep); y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    fig = Image.fromarray(a[y0:y1, x0:x1])
    s = h * B / (y1 - y0)
    fig = fig.resize((max(1, round(fig.width * s)), h * B), Image.NEAREST)
    out = Image.new('RGBA', (32 * B, 48 * B), (0, 0, 0, 0))
    out.paste(fig, ((32 * B - fig.width) // 2 // B * B, (47 - h) * B), fig)
    out.save(f'framed/{n}.png'); print(n, (y1 - y0), 'src px ->', h, 'width', fig.width / B)
