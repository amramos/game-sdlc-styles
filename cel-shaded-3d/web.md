# Web snippets (three.js 0.160.0)

`demo.html` holds all of this working; these are the parts to copy. Colours come from the palette
roles; three.js converts hex to linear for lighting, so the band ratios in `recipe.md` hold.

```html
<script type="importmap">
{ "imports": {
  "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js",
  "three/addons/": "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"
} }
</script>
```

**Renderer.** No tone mapping, sRGB output, antialiasing on (outlines alias without it).

```js
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NoToneMapping;
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.BasicShadowMap;       // hard edge, matches the bands
```

**Lights.** Since r155 lights are physical: multiply the recipe's ratios by π.

```js
const ambient = new THREE.AmbientLight(pal['shadow-tint'], 0.45 * Math.PI);
const key = new THREE.DirectionalLight(pal.key, (0.60 / 0.8) * Math.PI); // ramp lit texel is 0.8
key.position.set(-8, 12, 6);
key.castShadow = true;
key.shadow.mapSize.set(2048, 2048);
Object.assign(key.shadow.camera, { left: -12, right: 12, top: 12, bottom: -12 }); // ~1.2 cm texels
key.shadow.camera.updateProjectionMatrix();
key.shadow.normalBias = 0.1;                            // ~8 texels: no acne on the band edge
key.shadow.bias = -0.001;
// convex props (towers, heads) set receiveShadow = false; terrain receives
```

**Stepped ramp.** `MeshToonMaterial` samples the ramp at `N·L × 0.5 + 0.5`.

```js
function makeRamp(thresholds = [0.0, 0.75], values = [0, 0.8, 1.0], size = 16) {
  const data = new Uint8Array(size);
  for (let i = 0; i < size; i++) {
    const ndl = -1 + (i + 0.5) * (2 / size);
    let band = 0;
    thresholds.forEach((t) => { if (ndl >= t) band++; });
    data[i] = Math.round(values[band] * 255);
  }
  const tex = new THREE.DataTexture(data, size, 1, THREE.RedFormat);
  tex.minFilter = tex.magFilter = THREE.NearestFilter;
  tex.generateMipmaps = false;
  tex.needsUpdate = true;
  return tex;
}
const ramp = makeRamp();
const grass = new THREE.MeshToonMaterial({ color: pal['base-grass'], gradientMap: ramp });
const face = new THREE.MeshToonMaterial({ color: pal['base-skin'],   // face stays lit
  gradientMap: makeRamp([-0.5, 0.75]) });
```

**Rim** on characters, injected after the toon shading (values in linear space):

```js
mat.onBeforeCompile = (s) => {
  s.uniforms.rimColor = { value: new THREE.Color(pal['sky-horizon']) };
  s.fragmentShader = 'uniform vec3 rimColor;\n' + s.fragmentShader.replace(
    '#include <opaque_fragment>',
    `#include <opaque_fragment>
     float ndv = dot(normal, normalize(vViewPosition));
     gl_FragColor.rgb = mix(gl_FragColor.rgb, rimColor, 0.35 * step(0.70, 1.0 - ndv));`);
};
```

**Inverted-hull outline** with a smoothed normal, constant screen width and distance falloff:

```js
function addSmoothNormals(geo) {            // average normals of vertices sharing a position
  const p = geo.attributes.position, n = geo.attributes.normal, acc = new Map();
  const key = (i) => `${p.getX(i).toFixed(4)},${p.getY(i).toFixed(4)},${p.getZ(i).toFixed(4)}`;
  for (let i = 0; i < p.count; i++) {
    const k = key(i), v = acc.get(k) || new THREE.Vector3();
    acc.set(k, v.add(new THREE.Vector3(n.getX(i), n.getY(i), n.getZ(i))));
  }
  const out = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) acc.get(key(i)).clone().normalize().toArray(out, i * 3);
  geo.setAttribute('smoothNormal', new THREE.BufferAttribute(out, 3));
}

const outlineMat = (widthPx) => new THREE.ShaderMaterial({
  side: THREE.BackSide,
  uniforms: {
    ink: { value: new THREE.Color(pal.ink) }, fogColor: { value: new THREE.Color(pal['sky-horizon']) },
    widthPx: { value: widthPx }, viewport: { value: new THREE.Vector2(1920, 1080) },
    fade: { value: new THREE.Vector2(12, 60) }, fogRange: { value: new THREE.Vector2(75, 250) },
  },
  vertexShader: `
    attribute vec3 smoothNormal;
    uniform float widthPx; uniform vec2 viewport, fade;
    varying float vDepth;
    void main() {
      vec4 clip = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      vec3 nView = normalize(normalMatrix * smoothNormal);
      vec2 nClip = normalize((projectionMatrix * vec4(nView, 0.0)).xy + 1e-6);
      float px = mix(widthPx, 1.0, smoothstep(fade.x, fade.y, clip.w)) * viewport.y / 1080.0;
      clip.xy += nClip * px * 2.0 / viewport * clip.w;
      vDepth = clip.w;
      gl_Position = clip;
    }`,
  fragmentShader: `
    uniform vec3 ink, fogColor; uniform vec2 fogRange; varying float vDepth;
    void main() {
      gl_FragColor = vec4(mix(ink, fogColor, smoothstep(fogRange.x, fogRange.y, vDepth)), 1.0);
      #include <colorspace_fragment>
    }`,
});

function outline(mesh, widthPx = 2.5) {
  addSmoothNormals(mesh.geometry);
  const hull = new THREE.Mesh(mesh.geometry, outlineMat(widthPx));
  mesh.add(hull);                            // follows the mesh's transform
}
```

Update every outline material's `viewport` on resize with the drawing buffer size. Skinned meshes
need the skinning chunks in the hull's vertex shader (`#include <skinning_pars_vertex>` and
friends), or use `OutlineEffect` from `three/addons/effects/OutlineEffect.js`, whose width is in
world units and has no distance falloff.

**Sky and fog:**

```js
scene.fog = new THREE.Fog(pal['sky-horizon'], 75, 250);
const sky = new THREE.Mesh(new THREE.SphereGeometry(400, 32, 16), new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false, fog: false,
  uniforms: { top: { value: new THREE.Color(pal['sky-top']) },
              horizon: { value: new THREE.Color(pal['sky-horizon']) } },
  vertexShader: 'varying vec3 vDir; void main(){ vDir = normalize(position);' +
    ' gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `uniform vec3 top, horizon; varying vec3 vDir;
    void main(){ gl_FragColor = vec4(mix(horizon, top, smoothstep(0.0, 0.6, vDir.y)), 1.0);
    #include <colorspace_fragment>
    }`,
}));
```

**Render loop:** render on demand or cap at ~10 fps when nothing moves, and stop when
`document.hidden`; see `demo.html`.

**Fonts:** the demo bundles its fonts (Fredoka for display, Nunito for body, Noto Sans Symbols 2 for
the chip icons) in `assets/fonts/`; a game picks its own.
