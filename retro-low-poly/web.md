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

**Renderer:** no colour management, so hexes light as authored; no anti-aliasing; pixel ratio 1.

```js
THREE.ColorManagement.enabled = false;
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.outputColorSpace = THREE.LinearSRGBColorSpace;   // no conversion on output
renderer.toneMapping = THREE.NoToneMapping;
canvas.style.imageRendering = 'pixelated';
```

**Low-res target** (240 lines) and a full-screen post pass that upscales nearest, dithers and
quantises:

```js
const rt = new THREE.WebGLRenderTarget(Math.round(240 * w / h), 240,
  { minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter });
const post = new THREE.ShaderMaterial({
  uniforms: { tDiffuse: { value: rt.texture }, uLow: { value: new THREE.Vector2(rt.width, rt.height) } },
  vertexShader: `varying vec2 vUv; void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`,
  fragmentShader: `uniform sampler2D tDiffuse; uniform vec2 uLow; varying vec2 vUv;
    const float B[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
    void main() {
      vec2 px = floor(vUv * uLow);
      vec3 c = texture2D(tDiffuse, (px + 0.5) / uLow).rgb;
      c += ((B[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0 - 0.5) * 1.2 / 31.0;
      gl_FragColor = vec4(floor(clamp(c, 0.0, 1.0) * 31.0 + 0.5) / 31.0, 1.0);
    }`, depthTest: false, depthWrite: false });
const postScene = new THREE.Scene(), postCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
postScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), post));

function draw() {
  renderer.setRenderTarget(rt); renderer.render(scene, camera);
  renderer.setRenderTarget(null); renderer.render(postScene, postCam);
}
```

`float[16](…)` needs GLSL ES 3.0; three.js 0.160.0 compiles a `ShaderMaterial` as 3.0 on WebGL2.

**One `ShaderMaterial` for every mesh:** vertex snap, affine UVs, per-vertex light and fog. Share the
light and fog uniforms by reference (`{ ...G, map: { value: tex } }`), so one change reaches every
material.

```glsl
// shared by both stages
uniform vec3 uAmb; uniform vec3 uSunDir; uniform vec3 uSunCol;
uniform vec3 uPtPos[6]; uniform vec3 uPtCol[6]; uniform float uPtK[6];
vec3 lightAt(vec3 P, vec3 N) {
  vec3 c = uAmb + uSunCol * max(dot(N, uSunDir), 0.0);
  for (int i = 0; i < 6; i++) {
    vec3 L = uPtPos[i] - P; float d = length(L);
    c += uPtCol[i] * (max(dot(N, L / max(d, 1e-4)), 0.0) * 0.8 + 0.2) / (1.0 + uPtK[i] * d * d);
  }
  return c;
}
```

```glsl
// vertex
uniform vec2 uRes; uniform float uSnap; uniform float uFogNear; uniform float uFogFar;
varying vec3 vAff; varying vec3 vLight; varying float vFog;
void main() {
  vec4 wp = modelMatrix * vec4(position, 1.0);
  vec4 vp = viewMatrix * wp;
  vec4 p = projectionMatrix * vp;
  vec2 grid = uRes * 0.5 / uSnap;
  p.xy = floor(p.xy / p.w * grid + 0.5) / grid * p.w;
  gl_Position = p;
  vAff = vec3(uv * p.w, p.w);
  vLight = lightAt(wp.xyz, normalize(mat3(modelMatrix) * normal));   // uniform scale only
  vFog = clamp((-vp.z - uFogNear) / (uFogFar - uFogNear), 0.0, 1.0);
}
```

```glsl
// fragment
uniform sampler2D map; uniform float uEmit; uniform float uHi; uniform vec3 uAccent; uniform vec3 uFogCol;
varying vec3 vAff; varying vec3 vLight; varying float vFog;
void main() {
  vec3 tex = texture2D(map, vAff.xy / vAff.z).rgb;
  float bright = smoothstep(0.55, 0.85, max(tex.r, max(tex.g, tex.b)));
  vec3 c = tex * vLight + tex * uEmit * bright + uAccent * uHi;   // uHi = 0.25 + 0.2 sin(6t) on usable things
  gl_FragColor = vec4(mix(c, uFogCol, vFog), 1.0);
}
```

**Textures drawn in code** at true size, quantised to 5 bits, nearest, no mipmaps:

```js
function makeTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const x = c.getContext('2d'); draw(x, w, h);
  const d = x.getImageData(0, 0, w, h);
  for (let i = 0; i < d.data.length; i += 4) for (let k = 0; k < 3; k++) d.data[i + k] = d.data[i + k] >> 3 << 3;
  x.putImageData(d, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.magFilter = t.minFilter = THREE.NearestFilter; t.generateMipmaps = false;
  return t;
}
```

**Split big faces and tile UVs by world size** (bake each part's transform into the geometry first):

```js
const SEG = 1.6;
const box = (w, h, d, x, y, z) => new THREE.BoxGeometry(w, h, d,
  Math.ceil(w / SEG), Math.ceil(h / SEG), Math.ceil(d / SEG)).translate(x, y, z);
function boxUV(g, tile) {
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
    const [u, v] = ax >= ay && ax >= az ? [p.getZ(i), p.getY(i)] : ay >= az ? [p.getX(i), p.getZ(i)] : [p.getX(i), p.getY(i)];
    uv.setXY(i, u / tile, v / tile);
  }
  return g;
}
```

**Sky dome:** `SphereGeometry(250, 8, 6)`, `side: BackSide`, unlit, no fog; a 4×64 canvas from `sky`
at the top to `fog` at the middle row. `scene.background` = the `fog` colour.

**Render loop:** render while the camera eases or on input; otherwise about 10 fps; stop when
`document.hidden`. See `loop()` in demo.html.
