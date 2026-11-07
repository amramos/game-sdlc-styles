# Godot 4 snippets

<!-- matched-web-frame: c4e8276e5fd1 -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.png` rebuilds
`demo.html?frame=key-scene`: mean difference 0.8 / 1.0 / 0.7 per 255 (R/G/B); 4% of pixels differ by
more than 8 and 0.3% by more than 24, all of them single low-res pixels, one 5-bit step apart, scattered
over the frame (a texel or polygon edge that rounds the other way, mostly on the checker floor and the
edge of a wall sign). Composition, camera, cast, props, textures, dither pattern and palette are the
same. **Forward+** comes closer still (0.3 / 0.2 / 0.2; 0.5% of pixels over 8), with one change in the
surface shader that is already in the code below.

## Scene layout

3D renders into a `SubViewport` at 240 lines (427 × 240 at 16:9). A full-screen `TextureRect`
shows it with nearest filtering and the dither shader. The interface is ordinary `Control` nodes in a
`CanvasLayer` above it, at window resolution. The key-scene frame shows no interface; panels follow
`recipe.md` (a `StyleBoxFlat` with the `panel` fill, a 2 px `ink` border, a 0–4 px radius and a
3 px `ink` shadow offset with size 0).

Everything is built in code from one script on a plain `Node`. The palette, the light factors and
the pose time below are the example's sunny afternoon; a game sets its own.

```ini
; project.godot
[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=0
textures/canvas_textures/default_texture_filter=0
```

```gdscript
extends Node
## Port of retro-low-poly/demo.html?frame=key-scene: the diner seen from a counter stool,
## sunny-afternoon palette, every animated value posed at t = 1.3 s.

const P := {
	"ink": "#1C1824", "panel": "#F4ECD8", "key": "#FFF2D8", "ambient": "#8A94A8", "fog": "#DDEEF5",
	"sky": "#7FB8E0", "glow-sign": "#FF5A50", "glow-jukebox": "#FFC850", "glow-tube": "#F0FAFF",
	"accent": "#A23CFF", "material-floor-light": "#E0CCA0", "material-floor-dark": "#2A2A30",
	"material-wall": "#8FCFBF", "material-wood": "#7A4E2E", "material-vinyl": "#B02A34",
	"material-chrome": "#C4CCD6", "material-formica": "#E2CA7A", "material-skin": "#C68462",
	"material-cloth": "#F2F0EA", "material-paint": "#3A86B8", "material-brick": "#9A5A48",
	"material-asphalt": "#4E5058",
}
const LIGHT := {"amb": 0.75, "sun": 0.62, "sun_dir": Vector3(0.4, 0.8, 0.45), "tubes": 0.12,
	"sign": 0.35, "juke": 0.55, "head": 0.1, "kitchen": 0.25, "fog_near": 6.0, "fog_far": 55.0}
const LINES := 240                   # internal render height
const SEG := 0.5                     # faces split every 0.5 m: light lands, the affine warp never folds
const SEAT := Vector3(2.4, 1.5, -0.95)
const T := 1.3                       # the time the key-scene frame is posed at

var retro := preload("res://retro.gdshader")
var sv: SubViewport
var view: TextureRect
var world: Node3D
var camera: Camera3D
var tex := {}
var mats := {}                       # every ShaderMaterial, keyed like the web's material cache
var emit := {}                       # emit kind -> value
var hi := {}                         # highlight kind -> value

func v3(role: String, k := 1.0) -> Vector3:   # palette hex as authored, no sRGB decode
	var c := Color.html(P[role])
	return Vector3(c.r, c.g, c.b) * k

# ------------------------------------------------------------------ materials
func M(t: String, o := {}) -> ShaderMaterial:
	var key: String = t + (":e" + o.emit if o.has("emit") else "") + (":hi" if o.has("hi") else "") + (":u" if o.get("unlit", false) else "")
	if mats.has(key): return mats[key]
	var m := ShaderMaterial.new()
	m.shader = retro
	m.set_shader_parameter("albedo_tex", tex[t])
	m.set_shader_parameter("clamp_uv", t == "cook")
	m.set_meta("emit", o.get("emit", ""))
	m.set_meta("hi", o.get("hi", ""))
	m.set_shader_parameter("unlit", 1.0 if o.get("unlit", false) else 0.0)
	m.set_shader_parameter("fog_on", 0.0 if o.get("unlit", false) else 1.0)
	mats[key] = m
	return m

# ------------------------------------------------------------------ geometry helpers
func box(w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> Geo:
	var g := Geo.box(w, h, d, ceili(w / SEG), ceili(h / SEG), ceili(d / SEG))
	if ry != 0.0: g.rotate_y(ry)
	return g.translate(x, y, z)

func cyl(r: float, h: float, n: int, x: float, y: float, z: float, r2 := -1.0) -> Geo:
	return Geo.cylinder(r if r2 < 0.0 else r2, r, h, n).translate(x, y, z)

func add(parent: Node3D, g: Geo, mat: ShaderMaterial, tile := 1.0, inside := false) -> MeshInstance3D:
	if tile != 0.0: g.box_uv(tile)
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(inside)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## A quad that keeps 0..1 UVs (signs, machine fronts), split every 0.25 m or the affine warp folds it.
func decal(parent: Node3D, w: float, h: float, mat: ShaderMaterial, x: float, y: float, z: float, ry := 0.0) -> void:
	var g := Geo.plane(w, h, ceili(w / 0.25), ceili(h / 0.25))
	if ry != 0.0: g.rotate_y(ry)
	add(parent, g.translate(x, y, z), mat, 0.0)

# ------------------------------------------------------------------ scene
func _ready() -> void:
	var win := get_viewport().get_visible_rect().size
	sv = SubViewport.new()
	sv.size = Vector2i(roundi(LINES * win.x / win.y), LINES)        # 427 x 240 at 16:9
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sv.use_taa = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	view = TextureRect.new()
	view.texture = sv.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = preload("res://dither.gdshader")
	post.set_shader_parameter("low_res", Vector2(sv.size))
	view.material = post
	add_child(view)
	# The interface goes in a CanvasLayer above `view`, at window resolution (none in this frame).

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(P.fog)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera = Camera3D.new()
	camera.environment = env
	camera.fov = 55.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 300.0
	camera.position = SEAT
	camera.rotation = Vector3(deg_to_rad(-7.0), deg_to_rad(84.0), 0.0)   # Godot's Euler order is YXZ
	sv.add_child(camera)
	world = Node3D.new()
	sv.add_child(world)

	make_textures()
	build_diner()
	apply_light(Vector2(sv.size), win)

func make_textures() -> void:
	var tx := RetroTextures.new(P)
	for n in ["floor", "formica", "brick"]:
		var src: Image = (load("res://assets/%s.png" % n) as Texture2D).get_image()
		src.convert(Image.FORMAT_RGBA8)
		tex[n] = tx.make(n, src)
	for n in ["wall", "tile", "ceiling", "wood", "vinyl", "chrome", "asphalt", "road", "paint", "glass",
			"dark", "cloth", "jukefront", "jukearch", "neon", "tube", "sign", "open", "menu", "hill", "sky"]:
		tex[n] = tx.make(n)


# build_diner(): the set, one add()/decal() call per line of demo.html's set list, with the
# same sizes, positions, materials and tile sizes (see demo.html).
```

The camera matches three.js's: a 55° vertical field of view (`KEEP_HEIGHT`), near 0.05, far 300,
Euler order YXZ (Godot's default). The target's width is rounded (427 px where 16:9 gives
426.67), so the shader's `aspect_fix` scales clip-space x by the target's aspect over the window's,
as three.js does when it projects with the window's aspect.

## Import settings

- **Model (GLB):** in its `.import`: `gltf/embedded_image_handling=3` (embed uncompressed: no VRAM
  compression on a 256 px, 5-bit atlas), `meshes/generate_lods=false` (LODs would drop triangles
  at distance), `meshes/force_disable_compression=true` (vertex compression would shift the
  positions the snap rounds). The shader takes the model's base-colour texture from the imported
  material and samples it raw, nearest, clamped to its edges.
- **Texture PNGs:** `compress/mode=0` (lossless), `mipmaps/generate=false`,
  `detect_3d/compress_to=0`. They are only read as `Image`s and drawn into the textures below.
- Every texture is sampled by the shader's own `filter_nearest, repeat_enable` hint (no mipmaps),
  and without `source_color`, so texels reach the light maths as authored.

## Post: dither and 5-bit colour (`dither.gdshader`)

```glsl
// Post pass on the TextureRect that shows the low-res SubViewport: nearest upscale,
// 4x4 ordered dither, 31 levels per channel.
shader_type canvas_item;

uniform vec2 low_res = vec2(427.0, 240.0);
const float B[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

void fragment() {
	vec2 px = floor(UV * low_res);
	vec3 c = texture(TEXTURE, (px + 0.5) / low_res).rgb;
	float row = low_res.y - 1.0 - px.y;   // count rows from the bottom, as GL's gl_FragCoord does
	c += ((B[int(mod(row, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0 - 0.5) * 1.2 / 31.0;
	COLOR = vec4(floor(clamp(c, 0.0, 1.0) * 31.0 + 0.5) / 31.0, 1.0);
}
```

The Bayer row counts from the bottom of the target, as `gl_FragCoord` does in the web demo;
counting from the top flips the pattern's rows, and the frame then differs in about one pixel in
four by one step.

## The surface shader (`retro.gdshader`)

```glsl
// One shader for every mesh: vertex snap, affine UVs, per-vertex light, linear fog.
// Colours are computed in gamma space as authored (palette hexes and light ratios land as written).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;   // no source_color: texels as authored
uniform bool clamp_uv = false;                  // clamp-to-edge for atlas textures (the model)
uniform vec2 low_res = vec2(427.0, 240.0);      // the SubViewport size
uniform float aspect_fix = 1.0;                 // (low_res aspect) / (window aspect)
uniform float snap = 1.0;                       // 1 = one low-res pixel, 2 = coarser, 0 = off
uniform vec3 ambient;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);     // normalised
uniform vec3 sun_col;
uniform vec3 pt_pos[6];
uniform vec3 pt_col[6];
uniform float pt_k[6];
uniform vec3 fog_col;
uniform vec2 fog_range = vec2(6.0, 55.0);
uniform float fog_on = 1.0;
uniform float unlit = 0.0;
uniform float emit = 0.0;
uniform float hi = 0.0;                         // 0.25 + 0.2 sin(6t) on what the player can use
uniform vec3 accent;

varying vec3 aff;
varying vec3 v_light;
varying float v_fog;

vec3 light_at(vec3 p, vec3 n) {
	vec3 c = ambient + sun_col * max(dot(n, sun_dir), 0.0);
	for (int i = 0; i < 6; i++) {
		vec3 l = pt_pos[i] - p;
		float d = length(l);
		float wrap = max(dot(n, l / max(d, 1e-4)), 0.0) * 0.8 + 0.2;   // back faces keep 20%
		c += pt_col[i] * wrap / (1.0 + pt_k[i] * d * d);
	}
	return c;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Compatibility writes ALBEDO of an unshaded material into the SubViewport without the sRGB
// encode, so gamma-space values go out as they are; Forward+ encodes, so linearise first.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define TO_OUTPUT(c) (c)
#else
#define TO_OUTPUT(c) to_linear(c)
#endif

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);   // uniform scale only
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vec4 p = PROJECTION_MATRIX * vp;
	p.x *= aspect_fix;
	if (snap > 0.0) {                                    // snap to the low-res pixel grid
		vec2 grid = low_res * 0.5 / snap;
		p.xy = floor(p.xy / p.w * grid + 0.5) / grid * p.w;
	}
	POSITION = p;
	aff = vec3(UV * p.w, p.w);                           // affine: divided back per fragment
	v_light = mix(light_at(wp, wn), vec3(1.0), unlit);   // Gouraud: light per vertex
	v_fog = clamp((-vp.z - fog_range.x) / (fog_range.y - fog_range.x), 0.0, 1.0) * fog_on;
}

void fragment() {
	vec2 uv = aff.xy / aff.z;
	if (clamp_uv) {
		uv = clamp(uv, 0.0, 1.0);
	}
	vec3 t = texture(albedo_tex, uv).rgb;
	float bright = smoothstep(0.55, 0.85, max(t.r, max(t.g, t.b)));   // only bright texels glow
	vec3 c = t * v_light + t * emit * bright + accent * hi;
	c = mix(c, fog_col, v_fog);
	ALBEDO = TO_OUTPUT(clamp(c, 0.0, 1.0));
}
```

## Geometry (`geo.gd`)

Builds boxes, cylinders, cones, spheres and planes with the vertices, normals, UVs and triangle
diagonals of three.js's generators, so the affine warp folds the same way. Split boxes every 0.5 m
(`SEG`) and decals every 0.25 m; the lot is cut in pieces around the floor slab, never under it.

```gdscript
class_name Geo
extends RefCounted
## Chunky primitives with the same vertices, normals, UVs and triangle diagonals as three.js's
## BoxGeometry, CylinderGeometry, SphereGeometry and PlaneGeometry, so the affine warp folds the
## same way. Positions and normals are stored as 32-bit floats; maths runs in 64-bit, like three.
## Triangles are listed counter-clockwise as in three; to_mesh() reverses them for Godot, whose
## front faces are clockwise.

var pos := PackedFloat32Array()
var nrm := PackedFloat32Array()
var uv := PackedFloat32Array()
var idx := PackedInt32Array()

func _v(x: float, y: float, z: float, nx: float, ny: float, nz: float, u: float, v: float) -> void:
	pos.append(x); pos.append(y); pos.append(z)
	nrm.append(nx); nrm.append(ny); nrm.append(nz)
	uv.append(u); uv.append(v)

func count() -> int:
	return pos.size() / 3

# ------------------------------------------------------------------ transforms (baked, like three)
func _apply(m: Array, rotate_normals: bool) -> Geo:   # m = 3x3 row-major + translation
	for i in count():
		var x := pos[i * 3]; var y := pos[i * 3 + 1]; var z := pos[i * 3 + 2]
		pos[i * 3] = m[0] * x + m[1] * y + m[2] * z + m[9]
		pos[i * 3 + 1] = m[3] * x + m[4] * y + m[5] * z + m[10]
		pos[i * 3 + 2] = m[6] * x + m[7] * y + m[8] * z + m[11]
		var a := nrm[i * 3]; var b := nrm[i * 3 + 1]; var c := nrm[i * 3 + 2]
		if rotate_normals:
			var na: float = m[0] * a + m[1] * b + m[2] * c
			var nb: float = m[3] * a + m[4] * b + m[5] * c
			var nc: float = m[6] * a + m[7] * b + m[8] * c
			a = na; b = nb; c = nc
		var l := sqrt(a * a + b * b + c * c)
		if l > 0.0:
			nrm[i * 3] = a / l; nrm[i * 3 + 1] = b / l; nrm[i * 3 + 2] = c / l
	return self

func rotate_x(t: float) -> Geo:
	var c := cos(t); var s := sin(t)
	return _apply([1, 0, 0, 0, c, -s, 0, s, c, 0, 0, 0], true)

func rotate_y(t: float) -> Geo:
	var c := cos(t); var s := sin(t)
	return _apply([c, 0, s, 0, 1, 0, -s, 0, c, 0, 0, 0], true)

func rotate_z(t: float) -> Geo:
	var c := cos(t); var s := sin(t)
	return _apply([c, -s, 0, s, c, 0, 0, 0, 1, 0, 0, 0], true)

func translate(x: float, y: float, z: float) -> Geo:
	return _apply([1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z], false)

# ------------------------------------------------------------------ primitives
static func box(w: float, h: float, d: float, ws := 1, hs := 1, ds := 1) -> Geo:
	var g := Geo.new()
	g._plane(2, 1, 0, -1, -1, d, h, w, ds, hs)    # +x
	g._plane(2, 1, 0, 1, -1, d, h, -w, ds, hs)    # -x
	g._plane(0, 2, 1, 1, 1, w, d, h, ws, ds)      # +y
	g._plane(0, 2, 1, 1, -1, w, d, -h, ws, ds)    # -y
	g._plane(0, 1, 2, 1, -1, w, h, d, ws, hs)     # +z
	g._plane(0, 1, 2, -1, -1, w, h, -d, ws, hs)   # -z
	return g

func _plane(u: int, v: int, w: int, udir: float, vdir: float, width: float, height: float,
		depth: float, gx: int, gy: int) -> void:
	var sw := width / gx; var sh := height / gy
	var start := count()
	for iy in gy + 1:
		var y := iy * sh - height / 2.0
		for ix in gx + 1:
			var x := ix * sw - width / 2.0
			var p := [0.0, 0.0, 0.0]; var n := [0.0, 0.0, 0.0]
			p[u] = x * udir; p[v] = y * vdir; p[w] = depth / 2.0
			n[w] = 1.0 if depth > 0 else -1.0
			_v(p[0], p[1], p[2], n[0], n[1], n[2], float(ix) / gx, 1.0 - float(iy) / gy)
	for iy in gy:
		for ix in gx:
			var a := start + ix + (gx + 1) * iy
			var b := start + ix + (gx + 1) * (iy + 1)
			var c := start + ix + 1 + (gx + 1) * (iy + 1)
			var d := start + ix + 1 + (gx + 1) * iy
			idx.append_array([a, b, d, b, c, d])

static func plane(w: float, h: float, gx := 1, gy := 1) -> Geo:
	var g := Geo.new()
	for iy in gy + 1:
		var y := iy * (h / gy) - h / 2.0
		for ix in gx + 1:
			var x := ix * (w / gx) - w / 2.0
			g._v(x, -y, 0.0, 0.0, 0.0, 1.0, float(ix) / gx, 1.0 - float(iy) / gy)
	for iy in gy:
		for ix in gx:
			var a := ix + (gx + 1) * iy
			var b := ix + (gx + 1) * (iy + 1)
			var c := ix + 1 + (gx + 1) * (iy + 1)
			var d := ix + 1 + (gx + 1) * iy
			g.idx.append_array([a, b, d, b, c, d])
	return g

static func cylinder(rt: float, rb: float, h: float, radial := 8, hseg := 1, open := false,
		t0 := 0.0, tl := TAU) -> Geo:
	var g := Geo.new()
	var half := h / 2.0
	var slope := (rb - rt) / h
	var grid := []
	for y in hseg + 1:
		var row := []
		var v := float(y) / hseg
		var r := v * (rb - rt) + rt
		for x in radial + 1:
			var u := float(x) / radial
			var th := u * tl + t0
			var s := sin(th); var c := cos(th)
			var nl := sqrt(s * s + slope * slope + c * c)
			g._v(r * s, -v * h + half, r * c, s / nl, slope / nl, c / nl, u, 1.0 - v)
			row.append(g.count() - 1)
		grid.append(row)
	for x in radial:
		for y in hseg:
			var a: int = grid[y][x]; var b: int = grid[y + 1][x]
			var c: int = grid[y + 1][x + 1]; var d: int = grid[y][x + 1]
			if rt > 0 or y != 0: g.idx.append_array([a, b, d])
			if rb > 0 or y != hseg - 1: g.idx.append_array([b, c, d])
	if not open:
		if rt > 0: g._cap(true, rt, half, radial, t0, tl)
		if rb > 0: g._cap(false, rb, half, radial, t0, tl)
	return g

func _cap(top: bool, r: float, half: float, radial: int, t0: float, tl: float) -> void:
	var sgn := 1.0 if top else -1.0
	var c0 := count()
	for x in range(1, radial + 1):
		_v(0.0, half * sgn, 0.0, 0.0, sgn, 0.0, 0.5, 0.5)
	var e0 := count()
	for x in radial + 1:
		var th := float(x) / radial * tl + t0
		var c := cos(th); var s := sin(th)
		_v(r * s, half * sgn, r * c, 0.0, sgn, 0.0, c * 0.5 + 0.5, s * 0.5 * sgn + 0.5)
	for x in radial:
		var cc := c0 + x; var i := e0 + x
		if top: idx.append_array([i, i + 1, cc])
		else: idx.append_array([i + 1, i, cc])

static func sphere(r: float, ws := 8, hs := 6, p0 := 0.0, pl := TAU, t0 := 0.0, tl := PI) -> Geo:
	var g := Geo.new()
	var t_end := minf(t0 + tl, PI)
	var grid := []
	for iy in hs + 1:
		var row := []
		var v := float(iy) / hs
		var u_off := 0.0
		if iy == 0 and t0 == 0.0: u_off = 0.5 / ws
		elif iy == hs and t_end == PI: u_off = -0.5 / ws
		for ix in ws + 1:
			var u := float(ix) / ws
			var x := -r * cos(p0 + u * pl) * sin(t0 + v * tl)
			var y := r * cos(t0 + v * tl)
			var z := r * sin(p0 + u * pl) * sin(t0 + v * tl)
			var l := sqrt(x * x + y * y + z * z)
			g._v(x, y, z, x / l, y / l, z / l, u + u_off, 1.0 - v)
			row.append(g.count() - 1)
		grid.append(row)
	for iy in hs:
		for ix in ws:
			var a: int = grid[iy][ix + 1]; var b: int = grid[iy][ix]
			var c: int = grid[iy + 1][ix]; var d: int = grid[iy + 1][ix + 1]
			if iy != 0 or t0 > 0: g.idx.append_array([a, b, d])
			if iy != hs - 1 or t_end < PI: g.idx.append_array([b, c, d])
	return g

## Planar UVs from position, chosen by the face normal; tile = metres per texture repeat.
func box_uv(tile: float) -> Geo:
	for i in count():
		var ax := absf(nrm[i * 3]); var ay := absf(nrm[i * 3 + 1]); var az := absf(nrm[i * 3 + 2])
		var x := pos[i * 3]; var y := pos[i * 3 + 1]; var z := pos[i * 3 + 2]
		var u: float; var v: float
		if ax >= ay and ax >= az: u = z; v = y
		elif ay >= az: u = x; v = z
		else: u = x; v = y
		uv[i * 2] = u / tile; uv[i * 2 + 1] = v / tile
	return self

func to_mesh(inside := false) -> ArrayMesh:
	var p := PackedVector3Array(); var n := PackedVector3Array(); var t := PackedVector2Array()
	for i in count():
		p.append(Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]))
		n.append(Vector3(nrm[i * 3], nrm[i * 3 + 1], nrm[i * 3 + 2]))
		t.append(Vector2(uv[i * 2], uv[i * 2 + 1]))
	var ii := PackedInt32Array()
	for k in range(0, idx.size(), 3):   # three: counter-clockwise front faces; Godot: clockwise
		if inside: ii.append_array([idx[k], idx[k + 1], idx[k + 2]])
		else: ii.append_array([idx[k], idx[k + 2], idx[k + 1]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = p; arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = t; arrays[Mesh.ARRAY_INDEX] = ii
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
```

## Textures (`textures.gd`)

Drawn at true size with the same calls and seeded randomness as the web demo, then cut to 5 bits per
channel and flipped vertically (canvas row 0 is the top; three.js's `CanvasTexture` puts it at v = 1,
and the world-space UVs assume that).

```gdscript
class_name RetroTextures
extends RefCounted
## Textures drawn in code at true size from the palette roles, cut to 5 bits per channel,
## nearest-filtered. Same drawing and seeded randomness as the web demo, texel for texel.

var P: Dictionary            # the palette: role -> "#RRGGBB"
var img: Image
var _a := 0                  # mulberry32 state

func _init(palette: Dictionary) -> void:
	P = palette

# ------------------------------------------------------------------ seeded random (mulberry32 + FNV name hash)
static func imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF

static func name_hash(s: String) -> int:
	var h := 2166136261
	for ch in s:
		h = imul(h ^ ch.unicode_at(0), 16777619)
	return h

func r() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# ------------------------------------------------------------------ colours (CSS rgb() rounding)
func rgb(role: String) -> Array:
	var c := Color.html(P[role])
	return [c.r8, c.g8, c.b8]

func _css(a: Array) -> Color:
	var o := []
	for v in a: o.append(clampi(int(floor(v + 0.5)), 0, 255))
	return Color8(o[0], o[1], o[2])

func shade(role: String, k: float) -> Color:
	var a := rgb(role)
	return _css([a[0] * k, a[1] * k, a[2] * k])

func mixc(ra: String, rb: String, t: float) -> Color:
	var a := rgb(ra); var b := rgb(rb)
	return _css([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t])

# ------------------------------------------------------------------ canvas-like drawing
var fill_col := Color.BLACK

func rect(x: int, y: int, w: int, h: int, col = null) -> void:
	if col != null: fill_col = col
	var r2 := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r2.size.x > 0 and r2.size.y > 0: img.fill_rect(r2, fill_col)

func speck(n: int, col: Color, s := 1) -> void:
	fill_col = col
	var w := img.get_width(); var h := img.get_height()
	for i in n:
		var x := int(floor(r() * w)); var y := int(floor(r() * h))
		rect(x, y, s, s)

const GLYPHS := { "O": "01110100011000110001100011000101110", "P": "11110100011000111110100001000010000",
	"E": "11111100001000011110100001000011111", "N": "10001110011010110011100011000110001",
	"A": "01110100011000111111100011000110001", "T": "11111001000010000100001000010000100" }

## 5x7 bitmap letters drawn texel by texel; s = texels per glyph pixel.
func pixel_text(text: String, s: int) -> void:
	var w := img.get_width(); var h := img.get_height()
	var tw := text.length() * 6 * s - s
	var x0 := int(floor((w - tw) / 2.0 + 0.5)); var y0 := int(floor((h - 7 * s) / 2.0 + 0.5))
	for k in text.length():
		var g: String = GLYPHS[text[k]]
		for i in 35:
			if g[i] == "1": rect(x0 + (k * 6 + i % 5) * s, y0 + (i / 5) * s, s, s)

# ------------------------------------------------------------------ the textures
func make(tex_name: String, source: Image = null) -> ImageTexture:
	var size: Array = {"floor": [64, 64], "formica": [64, 64], "brick": [64, 64], "jukefront": [64, 64],
		"neon": [8, 8], "tube": [8, 8], "sign": [64, 32], "open": [128, 32], "menu": [64, 32],
		"sky": [4, 64]}.get(tex_name, [32, 32])
	img = Image.create(size[0], size[1], false, Image.FORMAT_RGBA8)
	_a = name_hash(tex_name)
	var w: int = size[0]; var h: int = size[1]
	match tex_name:
		"floor", "formica", "brick":                       # MaterialCraft PNGs
			img.blit_rect(source, Rect2i(0, 0, w, h), Vector2i.ZERO)
		"wall":
			rect(0, 0, w, h, shade("material-wall", 1))
			rect(0, 0, 1, h, shade("material-wall", 0.8)); rect(16, 0, 1, h)
			rect(1, 0, 1, h, shade("material-wall", 1.1)); rect(17, 0, 1, h)
			speck(30, shade("material-wall", 0.9))
		# … one branch per texture, as demo.html's DRAW table: tile, ceiling, wood, vinyl, chrome,
		# asphalt, road, paint, glass, dark, cloth, jukefront, jukearch, neon, tube, sign, open, menu,
		# hill, sky
	# 5 bits per channel, like the textures of the era
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color8(c.r8 >> 3 << 3, c.g8 >> 3 << 3, c.b8 >> 3 << 3))
	img.flip_y()   # canvas row 0 is the top; three's CanvasTexture flips it, so v = 0 is the bottom row
	return ImageTexture.create_from_image(img)
```

## The model and the light

```gdscript
## The cook: a Meshy model (about 2,600 triangles, 256 px texture at 5 bits), drawn by the same
## shader, its texture sampled raw. Facing +z, feet at the origin, 1.95 m to the top of the cap.
func build_cook() -> Node3D:
	var g := Node3D.new(); world.add_child(g)
	var m: Node3D = (load("res://assets/cook.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = m.find_children("*", "MeshInstance3D")[0]
	if not tex.has("cook"):
		tex["cook"] = (mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture
	mi.material_override = M("cook")
	var b := mi.mesh.get_aabb()
	var k := 1.95 / b.size.y
	m.scale = Vector3.ONE * k
	var c := b.get_center()
	m.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
	g.add_child(m)
	return g

# ------------------------------------------------------------------ light, fog and animated values
func apply_light(low: Vector2, win: Vector2) -> void:
	var L := LIGHT
	var key := v3("key")
	var pts := [
		[Vector3(-4.5, 3.0, 0), key * L.tubes * 0.9, 0.12], [Vector3(0, 3.0, 0), key * L.tubes * 0.9, 0.12],
		[Vector3(4.5, 3.0, 0), key * L.tubes * 0.9, 0.12], [Vector3(-14.4, 2.6, -2.2), v3("glow-sign", L.sign * 1.6), 0.08],
		[Vector3(-5.9, 1.2, -2.9), v3("glow-jukebox", L.juke * 0.8), 0.9], [Vector3(0, 2.3, -4.8), key * L.kitchen, 0.3]]
	var pp := PackedVector3Array(); var pc := PackedVector3Array(); var pk := PackedFloat32Array()
	for p in pts: pp.append(p[0]); pc.append(p[1]); pk.append(p[2])
	# animated values, posed at T (in a game: update emit.sign and hi.juke every frame)
	emit = {"": 0.0, "tube": L.tubes * 0.9 + 0.1, "juke": L.juke, "head": L.head,
		"sign": L.sign * (0.92 + 0.05 * sin(T * 13) + 0.03 * sin(T * 31))}   # flicker
	hi = {"": 0.0, "juke": 0.25 + 0.2 * sin(T * 6)}                        # the accent's one job
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter("low_res", low)
		m.set_shader_parameter("aspect_fix", (low.x / low.y) / (win.x / win.y))
		m.set_shader_parameter("ambient", v3("ambient", L.amb))
		m.set_shader_parameter("sun_col", v3("key", L.sun))
		m.set_shader_parameter("sun_dir", (L.sun_dir as Vector3).normalized())
		m.set_shader_parameter("pt_pos", pp)
		m.set_shader_parameter("pt_col", pc)
		m.set_shader_parameter("pt_k", pk)
		m.set_shader_parameter("fog_col", v3("fog"))
		m.set_shader_parameter("fog_range", Vector2(L.fog_near, L.fog_far))
		m.set_shader_parameter("accent", v3("accent"))
		m.set_shader_parameter("emit", emit[m.get_meta("emit")])
		m.set_shader_parameter("hi", hi[m.get_meta("hi")])
```

In a game, set `emit` for flickering signs and `hi` for the usable object's pulse every frame
(`0.92 + 0.05 sin 13t + 0.03 sin 31t` and `0.25 + 0.2 sin 6t`); the render poses them at t = 1.3 s.

## Compatibility traps

- **Unshaded `ALBEDO` reaches a `SubViewport` without the sRGB encode in Compatibility**, while
  Forward+ encodes it. Linearising in the shader (as the draft of this page did) made the
  Compatibility frame far too dark (mean difference 56/255). The shader writes gamma-space colour as
  it is in Compatibility and linearises only for the other renderers (`TO_OUTPUT`).
- **Dither rows:** canvas `UV` runs top-down; count Bayer rows from the bottom to match GL.
- **Winding:** Godot's front faces are clockwise and three.js's counter-clockwise; `to_mesh()`
  reverses every triangle, and keeps them as they are for the sky dome, which is seen from inside.
- **Texture rows:** three.js's canvas textures are flipped; flip each `Image` once after drawing.
- **Rounding:** Compatibility's canvas output rounds a 5-bit level such as 20/31 (164.5/255) up to
  165 where the browser writes 164; harmless, and the source of most ±1 differences.
- No Environment fog, ambient, glow or tone mapping is used (the shader does light and fog), so the
  ambient-with-shadowed-light and fog-in-both-passes traps don't arise here.
