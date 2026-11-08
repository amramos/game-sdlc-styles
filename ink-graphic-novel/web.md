# Web snippets (canvas 2D; optional three.js 0.160.0)

`demo.html` is a working starter in plain canvas 2D, no libraries: brush contours, black masses by
offset copy, hatching, captions with measured wrapping, status icons, paper slips, sound words, notes and a palette
switcher. These are the parts a prototype copies.

**Palette as role constants** (names from `style.md`, hexes from the game's `.gpl`):

```js
const ROLES = ['ink', 'paper', 'field-1', 'field-2', 'field-3', 'accent', 'signal-alert', 'signal-ok'];
const P = { ink: '<ink>', paper: '<paper>', 'field-1': '<field-1>' /* … every role */ };
const LIGHT = [-0.6, -0.8];   // key light direction on screen (upper left)
```

**Black mass:** the shape minus a copy moved toward the light, filled with ink. One clip and one
even-odd fill:

```js
function crescent(pts, dx, dy, col) {
  const b = bbox(pts), m = Math.abs(dx) + Math.abs(dy) + 20;
  ctx.save(); path(pts); ctx.clip();
  ctx.beginPath(); ctx.rect(b.x0 - m, b.y0 - m, b.x1 - b.x0 + 2 * m, b.y1 - b.y0 + 2 * m);
  ctx.moveTo(pts[0][0] + dx, pts[0][1] + dy);
  for (const [x, y] of pts.slice(1)) ctx.lineTo(x + dx, y + dy);
  ctx.closePath(); ctx.fillStyle = col; ctx.fill('evenodd'); ctx.restore();
}
// shadow: crescent(pts, LIGHT[0] * size * 0.22, LIGHT[1] * size * 0.22, P.ink)
// rim:    crescent(pts, -towardLight[0] * 6, -towardLight[1] * 6, P.accent)
```

**Brush contour:** one filled quad per segment and a dab per point, so the width can change along
the line. Fill each piece on its own path: quads and arcs in one path can wind in opposite
directions and cut holes.

```js
function strokeVar(pts, ws, closed, col) {
  ctx.fillStyle = col;
  const n = pts.length;
  for (let i = 0; i < (closed ? n : n - 1); i++) {
    const a = pts[i], b = pts[(i + 1) % n], L = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
    const nx = -(b[1] - a[1]) / L, ny = (b[0] - a[0]) / L, wa = ws[i] / 2, wb = ws[(i + 1) % n] / 2;
    ctx.beginPath(); ctx.moveTo(a[0] + nx * wa, a[1] + ny * wa); ctx.lineTo(b[0] + nx * wb, b[1] + ny * wb);
    ctx.lineTo(b[0] - nx * wb, b[1] - ny * wb); ctx.lineTo(a[0] - nx * wa, a[1] - ny * wa); ctx.fill();
  }
  pts.forEach((p, i) => { ctx.beginPath(); ctx.arc(p[0], p[1], ws[i] / 2, 0, Math.PI * 2); ctx.fill(); });
}
// contour widths: heavier where the outward normal faces away from the light
const c = centroid(pts);
const ws = pts.map(p => { const nx = p[0] - c[0], ny = p[1] - c[1], L = Math.hypot(nx, ny) || 1;
  const away = Math.max(0, -(nx * LIGHT[0] + ny * LIGHT[1]) / L);
  return (wMin + (wMax - wMin) * away * away) * (0.88 + 0.24 * rand()); });
```

The centroid normal suits blob-like shapes; for long concave shapes, use the segment normal instead.
Build shapes from a few control points through a Catmull-Rom spline (`smooth()` in `demo.html`)
so they read as brushed rather than polygonal.

**Hatching:** clip to the region, then one path of parallel lines.

```js
function hatch(pts, spacing = 8, angle = -0.85, w = 2) {
  ctx.save(); path(pts); ctx.clip();
  const b = bbox(pts), cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2;
  const R = Math.hypot(b.x1 - b.x0, b.y1 - b.y0) / 2, ca = Math.cos(angle), sa = Math.sin(angle);
  ctx.beginPath();
  for (let d = -R; d <= R; d += spacing) {
    ctx.moveTo(cx - ca * R - sa * d, cy - sa * R + ca * d); ctx.lineTo(cx + ca * R - sa * d, cy + sa * R + ca * d);
  }
  ctx.lineWidth = w; ctx.strokeStyle = P.ink; ctx.stroke(); ctx.restore();
}
```

**Caption box** (the one frame style). Measure and wrap with `ctx.measureText`; the box grows by
whole lines:

```js
ctx.fillStyle = P.ink;   ctx.fillRect(x + 5, y + 5, w, h);          // hard offset shadow
ctx.fillStyle = P.paper; ctx.fillRect(x, y, w, h);
ctx.lineWidth = 3; ctx.strokeStyle = P.ink; ctx.strokeRect(x + 1.5, y + 1.5, w - 3, h - 3);
```

As HTML over the canvas, the same box:

```css
.cap { background: var(--paper); color: var(--ink); border: 3px solid var(--ink);
  box-shadow: 5px 5px 0 var(--ink); padding: 10px; text-transform: uppercase;
  font: 700 20px/1.22 var(--lettering); }
.cap.focus { background: var(--ink); color: var(--paper); border-color: var(--paper); }
.cap:active { transform: translate(3px, 3px); box-shadow: 2px 2px 0 var(--ink); }
```

**Sound word:** ink copy offset, then an ink stroke under a paper fill.

```js
ctx.font = `small-caps 700 ${fs}px <title face>`; ctx.lineJoin = 'round';
ctx.fillStyle = P.ink; ctx.fillText(t, 6, 6);
ctx.lineWidth = 8; ctx.strokeStyle = P.ink; ctx.strokeText(t, 0, 0);
ctx.fillStyle = P.paper; ctx.fillText(t, 0, 0);
```

**Fonts:** a hand-lettered face for captions and a small-caps serif for titles, shipped with the
game (`@font-face` from a local file, licence checked). The demo bundles its own in `assets/fonts/`
(Comic Neue, Alegreya, Arimo; all OFL) and loads them before the first canvas text draw:

```css
@font-face { font-family: "Comic Neue"; src: url(assets/fonts/ComicNeue-Bold.woff) format("woff"); font-weight: 700; }
@font-face { font-family: "Alegreya"; src: url(assets/fonts/Alegreya-Bold.woff) format("woff"); font-weight: 700; }
```

```js
await Promise.all(['700 16px "Comic Neue"', '400 16px "Comic Neue"', '700 16px "Alegreya"',
  '400 16px Arimo'].map(f => document.fonts.load(f)));
```

**Ramp swap per chapter** on an `ImageData`, protecting the accent:

```js
for (let i = 0; i < d.length; i += 4) {
  const r = d[i], g = d[i + 1], b = d[i + 2];
  if (isAccent(r, g, b)) continue;                  // hue within 25° of the accent, chroma > 0.45
  const L = (0.3 * r + 0.55 * g + 0.15 * b) / 255, f = Math.min(2.999, L * 3.2), k = f | 0, t = f - k;
  const A = ramp[k], B = ramp[k + 1];               // ramp = [ink, field-1, field-2, field-3] as RGB
  d[i] = A[0] + (B[0] - A[0]) * t; d[i + 1] = A[1] + (B[1] - A[1]) * t; d[i + 2] = A[2] + (B[2] - A[2]) * t;
}
```

**Loop:** draw on input and while something moves; otherwise `setInterval(step, 100)` (10 fps)
for particles and the accent's flicker, stopped on `visibilitychange` when `document.hidden`.

## Toon 3D in ink (three.js 0.160.0)

Only for a few 3D objects inside a panel. Pin the exact version:

```html
<script type="importmap">
{ "imports": { "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js" } }
</script>
```

```js
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, preserveDrawingBuffer: true });
renderer.toneMapping = THREE.NoToneMapping;
const camera = new THREE.PerspectiveCamera(30, w / h, 1, 90);

// 3-step light
const steps = new THREE.DataTexture(new Uint8Array([70, 160, 255]), 3, 1, THREE.RedFormat);
steps.minFilter = steps.magFilter = THREE.NearestFilter; steps.needsUpdate = true;
const toon = color => new THREE.MeshToonMaterial({ color, gradientMap: steps });

// inverted-hull outline: a back-face copy in ink, scaled up 3.5-8% per part
function inked(mesh, grow = 0.05) {
  const hull = new THREE.Mesh(mesh.geometry, new THREE.MeshBasicMaterial({ color: P.ink, side: THREE.BackSide }));
  hull.scale.setScalar(1 + grow); mesh.add(hull); return mesh;
}
```

Post pass: render the scene to a `WebGLRenderTarget` with a `DepthTexture`, then a full-screen
`ShaderMaterial` (linearise depth with the camera's near and far first):

```glsl
float e = 0.0;                                     // depth-edge ink
for (int i = 0; i < 4; i++) e = max(e, abs(linDepth(vUv + off[i] * 1.3 * px) - linDepth(vUv)));
e = smoothstep(0.10, 0.22, e);
vec3 c = pow(texture2D(tColor, vUv).rgb, vec3(1.0 / 2.2));
float l = max(max(c.r, c.g), c.b); vec3 hue = c / max(l, 0.001);
c = hue * floor(l * 5.0 + 0.5) / 5.0;              // posterise, keeping hue
c += hash(floor(vUv * res / 1.5) + floor(t * 8.0)) * 0.06 - 0.03;   // optional print grain
gl_FragColor = vec4(mix(c, inkRGB, e), 1.0);
```

Light it with one `DirectionalLight` from the game's key direction and a low `AmbientLight`
(ambient : key about 1 : 2); a focal light is a `PointLight` with short `distance` beside an unlit
`MeshBasicMaterial` in the accent, so its spill stays local.
