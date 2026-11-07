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
