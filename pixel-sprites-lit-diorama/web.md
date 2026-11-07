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

**Renderer:** no tone mapping, so palette colours land as authored; soft shadows; a 4×
multisampled half-float target for the post chain.

```js
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.toneMapping = THREE.NoToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
const rt = new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 });
```

**A pixel sprite standing in the lit world,** drawn from a character grid (`o` outline, `s` skin,
upper case = shaded) and lit by tint:

```js
const PX = 1.8 / 24;                                    // world units per sprite pixel
const c = document.createElement('canvas'); c.width = 16; c.height = 24;
const x = c.getContext('2d');
rows.forEach((r, j) => [...r].forEach((ch, i) => {
  if (ch === '.') return;
  const col = new THREE.Color(palette[ROLE[ch.toLowerCase()]]);
  if (ch !== ch.toLowerCase()) col.multiplyScalar(0.72);
  x.fillStyle = '#' + col.getHexString(); x.fillRect(i, j, 1, 1);
}));
const t = new THREE.CanvasTexture(c);
t.colorSpace = THREE.SRGBColorSpace;
t.magFilter = t.minFilter = THREE.NearestFilter; t.generateMipmaps = false;
const mat = new THREE.MeshBasicMaterial({ map: t, alphaTest: 0.5, side: THREE.DoubleSide });
const mesh = new THREE.Mesh(new THREE.PlaneGeometry(16 * PX, 24 * PX).translate(0, 11 * PX, 0), mat);
mesh.scale.x = face;                                    // ±1 flips
// every frame: yaw-only billboard, and the tint that stands in for light
mesh.rotation.y = Math.atan2(camera.position.x - mesh.position.x, camera.position.z - mesh.position.z);
const w = lampLit ? 0.55 * (1 - smoothstep(0.8, 4.5, distToLamp)) : 0;
mat.color.set(palette.tint).lerp(new THREE.Color(palette['glow-lamp']), w);
```

**Toon paint with grain** for every set material:

```js
const gradientMap = new THREE.DataTexture(new Uint8Array([70, 140, 205, 255]), 4, 1, THREE.RedFormat);
gradientMap.minFilter = gradientMap.magFilter = THREE.NearestFilter; gradientMap.needsUpdate = true;
const paint = (hex, map = grainTex) => new THREE.MeshToonMaterial({ color: hex, gradientMap, map });
// grainTex: a 128² canvas, white, 900 strokes of rgba(g,g,g,0.35) with g in 196–255, 4–22 × 1–3 px
```

**Surface value maps** (floor, plaster, roof, planks): a grey tileable map of four values multiplies
the role colour, point-sampled up close, with box UVs in world units so every face shows one texel
size:

```js
const t = new THREE.TextureLoader().load('textures/floor-tiles.png');   // 128², values 0.60–1.00
t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping;
t.magFilter = THREE.NearestFilter; t.minFilter = THREE.LinearMipmapLinearFilter;
const floor = paint(palette.ground, t);
function worldUV(geo, tile) {                           // tile: world units one map covers
  const p = geo.attributes.position, n = geo.attributes.normal, uv = geo.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i));
    if (ax > 0.5) uv.setXY(i, p.getZ(i) / tile, p.getY(i) / tile);
    else if (ay > 0.5) uv.setXY(i, p.getX(i) / tile, p.getZ(i) / tile);
    else uv.setXY(i, p.getX(i) / tile, p.getY(i) / tile);
  }
  uv.needsUpdate = true; return geo;
}
```

A generated sprite repaints into another palette by mapping each pixel back to its role (the
cleanup palette lists every role and its shade in a fixed order); read its pixels from a data URL
so a page opened from `file://` can.

**Lights** (day scheme; the demo's palettes hold each scheme's numbers). With tone mapping off,
a directional light of intensity π lights a facing surface at 1× its colour, and the hemisphere
light adds its colour × intensity ÷ π:

