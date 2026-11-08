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

**Renderer:** tone mapping off so palette colours land as authored; soft shadows.

```js
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.toneMapping = THREE.NoToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
```

**One flat material per palette role**, with vertex colours for the baked ground shading:

```js
const mats = {};
const mat = role => mats[role] ??= new THREE.MeshStandardMaterial({
  color: palette[role], roughness: 1, metalness: 0, flatShading: true, vertexColors: true });

// darken vertices near the ground: 0.72 at y = 0 up to 1.0 at y = 0.55 (geometry in object space)
function bakeAO(g, lo = 0, hi = 0.55, min = 0.72) {
  const p = g.attributes.position, c = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++)
    c.fill(min + (1 - min) * THREE.MathUtils.smoothstep(p.getY(i), lo, hi), i * 3, i * 3 + 3);
  g.setAttribute('color', new THREE.BufferAttribute(c, 3));
  return g;
}
```

**Chamfered box** (the toy edge) from an extruded rectangle with a one-segment bevel:

```js
function chamferBox(w, h, d, b) {
  const x = w / 2 - b, z = d / 2 - b, depth = Math.max(h - 2 * b, 0.001);
  const s = new THREE.Shape();
  s.moveTo(-x, -z); s.lineTo(x, -z); s.lineTo(x, z); s.lineTo(-x, z);
  const g = new THREE.ExtrudeGeometry(s, { depth, bevelEnabled: true, bevelThickness: b,
    bevelSize: b, bevelSegments: 1, curveSegments: 1 });
  g.rotateX(-Math.PI / 2); g.translate(0, -depth / 2, 0);
  return g;
}
```

**Lights:** hemisphere fill to sun about 1.4 : 1 (three.js physical units, tone mapping off).

```js
const hemi = new THREE.HemisphereLight(
  new THREE.Color(palette['sky-top']).lerp(new THREE.Color(0xffffff), 0.45),
  palette.shadow, 2.2);
const sun = new THREE.DirectionalLight(0xFFF3E0, 1.6);
sun.position.set(-7, 16, 9);            // ~55 deg up, well off the camera's yaw
sun.castShadow = true;
sun.shadow.mapSize.set(1024, 1024);
Object.assign(sun.shadow.camera, { left: -9, right: 9, top: 9, bottom: -9, near: 1, far: 50 });
sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.02;
scene.add(hemi, sun, sun.target);
```

**Sky gradient and fog:** a 2×256 canvas as the background, fog in `sky-low`.

```js
const c = document.createElement('canvas'); c.width = 2; c.height = 256;
const x = c.getContext('2d'), gr = x.createLinearGradient(0, 0, 0, 256);
gr.addColorStop(0, palette['sky-top']); gr.addColorStop(0.75, palette['sky-low']);
x.fillStyle = gr; x.fillRect(0, 0, 2, 256);
scene.background = new THREE.CanvasTexture(c); scene.background.colorSpace = THREE.SRGBColorSpace;
scene.fog = new THREE.Fog(palette['sky-low'], camDist + 3, camDist + 26);
```

**Isometric orthographic camera:**

```js
function isoCamera(viewH, aspect, target = new THREE.Vector3(), dist = 40) {
  const pitch = Math.atan(1 / Math.SQRT2), yaw = Math.PI / 4;   // 35.264 deg, 45 deg
  const cam = new THREE.OrthographicCamera(-viewH * aspect / 2, viewH * aspect / 2, viewH / 2, -viewH / 2, 0.1, 200);
  cam.position.set(target.x + dist * Math.cos(pitch) * Math.sin(yaw), target.y + dist * Math.sin(pitch),
                   target.z + dist * Math.cos(pitch) * Math.cos(yaw));
  cam.lookAt(target);
  return cam;
}
```

**Tilt-shift** with the stock shaders, on a 4× multisampled target:

```js
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { HorizontalTiltShiftShader } from 'three/addons/shaders/HorizontalTiltShiftShader.js';
import { VerticalTiltShiftShader } from 'three/addons/shaders/VerticalTiltShiftShader.js';

const rt = new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 });
const composer = new EffectComposer(renderer, rt);
composer.addPass(new RenderPass(scene, camera));
const hT = new ShaderPass(HorizontalTiltShiftShader), vT = new ShaderPass(VerticalTiltShiftShader);
hT.uniforms.h.value = 2.5 / w; vT.uniforms.v.value = 2.5 / h;   // at 720p; scale by h / 720
hT.uniforms.r.value = vT.uniforms.r.value = 0.48;                // focus line from the bottom
composer.addPass(hT); composer.addPass(vT); composer.addPass(new OutputPass());
```

**Contact blob and raised tiles** (no z-fighting):

```js
const blobMat = new THREE.MeshBasicMaterial({ map: radialGradientTexture, color: palette.shadow,
  transparent: true, opacity: 0.45, depthWrite: false,
  polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -2 });
// path slab: 0.94 x 0.07 x 0.94, centred at y = 0.005, so its top sits 0.04 above the ground
```

**Render loop:** render on input and while something animates; otherwise about 10 fps, and stop
when `document.hidden`. See `loop()` in demo.html.

**Fonts:** the demo bundles its fonts (Nunito, and Noto Sans Symbols 2 for the check mark) in
`assets/fonts/`; a game picks its own.
