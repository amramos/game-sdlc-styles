# Web snippets (prototype)

Canvas 2D, no libraries: a bloom pass built from offscreen canvases, `ctx.filter = 'blur()'` and
`globalCompositeOperation = 'lighter'`. `demo.html` uses exactly these and is the working
reference. Values below are at 720p, as in the demo (two thirds of the recipe's 1080p numbers).

**Draw in one logical resolution** and scale the backing store, so line widths stay in screen px:

```js
const W = 1280, H = 720;
function fit() {
  const s = Math.min(innerWidth / W, innerHeight / H), dpr = devicePixelRatio || 1;
  canvas.style.width = W * s + 'px'; canvas.style.height = H * s + 'px';
  canvas.width = Math.round(W * s * dpr); canvas.height = Math.round(H * s * dpr);
  ctx.setTransform(canvas.width / W, 0, 0, canvas.width / W, 0, 0);
}
```

**Glow: two layers, blurred three times.** Inside a glow pass, every glowing path is stroked on a
*line* layer (colour core, then a near-white centre, normal blend) and on a *bloom source* (pure
colour, a little wider, additive). `endGlow` blurs the source at three radii, adds each copy with a
gain above 1, then lays the line layer on top. Wide blurs run on quarter-size canvases.

```js
const LN = layer(), BL = layer(), TMP = { 1: layer(), 0.5: layer(), 0.25: layer() };  // sized in fit()
const BLOOM = {   // r: blur px at 720p; g: gain (copies added); s: working resolution
  world:  [{ r: 2, g: 1.2, s: 1 }, { r: 7, g: 1.8, s: 0.5 }, { r: 24, g: 3.2, s: 0.25 }],
  danger: [{ r: 2, g: 1.0, s: 1 }, { r: 6, g: 1.2, s: 0.5 }],
  hud:    [{ r: 1.5, g: 0.55, s: 1 }, { r: 5, g: 0.45, s: 0.5 }],
};
function glowStroke(path, col, w, k = 1) {      // k: bloom strength (0.55 small pickups, 1.3 player)
  const b = BL.x;                               // copy ctx's transform, dash and alpha to b first
  b.globalCompositeOperation = 'lighter'; b.globalAlpha = Math.min(1, k);
  b.strokeStyle = col; b.lineWidth = w + 2 * k; b.stroke(path);
  ctx.lineJoin = ctx.lineCap = 'round';         // ctx is the line layer during a pass
  ctx.strokeStyle = col; ctx.lineWidth = w; ctx.stroke(path);
  ctx.strokeStyle = mix(col, '#FFFFFF', 0.75); ctx.lineWidth = Math.max(1, w * 0.45); ctx.stroke(path);
}
function endGlow(spec, src = BL) {              // src = LN for HUD text: blur the crisp layer itself
  ctx = MAIN; MAIN.save(); MAIN.setTransform(1, 0, 0, 1, 0, 0);
  MAIN.globalCompositeOperation = 'lighter';
  for (const { r, g, s } of spec) {
    const T = TMP[s]; T.x.clearRect(0, 0, T.c.width, T.c.height);
    T.x.filter = `blur(${r * K * s}px)`; T.x.drawImage(src.c, 0, 0, T.c.width, T.c.height); T.x.filter = 'none';
    for (let a = g; a > 0.01; a -= 1) { MAIN.globalAlpha = Math.min(1, a); MAIN.drawImage(T.c, 0, 0, cv.width, cv.height); }
  }
  MAIN.globalAlpha = 1; MAIN.globalCompositeOperation = 'source-over';
  MAIN.drawImage(LN.c, 0, 0); MAIN.restore();
}
```

Order per frame: void, grid (never in a pass), world pass (sparks, pickups, core, shots, enemies,
player, hazards) → `endGlow(BLOOM.world)`, a void disc around each enemy shot, a danger pass →
`endGlow(BLOOM.danger)`, the edge fade, a HUD pass → `endGlow(BLOOM.hud, LN)`. Avoid `shadowBlur`
for glow: it is slow over many strokes and doesn't add like light. Cost at 1280×720: three blurs
per pass, two of them at reduced size; fine on a GPU-backed canvas at 60 fps.

**Sparks:** additive on the line layer, and into the bloom source at 60%; a line back along the velocity.

```js
ctx.globalCompositeOperation = 'lighter'; ctx.lineWidth = 1.5;
for (const p of sparks) {
  ctx.strokeStyle = p.col; ctx.globalAlpha = 0.8 * p.life / p.max;
  ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.035, p.y - p.vy * 0.035); ctx.stroke();
}
// update: p.x += p.vx * dt; p.vx *= Math.pow(0.05, dt); p.life -= dt;
```

**Grid:** a spring mesh in `Float32Array`s (position and velocity per axis), stepped at a fixed
1/60 s with the recipe's constants (anchor `0.025`, neighbour `0.06`, damping `0.07`; spacing 40 px
and offset cap 24 px at 720p). Draw all minor lines as one `Path2D` and all major lines as another
(two `stroke()` calls), then add warped segments one by one with `'lighter'`.

**Danger rim:** after the world bloom, fill a circle in the void colour 4 px larger than the shot, then draw the shots in their own pass.

**Flash limiter:**

```js
function requestFlash(alpha) {
  flashes = flashes.filter(t => now - t < 1);
  if (reducedFlash || flashes.length >= 3) return false;
  flashes.push(now); flash = Math.min(0.15, alpha); return true;
}
```

**Idle cost:** run at ~10 fps (`setTimeout(tick, 100)`) when there has been no input for 2 s, switch
to `requestAnimationFrame` on input, and stop on `visibilitychange` when hidden.

**HUD:** draw last in its own pass with the tight `BLOOM.hud`, no panels, over a void fade from the
top edge (`createLinearGradient`, void at 0.85 to 0 over 112 px); `ctx.letterSpacing` for labels.
The demo bundles its fonts in `assets/fonts/` (Open Sans for words, Cascadia Mono for numbers) and
loads every face before the first word is drawn, since a canvas doesn't redraw when a font arrives:

```js
// CSS: @font-face { font-family: "Cascadia Mono"; src: url(assets/fonts/CascadiaMono-Bold.woff) format("woff"); font-weight: 700; }
const F_BODY = '"Open Sans", sans-serif', F_NUM = '"Cascadia Mono", monospace';
await Promise.all(['400 16px "Open Sans"', '700 16px "Cascadia Mono"' /* … each face used */]
  .map(f => document.fonts.load(f)));
```

Captures for the catalog are PNG; save them with `optimize=True`, since bloom gradients compress
worse than flat lines.

**If you use three.js instead:** three@0.160.0 with `EffectComposer`, `RenderPass`,
`UnrealBloomPass(resolution, 0.8, 0.4, 0.85)` (strength, radius, threshold) and `OutputPass`; lines
as `Line2` from `three/addons/lines/` (plain `LineBasicMaterial` ignores line width); materials with
`toneMapped: false` and colours scaled ×2 so only the cores pass the threshold (check that the inner halo and the wide bloom both show, as in the canvas version); the HUD as HTML over
the canvas. The demo doesn't use this path, so it is untested here.