```js
const hemi = new THREE.HemisphereLight(palette['fill-sky'], palette['fill-ground'], 1.25);
const key = new THREE.DirectionalLight(palette.key, 2.8);
key.target.position.set(0, 0, -1);                     // the set's centre
key.position.set(-9, 14, 7).add(key.target.position);   // ~50° up, front-left
scene.add(key, key.target);
key.castShadow = true; key.shadow.mapSize.set(2048, 2048);
Object.assign(key.shadow.camera, { left: -13, right: 13, top: 13, bottom: -13, near: 1, far: 70 });
key.shadow.bias = -0.0005; key.shadow.normalBias = 0.03;
const lamp = new THREE.PointLight(palette['glow-lamp'], 14, 9, 1.6);   // night: the one warm light
lamp.intensity = 14 * (1 + 0.06 * Math.sin(t * 7.3) * Math.sin(t * 3.1));
lampCore.material = new THREE.MeshBasicMaterial({ color: new THREE.Color(palette['glow-lamp']).multiplyScalar(2.6) });
```

**The post chain:**

```js
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { HorizontalTiltShiftShader } from 'three/addons/shaders/HorizontalTiltShiftShader.js';
import { VerticalTiltShiftShader } from 'three/addons/shaders/VerticalTiltShiftShader.js';

const composer = new EffectComposer(renderer, rt);
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new UnrealBloomPass(new THREE.Vector2(w, h), 0.55, 0.6, 0.88));  // strength, radius, threshold
const hT = new ShaderPass(HorizontalTiltShiftShader), vT = new ShaderPass(VerticalTiltShiftShader);
hT.uniforms.h.value = 2.4 / w; vT.uniforms.v.value = 2.4 / h;       // 3.2 in close-ups
hT.uniforms.r.value = vT.uniforms.r.value = 0.40;                    // focus line from the bottom
composer.addPass(hT); composer.addPass(vT);
composer.addPass(grade); composer.addPass(new OutputPass());
```

**Grade:** shadows lean toward the fill colour, highlights are spared; vignette; grain.

```glsl
float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
c.rgb = mix(c.rgb, c.rgb * uTint, (1.0 - smoothstep(0.02, 0.35, lum)) * uAmt);   // uTint = fill-ground / its max channel
vec2 d = vUv - 0.5;
c.rgb *= mix(1.0, 1.0 - smoothstep(0.25, 0.85, length(d * vec2(1.1, 1.3))), uVig);
c.rgb += (h(floor(vUv * vec2(1280.0, 720.0)) + uTime) - 0.5) * 0.012;
```

**The animated banded surface** (`ShaderMaterial`, plane rotated flat, 200 × 110 segments):

```glsl
// vertex
float hgt(vec2 p, float t) { return 0.9 * sin(p.x * 0.11 + t * 0.6) + 0.6 * sin(p.y * 0.17 - t * 0.45 + p.x * 0.04)
                                  + 0.25 * sin((p.x + p.y) * 0.37 + t * 1.1); }
vec4 w = modelMatrix * vec4(position, 1.0); float h = hgt(w.xz, uTime); w.y += h; vH = h; vW = w.xyz;
gl_Position = projectionMatrix * viewMatrix * w;
// fragment
vec3 n = normalize(cross(dFdx(vW), dFdy(vW))); if (n.y < 0.0) n = -n;
float l = floor(max(dot(n, normalize(uKeyDir)), 0.0) * 4.0) / 4.0;
vec3 col = uBase * (uFill + uKeyCol * l);                // uKeyCol = key × intensity / π
col *= 0.9 + 0.1 * hash(floor(vW.xz * vec2(0.8, 3.0)));
col = mix(col, uCrest, smoothstep(1.1, 1.6, vH) * 0.5);
float d = length(vW - cameraPosition);
gl_FragColor = vec4(mix(col, uFog, 1.0 - exp(-uDensity * uDensity * d * d)), 1.0);
```

**Captions** are HTML over the canvas on an 85% `plate` backing, projected each frame and placed
by the recipe's layout (see `layoutCaptions()` and `findSpot()` in demo.html):

```js
v.copy(anchor).project(camera);
const sx = (v.x + 1) / 2 * W, sy = (1 - v.y) / 2 * H;
// obstacles: every sprite's screen rectangle (hard), stall boxes (soft); order by priority;
// try above, slid sideways and raised, then beside, then below; first spot clear of placed captions
// and sprites wins; after 4 full captions the rest show a short name; no spot = hidden
```

Clicks go to invisible hit spheres (`new THREE.MeshBasicMaterial({ visible: false })`, radius 0.75)
through a `Raycaster`, never to the caption text.

**Render loop:** full rate while the camera eases or for 2 s after input; otherwise about 10 fps;
stop when `document.hidden`. See `loop()` in demo.html.
