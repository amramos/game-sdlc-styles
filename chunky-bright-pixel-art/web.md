# Web snippets (prototype)

HTML canvas 2D, no libraries. `demo.html` is a working starter: an indexed frame buffer, the 3×5
font, auto-outlined sprites and integer presentation.

**Palette as role constants** (names from `style.md`; hexes from the game's `.gpl`):

```js
const ROLES = ['ink', 'paper', 'accent', 'signal-good', 'signal-bad', 'signal-rare',
  'warm-1', 'warm-2', 'warm-3', 'warm-4', 'cool-1', 'cool-2', 'cool-3', 'cool-4', 'bg-sky', 'bg-far'];
const PALETTE = { ink: '<ink>', paper: '<paper>', accent: '<accent>' /* … every role */ };
const R = Object.fromEntries(ROLES.map((r, i) => [r, i]));
```

**Draw into an indexed buffer at the base resolution;** look colours up only when presenting, so a
palette swap is one table and nothing goes off palette:

```js
const W = 320, H = 180, buf = new Uint8Array(W * H);
const px = (x, y, role) => { x = Math.round(x); y = Math.round(y);
  if (x >= 0 && y >= 0 && x < W && y < H) buf[y * W + x] = role; };
```

**Integer scaling in device pixels, smoothing off:**

```js
function present(view, base) {                 // base: a W×H canvas holding the frame
  const dpr = devicePixelRatio || 1;
  const k = Math.max(1, Math.floor(Math.min(innerWidth * dpr / W, innerHeight * dpr / H)));
  view.width = W * k; view.height = H * k;
  view.style.width = W * k / dpr + 'px'; view.style.height = H * k / dpr + 'px';
  const ctx = view.getContext('2d');
  ctx.imageSmoothingEnabled = false;           // set again after every resize: it resets
  ctx.drawImage(base, 0, 0, W * k, H * k);
}
```

```css
canvas { image-rendering: pixelated; }         /* belt and braces for CSS scaling */
body   { background: var(--ink); }            /* the border left by integer scaling */
```

**Pixel-snapped camera:** round the camera, then subtract it from rounded world positions.

```js
cam.x += (target.x - cam.x) * 0.15;            // float follow
const cx = Math.round(cam.x), cy = Math.round(cam.y);
drawSprite(s, Math.round(e.x) - cx, Math.round(e.y) - cy);
```

**Outline by code:** grow each sprite by 1 px and set every empty pixel that touches a filled one
(4-neighbour) to `ink` (see `outline()` in `demo.html`).

**Loop:** `setInterval(step, 100)` for a 10 fps showcase or `requestAnimationFrame` with a fixed
60 Hz step for play; stop it on `visibilitychange` when `document.hidden`.

Text: draw the bitmap font into the same buffer. `ctx.fillText` with a system font is anti-aliased
and off the grid; if it is unavoidable, use a pixel font file at an exact multiple of its design size
and integer coordinates.

The demo bundles its fonts in `assets/fonts/` (Silkscreen for the `dont` frame's off-grid text,
JetBrains Mono for the page controls); a game picks its own.
