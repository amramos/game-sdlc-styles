# Web snippets (three.js 0.160.0)

`demo.html` is the full working scene; these are the parts a prototype copies. Pin the exact
version in the import map:

```html
<script type="importmap">
{ "imports": {
  "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
  "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
} }
</script>
```

**Renderer:** ACES filmic tone mapping (applied by `OutputPass` at the end of the chain), soft
shadows, `preserveDrawingBuffer` so frames can be captured.

```js
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;          // 1.05 for the candlelit scheme
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
```

**Painted wood:** one material per palette role, paint × a neutral grain canvas, matte, flat.

```js
function grainTexture(rnd) {                  // 256², mean value about 0.9, wraps vertically
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const x = c.getContext('2d'); x.fillStyle = '#ececec'; x.fillRect(0, 0, 256, 256);
  for (let i = 0; i < 90; i++) {
    const y0 = rnd() * 256, a = 4 * (0.4 + rnd()), f = 1 + Math.floor(rnd() * 3), ph = rnd() * 6.283, g = 140 + (rnd() * 70 | 0);
    x.strokeStyle = `rgba(${g},${g},${g},${0.22 * (0.5 + rnd())})`; x.lineWidth = 1 + rnd();
    for (const dy of [-256, 0, 256]) { x.beginPath();
      for (let px = 0; px <= 256; px += 8) x.lineTo(px, y0 + dy + Math.sin(px / 256 * 6.283 * f + ph) * a);
      x.stroke(); }
  }
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(2, 2); t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
const GRAIN = grainTexture(rnd), mats = {};
const paint = (role, rough = 0.8) => mats[role + rough] ??= new THREE.MeshStandardMaterial({
  color: palette[role], map: GRAIN, roughness: rough, metalness: 0, flatShading: true });
// bare wood: paint('wood-bare', 0.9)
```

**Knife facets:** jitter vertices by a seeded offset hashed from their position, so shared corners
stay shut; flat shading turns the jitter into uneven facets.

```js
function carve(g, amt) {                      // amt = 2–4% of the piece's size
  if (g.index) g = g.toNonIndexed();
  const p = g.attributes.position, offs = new Map();
  for (let i = 0; i < p.count; i++) {
    const k = `${p.getX(i).toFixed(3)},${p.getY(i).toFixed(3)},${p.getZ(i).toFixed(3)}`;
    if (!offs.has(k)) offs.set(k, [0, 1, 2].map(() => (rnd() - 0.5) * 2 * amt));
    const o = offs.get(k); p.setXYZ(i, p.getX(i) + o[0], p.getY(i) + o[1], p.getZ(i) + o[2]);
  }
  g.computeVertexNormals();
  return g;
}
const head = new THREE.Mesh(carve(new THREE.IcosahedronGeometry(0.068, 1), 0.005), paint('wood-bare', 0.9));
```

**Lights.** Since r155 lights are physical: a directional light at intensity π gives a face its full
albedo. The numbers below are the demo's three schemes.

```js
const hemi = new THREE.HemisphereLight(palette.fill, new THREE.Color(palette.table).multiplyScalar(0.5), 2.0);
// day: a directional key, fill 2.0 (sunny) or 1.6 (low morning window)
const sun = new THREE.DirectionalLight(palette.key, 3.0);
sun.position.set(-6, 7.5, 3);                 // morning: (-8, 4.5, -1), intensity 3.2
sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -7, right: 7, top: 6, bottom: -6, near: 0.5, far: 40 });
sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.02;
// night: a lamp spot from above, fill 6.0 on a dark fill colour, a candle as a practical
const spot = new THREE.SpotLight(palette.key, 95, 0, 0.9, 0.6, 1.6);   // intensity, distance, angle, penumbra, decay
spot.position.set(0.4, 8.4, 0.6); spot.target.position.set(0, 0, -0.5);
spot.castShadow = true; spot.shadow.mapSize.set(2048, 2048); spot.shadow.bias = -0.0004;
const candle = new THREE.PointLight(0xffb070, 5, 7, 1.6);
// flicker, flames only: k = 0.97 + 0.03 * sin(7.3t) * sin(2.1t); spot.intensity = 95 * k
```

**Room and fog:** `scene.background = new THREE.Color(palette.room)`;
`scene.fog = new THREE.Fog(palette.room, 15, 28)` for a camera 10.8 units from the base (14–23 at
night, when the room should swallow the table sooner).

**Post chain:** guard, bloom, tilt-shift with vignette and grade, output.

```js
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

const VS = 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }';
const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 }));
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new ShaderPass({ uniforms: { tDiffuse: { value: null } }, vertexShader: VS, fragmentShader: `
  uniform sampler2D tDiffuse; varying vec2 vUv;
  void main(){ vec4 c = texture2D(tDiffuse, vUv);
    if (any(isnan(c)) || any(isinf(c))) c = vec4(0.0);
    gl_FragColor = clamp(c, 0.0, 40.0); }` }));
// strength, radius, threshold: day 0.15 / 0.7 / 1.4, night 0.55 / 0.7 / 0.82
composer.addPass(new UnrealBloomPass(new THREE.Vector2(w, h), 0.15, 0.7, 1.4));
const lens = new ShaderPass({
  uniforms: { tDiffuse: { value: null }, res: { value: new THREE.Vector2(w, h) }, focus: { value: 0.46 },
              amount: { value: 5 * h / 720 }, vig: { value: 0.3 }, grade: { value: new THREE.Vector3(1.03, 1.0, 0.95) },
              gradeAmt: { value: 0.6 } },
  vertexShader: VS, fragmentShader: `
  uniform sampler2D tDiffuse; uniform vec2 res; uniform float focus, amount, vig, gradeAmt; uniform vec3 grade; varying vec2 vUv;
  void main(){
    float d = vUv.y - focus;
    float b = d > 0.0 ? smoothstep(0.1, 0.5, d) : 0.3 * smoothstep(0.2, 0.55, -d);
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 16; i++) { float fi = float(i), a = fi * 2.39996;
      acc += texture2D(tDiffuse, vUv + vec2(cos(a), sin(a)) * sqrt(fi / 16.0) * b * amount / res); }
    vec4 c = acc / 16.0;
    float v = smoothstep(1.05, 0.25, length((vUv - vec2(0.5, 0.52)) * vec2(1.1, 1.25)));
    c.rgb *= mix(1.0, v, vig);                          // 0.3 by day, 0.85 at night
    c.rgb = mix(c.rgb, c.rgb * grade, gradeAmt);        // night grade (1.06, 0.98, 0.86)
    gl_FragColor = c; }` });
composer.addPass(lens);
composer.addPass(new OutputPass());                     // tone mapping and sRGB happen here
```

Set `res` to the drawing-buffer size (CSS size × pixel ratio) and scale `amount` with its height.
Halve `amount` for close-ups.

**Live text on cards and signs in the scene:** draw it into a canvas texture with the palette's
`paper` and `ink`, and redraw it when the palette changes; see `label()` in `demo.html`. Text the
player must read lives in HTML paper cards over the canvas.

**Accent ring:** `RingGeometry(1.1 r, 1.1 r + 0.04, 48)` in a `MeshBasicMaterial` of `accent`,
`depthWrite: false`, polygon offset −2/−4, 0.02 above the surface it marks.

**Render loop:** render at about 10 fps when idle (the sway and flicker are slow), at full rate for
300 ms after input, and stop when `document.hidden`. See `loop()` in `demo.html`.
