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

**Renderer:** tone mapping off so printed colours land as authored; soft shadows.

```js
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.toneMapping = THREE.NoToneMapping;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
```

**Generated prints (what demo.html does).** Load each piece with `THREE.TextureLoader` once a
`LoadingManager` reports every image, stand it on a plane sized from the image's aspect, alpha-test
at 0.5, and draw the card edge as a second plane that keeps only the map's alpha:

```js
m.onBeforeCompile = sh => { sh.fragmentShader = sh.fragmentShader.replace('#include <map_fragment>',
  'vec4 sampledDiffuseColor = texture2D( map, vMapUv ); diffuseColor.a *= sampledDiffuseColor.a;'); };
```

From `file://`, Chrome blocks local textures unless it runs with `--allow-file-access-from-files`;
serve the folder over HTTP otherwise.

**Or draw a print in code (a canvas texture),** when the game wants prints that recolour with the
palette. Draw in world units (`ctx.setTransform(ppu, 0, 0, ppu, pad, pad)`),
so line widths and hatch spacing are the recipe's numbers. The cut-out's paper border goes under
the art; a second canvas holds the card back's mask (white on black, grown and offset):

```js
for (const p of parts) {                       // p.path is a Path2D in units
  mask.fill(p.path); mask.stroke(p.path);      // mask: lineWidth 2*(0.06+0.025), translated (0.02, 0.02)
  ctx.fillStyle = ctx.strokeStyle = pal.paper; ctx.lineWidth = 0.12;   // the 0.06 paper border
  ctx.fill(p.path); ctx.stroke(p.path);
}
for (const p of parts) { ctx.fillStyle = pal[p.fill]; ctx.fill(p.path); hatch(ctx, p.path, p.hatch); }
ctx.strokeStyle = pal.ink; ctx.lineWidth = 0.02;
for (const p of parts) ctx.stroke(p.path);
```

**Hatching:** lines clipped to the part on a scratch canvas, faded toward the light with a
`destination-in` gradient, then drawn over the tint:

```js
function hatch(ctx, p, { a = 35, gap = 0.045, cross = false, lit = 0.25 }) {
  t.clearRect(...); t.save(); t.clip(p); t.lineWidth = 0.011; t.strokeStyle = pal.ink;
  for (const deg of cross ? [a, a + 80] : [a]) {
    const dx = Math.cos(deg * Math.PI / 180), dy = Math.sin(deg * Math.PI / 180); t.beginPath();
    for (let q = -R; q <= R; q += gap * scheme.hatch) {          // scheme.hatch 0.72 at night: denser
      const px = cx - dy * q, py = cy + dx * q; t.moveTo(px - dx * R, py - dy * R); t.lineTo(px + dx * R, py + dy * R); }
    t.stroke(); }
  t.restore(); t.globalCompositeOperation = 'destination-in';
  const g = t.createLinearGradient(0, 0, w, h);                    // light from the upper left
  g.addColorStop(0, `rgba(0,0,0,${lit})`); g.addColorStop(1, 'rgba(0,0,0,1)');
  t.fillStyle = g; t.fillRect(0, 0, w, h); t.globalCompositeOperation = 'source-over';
  ctx.globalAlpha = 0.8; ctx.drawImage(scratch, 0, 0); ctx.globalAlpha = 1;
}
```

**The cut-out mesh:** alpha-tested front, card back behind it; both cast silhouette shadows. The
shadow pass must be double-sided, or a plane facing the light casts nothing:

```js
const geo = new THREE.PlaneGeometry(W, H); geo.translate(0, H / 2 - pad, 0);   // art's bottom at y = 0
const front = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({
  map: tex, alphaTest: 0.5, roughness: 0.92, metalness: 0, shadowSide: THREE.DoubleSide }));
front.customDepthMaterial = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: tex, alphaTest: 0.5 });
const back = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({
  color: pal.card, alphaMap: maskTex, alphaTest: 0.5, roughness: 0.95, shadowSide: THREE.DoubleSide }));
back.position.z = -0.018;
back.customDepthMaterial = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, alphaMap: maskTex, alphaTest: 0.5 });
for (const m of [front, back]) { m.castShadow = m.receiveShadow = true; group.add(m); }
group.rotation.y = 0.12;                         // 5-15 deg off the camera axis
```

**Lights:** constant-intensity spots (decay 0, distance 0); the scheme sets colours and
intensities. The bright and night values from demo.html:

```js
function spot(pos, target, angle, penumbra) {
  const l = new THREE.SpotLight(0xffffff, 1, 0, angle, penumbra, 0);
  l.position.copy(pos); l.target.position.copy(target); scene.add(l, l.target); return l; }
const key  = spot(new THREE.Vector3(-5, 9, 12), new THREE.Vector3(-0.3, -0.4, -1), 0.5, 0.55);
const fill = spot(new THREE.Vector3(6, 7, 11), new THREE.Vector3(0.5, 0, -1), 0.6, 0.7);
const foot = spot(new THREE.Vector3(0, floorY + 0.15, 4.6), new THREE.Vector3(0, 1.2, -6), 1.0, 0.8);
const hemi = new THREE.HemisphereLight(pal['light-fill'], pal.boards, 1);
for (const l of [key, foot]) { l.castShadow = true; l.shadow.mapSize.set(2048, 2048);
  l.shadow.bias = -0.0006; l.shadow.normalBias = 0.02; }
// bright: hemi 1.0, key 2.0, fill 0.9, foot 0.6     night: hemi 0.35, key 1.5, fill 0.6, foot 1.7, pin 2.2
```

**Text in the scene keeps an emissive floor:**

```js
new THREE.MeshStandardMaterial({ map: tex, alphaTest: 0.5, emissive: 0xffffff, emissiveMap: tex, emissiveIntensity: 0.35 });
```

**Vignette** toward the house colour, on a 4× multisampled target, before the output pass:

```js
const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 }));
composer.addPass(new RenderPass(scene, camera));
composer.addPass(new ShaderPass({ uniforms: { tDiffuse: { value: null }, amt: { value: 0.22 }, col: { value: new THREE.Color(pal.house) } },
  vertexShader: 'varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform float amt; uniform vec3 col; varying vec2 vUv;
    void main() { vec4 c = texture2D(tDiffuse, vUv); float v = smoothstep(0.35, 0.95, length((vUv - 0.5) * vec2(1.6, 1.0)));
      gl_FragColor = vec4(mix(c.rgb, col, v * amt), c.a); }` }));
composer.addPass(new OutputPass());
```

**Interface:** DOM slips over the canvas, placed in a 1280×720 box scaled to the frame. Anchor tags
by projecting world points with a camera that has no parallax (`new THREE.Vector3(x, y, z).project(cam)`).
Torn edges are a `clip-path` polygon; the card edge is `filter: drop-shadow(2px 3px 0 var(--card))`
on a wrapper, since the clip would cut a box shadow.

**Palette and lighting switch:** repaint every canvas, set `needsUpdate`, recolour the card backs
and lights. **Render loop:** about 10 fps when idle, stop when `document.hidden`. See `loop()` in
demo.html.
