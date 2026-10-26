extends RefCounted
## Procedural spaceship geometry, built entirely from the parameter dictionary `p`.
## Ship nose points down -Z (Godot's "forward"), engines are at +Z.

const RINGS := 56


# --- hull shape -------------------------------------------------------------

## Radius multiplier (0..~1) of the fuselage at t in [0, 1] from nose to tail.
static func profile(p: Dictionary, t: float) -> float:
	var steps := int(p.hull_steps)
	if steps > 0:
		t = (minf(floorf(t * steps), steps - 1.0) + 0.5) / steps
	var nose_len: float = maxf(p.nose_len, 0.02)
	var tail_len: float = maxf(p.tail_len, 0.02)
	var f := 1.0
	if t < nose_len:
		f = pow(sin(t / nose_len * PI * 0.5), float(p.nose_round))
	if t > 1.0 - tail_len:
		var k := smoothstep(0.0, 1.0, (t - (1.0 - tail_len)) / tail_len)
		f *= lerpf(1.0, float(p.tail_scale), k)
	var bulge: float = p.bulge
	f *= 1.0 + bulge * sin(t * PI)
	return f


static func z_at(p: Dictionary, t: float) -> float:
	var half: float = float(p.length) * 0.5
	return lerpf(-half, half, t)


## Point on the fuselage cross-section (a super-ellipse) at angle `a`.
static func section(p: Dictionary, t: float, a: float) -> Vector3:
	var f: float = profile(p, t)
	var sides := int(p.hull_sides)
	var c := cos(a)
	var s := sin(a)
	var x: float
	var y: float
	if sides < 12:
		# Faceted hull: regular polygon scaled so the flat faces sit at the nominal size.
		var k := 1.0 / cos(PI / sides)
		x = c * float(p.width) * 0.5 * f * k
		y = s * float(p.height) * 0.5 * f * k
	else:
		var ex: float = 2.0 / float(p.squareness)
		x = signf(c) * pow(absf(c), ex) * float(p.width) * 0.5 * f
		y = signf(s) * pow(absf(s), ex) * float(p.height) * 0.5 * f
	if y < 0.0:
		y *= float(p.belly)
	x += float(p.asymmetry) * sin(t * 3.0) * float(p.width) * 0.12
	return Vector3(x, y, z_at(p, t))


# --- triangle helpers -------------------------------------------------------

static func uv_for(v: Vector3, axis: int, s: float) -> Vector2:
	match axis:
		0:
			return Vector2(v.z, -v.y) * s
		1:
			return Vector2(v.x, v.z) * s
		_:
			return Vector2(v.x, -v.y) * s


## Adds one triangle. Winding is corrected so the face points away from `center`,
## and a planar UV is projected along the face's dominant axis.
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3,
		col: Color, smooth: bool, uvs: float) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - center) > 0.0:
		var tmp := b
		b = c
		c = tmp
	var an := n.abs()
	var axis := 2
	if an.x >= an.y and an.x >= an.z:
		axis = 0
	elif an.y >= an.z:
		axis = 1
	st.set_smooth_group(0 if smooth else -1)
	st.set_color(col)
	for v in [a, b, c]:
		st.set_uv(uv_for(v, axis, uvs))
		st.add_vertex(v)


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		center: Vector3, col: Color, smooth: bool, uvs: float) -> void:
	tri(st, a, b, c, center, col, smooth, uvs)
	tri(st, a, c, d, center, col, smooth, uvs)


## Solid between two 4-point loops (a hexahedron). Used for wings, fins and boxes.
static func prism(st: SurfaceTool, bot: PackedVector3Array, top: PackedVector3Array,
		col: Color, uvs: float) -> void:
	var center := Vector3.ZERO
	for v in bot:
		center += v
	for v in top:
		center += v
	center /= 8.0
	quad(st, bot[0], bot[1], bot[2], bot[3], center, col, false, uvs)
	quad(st, top[0], top[1], top[2], top[3], center, col, false, uvs)
	for i in 4:
		var j := (i + 1) % 4
		quad(st, bot[i], bot[j], top[j], top[i], center, col, false, uvs)


static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, uvs: float) -> void:
	var h := s * 0.5
	var bot := PackedVector3Array([
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, -h.y, h.z), c + Vector3(-h.x, -h.y, h.z)])
	var top := PackedVector3Array([
		c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z),
		c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)])
	prism(st, bot, top, col, uvs)


# --- parts ------------------------------------------------------------------

static func wing(st: SurfaceTool, side: float, x0: float, z_le: float, y: float,
		span: float, c_root: float, c_tip: float, sweep: float, thick: float,
		dihedral: float, col: Color, uvs: float) -> void:
	var x1 := x0 + span
	var yt := y + dihedral
	var th_t := thick * 0.4
	var bot := PackedVector3Array([
		Vector3(side * x0, y - thick * 0.5, z_le),
		Vector3(side * x0, y - thick * 0.5, z_le + c_root),
		Vector3(side * x1, yt - th_t * 0.5, z_le + sweep + c_tip),
		Vector3(side * x1, yt - th_t * 0.5, z_le + sweep)])
	var top := PackedVector3Array([
		Vector3(side * x0, y + thick * 0.5, z_le),
		Vector3(side * x0, y + thick * 0.5, z_le + c_root),
		Vector3(side * x1, yt + th_t * 0.5, z_le + sweep + c_tip),
		Vector3(side * x1, yt + th_t * 0.5, z_le + sweep)])
	prism(st, bot, top, col, uvs)


## A tail fin sticking out of the hull at `ang` radians around the Z axis (0 = straight up).
static func fin(st: SurfaceTool, ang: float, r0: float, z_le: float, height: float,
		chord_root: float, chord_tip: float, sweep: float, thick: float,
		col: Color, uvs: float) -> void:
	var h := thick * 0.5
	var plan: Array[Vector2] = [
		Vector2(r0, z_le), Vector2(r0, z_le + chord_root),
		Vector2(r0 + height, z_le + sweep + chord_tip), Vector2(r0 + height, z_le + sweep)]
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for q in plan:
		left.append(Vector3(-h, q.x, q.y).rotated(Vector3.BACK, ang))
		right.append(Vector3(h, q.x, q.y).rotated(Vector3.BACK, ang))
	prism(st, left, right, col, uvs)


## Engine nacelle ending in a flared nozzle. `pos` is the centre of the nozzle opening.
static func engine(st: SurfaceTool, pos: Vector3, r: float, eng_len: float,
		col: Color, uvs: float) -> void:
	var mult := [0.8, 1.0, 1.0, 1.25]
	var frac := [-1.0, -0.55, -0.15, 0.0]
	var n := 16
	var rings: Array = []
	for i in mult.size():
		var ring := PackedVector3Array()
		for j in n:
			var a := TAU * j / n
			ring.append(Vector3(pos.x + cos(a) * r * mult[i], pos.y + sin(a) * r * mult[i],
				pos.z + eng_len * frac[i]))
		rings.append(ring)
	for i in mult.size() - 1:
		var center := Vector3(pos.x, pos.y, pos.z + eng_len * (frac[i] + frac[i + 1]) * 0.5)
		for j in n:
			var j2 := (j + 1) % n
			quad(st, rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j],
				center, col, true, uvs)
	var front: PackedVector3Array = rings[0]
	var fc := Vector3(pos.x, pos.y, pos.z - eng_len)
	for j in n:
		tri(st, fc, front[j], front[(j + 1) % n], pos, col, false, uvs)


## Point `u` (0..1) of the way along the hull edge between angles a_lo and a_hi.
## Interpolating between ring vertices keeps plates flat on faceted hulls.
static func plate_pt(p: Dictionary, t: float, a_lo: float, a_hi: float, u: float) -> Vector3:
	return section(p, t, a_lo).lerp(section(p, t, a_hi), u)


## Box placed relative to `c` along three principal axes (a, b, n) instead of x, y, z.
static func axis_box(st: SurfaceTool, c: Vector3, a: Vector3, b: Vector3, n: Vector3,
		ca: float, cb: float, cn: float, sa: float, sb: float, sn: float,
		col: Color, uvs: float) -> void:
	var size := a.abs() * sa + b.abs() * sb + n.abs() * sn
	box(st, c + a * ca + b * cb + n * cn, size, col, uvs)


## Frame around a hangar opening. `n` points out of the hull, `a` runs along the long side
## of the opening and `b` along the short side. Returns where to put the glowing door.
static func hangar(st: SurfaceTool, origin: Vector3, n: Vector3, a: Vector3, b: Vector3,
		hs: float, col: Color, uvs: float) -> Dictionary:
	var la := 3.0 * hs
	var lb := 1.2 * hs
	var bt := 0.25 * hs
	var d := 0.35 * hs
	var c := origin + n * d * 0.35
	for sgn in [-1.0, 1.0]:
		axis_box(st, c, a, b, n, 0.0, sgn * (lb * 0.5 + bt * 0.5), 0.0, la + 2.0 * bt, bt, d, col, uvs)
		axis_box(st, c, a, b, n, sgn * (la * 0.5 + bt * 0.5), 0.0, 0.0, bt, lb, d, col, uvs)
	var rot := Vector3.ZERO
	var qsize := Vector2(la, lb)
	if absf(n.x) > 0.5:
		rot = Vector3(0, 90.0 * signf(n.x), 0)
	else:
		rot = Vector3(90, 0, 0)
		qsize = Vector2(lb, la)
	return {"pos": origin + n * d * 0.5, "rot": rot, "size": qsize}


# --- full ship --------------------------------------------------------------

static func build(p: Dictionary) -> Dictionary:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var uvs: float = p.tex_scale
	var part_col: Color = p.part_col
	var hull_col := Color.WHITE
	var dark := Color(0.16, 0.16, 0.19)
	var length: float = p.length
	var width: float = p.width
	var height: float = p.height

	# Fuselage: stacked rings, smooth-shaded.
	var sides := int(p.hull_sides)
	var smooth := sides >= 12
	var a0 := 0.0 if smooth else 0.5
	var asym: float = p.asymmetry
	var rings: Array = []
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var ring := PackedVector3Array()
		for j in sides:
			ring.append(section(p, t, TAU * (j + a0) / sides))
		rings.append(ring)
	for i in RINGS:
		var zc := (z_at(p, float(i) / RINGS) + z_at(p, float(i + 1) / RINGS)) * 0.5
		var center := Vector3(0, 0, zc)
		for j in sides:
			var j2 := (j + 1) % sides
			quad(st, rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j],
				center, hull_col, smooth, uvs)
	# Rear and nose caps (the nose only has one when the hull is blunt or stepped).
	var last: PackedVector3Array = rings[RINGS]
	var cap_c := Vector3(0, 0, z_at(p, 1.0))
	for j in sides:
		tri(st, cap_c, last[j], last[(j + 1) % sides], cap_c - Vector3(0, 0, 1), hull_col, false, uvs)
	if profile(p, 0.0) > 0.01:
		var first: PackedVector3Array = rings[0]
		var nose_c := Vector3(0, 0, z_at(p, 0.0))
		for j in sides:
			tri(st, nose_c, first[j], first[(j + 1) % sides], nose_c + Vector3(0, 0, 1), hull_col, false, uvs)

	# Main wings.
	if float(p.wing_span) > 0.05:
		var wz := z_at(p, p.wing_pos)
		var wx0: float = width * 0.5 * profile(p, p.wing_pos) * 0.35
		var wy: float = float(p.wing_y) * height * 0.5
		for side in [-1.0, 1.0]:
			var k := 1.0 - asym * 0.45 if side > 0.0 else 1.0 + asym * 0.15
			wing(st, side, wx0, wz, wy, float(p.wing_span) * k, p.wing_chord,
				float(p.wing_chord) * float(p.wing_taper), float(p.wing_sweep) * k, p.wing_thick,
				p.wing_dihedral, part_col, uvs)

	# Canards (small forward wings).
	if float(p.canard_span) > 0.05:
		var cz := z_at(p, p.canard_pos)
		var cx0: float = width * 0.5 * profile(p, p.canard_pos) * 0.35
		for side in [-1.0, 1.0]:
			wing(st, side, cx0, cz, 0.0, p.canard_span, p.canard_chord,
				float(p.canard_chord) * 0.5, p.canard_sweep, float(p.wing_thick) * 0.7,
				0.0, part_col, uvs)

	# Tail fins.
	var fin_count := int(p.fin_count)
	if fin_count > 0:
		var splay := deg_to_rad(float(p.fin_splay))
		var angles: Array[float] = []
		match fin_count:
			1:
				angles = [0.0]
			2:
				angles = [-splay, splay]
			_:
				angles = [-splay, 0.0, splay]
		var fz := z_at(p, p.fin_pos)
		var r0: float = height * 0.5 * profile(p, p.fin_pos) * 0.6
		for a in angles:
			fin(st, a, r0, fz, p.fin_height, p.fin_chord, float(p.fin_chord) * 0.4,
				p.fin_sweep, p.fin_thick, part_col, uvs)

	# Engines.
	var engines: Array[Vector3] = []
	var eng_n := int(p.engine_count)
	for i in eng_n:
		var ex := (float(i) - (eng_n - 1) * 0.5) * float(p.engine_spacing)
		var pos := Vector3(ex, float(p.engine_y) + asym * 0.8 * sin(i * 2.1),
			length * 0.5 + float(p.engine_out) + asym * 0.6 * cos(i * 1.7))
		engine(st, pos, p.engine_radius, p.engine_len, dark, uvs)
		engines.append(pos)

	# Spires: tapered towers along the top of the hull.
	var spires := int(p.spire_count)
	for i in spires:
		var t := lerpf(0.3, 0.85, (float(i) + 0.5) / spires)
		var zc := z_at(p, t)
		var y0 := height * 0.5 * profile(p, t) * 0.9
		var sh := float(p.spire_height) * (1.0 - 0.15 * i)
		var bw := maxf(0.15, width * 0.05)
		var tw := bw * 0.15
		var bot := PackedVector3Array([
			Vector3(-bw, y0, zc - bw * 1.5), Vector3(bw, y0, zc - bw * 1.5),
			Vector3(bw, y0, zc + bw * 1.5), Vector3(-bw, y0, zc + bw * 1.5)])
		var top := PackedVector3Array([
			Vector3(-tw, y0 + sh, zc - tw), Vector3(tw, y0 + sh, zc - tw),
			Vector3(tw, y0 + sh, zc + tw), Vector3(-tw, y0 + sh, zc + tw)])
		prism(st, bot, top, part_col, uvs)

	# Surface greebles: little boxes scattered over the top of the hull.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed) * 7919 + 13
	var gsize: float = p.greeble_size
	for i in int(p.greeble_count):
		var t := rng.randf_range(0.12, 0.88)
		var f := profile(p, t)
		var xr := rng.randf_range(-0.7, 0.7)
		var gx := xr * width * 0.5 * f
		var gy := height * 0.5 * f * sqrt(1.0 - xr * xr) - gsize * 0.1
		var sz := Vector3(rng.randf_range(0.3, 1.0), rng.randf_range(0.2, 0.7),
			rng.randf_range(0.3, 1.2)) * gsize
		box(st, Vector3(gx, gy, z_at(p, t)), sz, part_col.darkened(0.25), uvs)

	# Turrets: a base, a head and a few barrels, spread over the top of the hull.
	var turret_n := int(p.turret_count)
	var ts: float = p.turret_size
	var barrels := int(p.turret_barrels)
	var barrel_len: float = float(p.barrel_len) * ts
	for i in turret_n:
		var t := lerpf(0.2, 0.8, (float(i) + 0.5) / turret_n)
		var f := profile(p, t)
		var xr := 0.0 if turret_n == 1 else (0.4 if i % 2 == 0 else -0.4)
		var base := Vector3(xr * width * 0.5 * f,
			height * 0.5 * f * sqrt(1.0 - xr * xr) - ts * 0.1, z_at(p, t))
		box(st, base + Vector3(0, ts * 0.25, 0), Vector3(1.2, 0.5, 1.2) * ts,
			part_col.darkened(0.15), uvs)
		var head := base + Vector3(0, ts * 0.7, 0)
		box(st, head, Vector3(0.9, 0.45, 1.1) * ts, part_col, uvs)
		for b in barrels:
			var bx := (float(b) - (barrels - 1) * 0.5) * 0.28 * ts
			box(st, head + Vector3(bx, ts * 0.02, -(0.55 * ts + barrel_len * 0.5)),
				Vector3(0.12 * ts, 0.12 * ts, barrel_len), dark, uvs)

	# Missile launcher pods: blocks on both flanks with a 2x2 grid of tubes up front.
	var launcher_n := int(p.launcher_count)
	var ls: float = p.launcher_size
	for i in launcher_n:
		var t := lerpf(0.3, 0.7, (float(i) + 0.5) / launcher_n)
		var f := profile(p, t)
		for side in [-1.0, 1.0]:
			var lc := Vector3(side * width * 0.5 * f * 0.95, -height * 0.1 * f, z_at(p, t))
			box(st, lc, Vector3(0.8, 0.7, 2.0) * ls, part_col.darkened(0.2), uvs)
			for qx in [-1.0, 1.0]:
				for qy in [-1.0, 1.0]:
					box(st, lc + Vector3(qx * 0.18, qy * 0.17, -1.02) * ls,
						Vector3(0.25, 0.25, 0.15) * ls, dark, uvs)

	# Sensor masts: thin poles with a crossbar and a tip, towards the back of the hull.
	var ah: float = p.antenna_height
	for i in int(p.antenna_count):
		var t := rng.randf_range(0.55, 0.9)
		var f := profile(p, t)
		var xr := rng.randf_range(-0.5, 0.5)
		var mh := rng.randf_range(0.6, 1.0) * ah
		var mb := Vector3(xr * width * 0.5 * f,
			height * 0.5 * f * sqrt(1.0 - xr * xr) - 0.1, z_at(p, t))
		box(st, mb + Vector3(0, mh * 0.5, 0), Vector3(0.08, mh, 0.08), dark, uvs)
		box(st, mb + Vector3(0, mh * 0.8, 0), Vector3(rng.randf_range(0.6, 1.6), 0.06, 0.06), dark, uvs)
		box(st, mb + Vector3(0, mh, 0), Vector3(0.16, 0.16, 0.16), part_col, uvs)

	# Armor plating: flat slabs laid over the top and flanks, with gaps between them.
	var armor_rows := int(p.armor_rows)
	if armor_rows > 0:
		var thick := 1.0 + float(p.armor_thick)
		var gap: float = p.armor_gap
		var cols := sides if sides < 12 else 8
		var plate_col := part_col.darkened(0.05)
		var u0 := 0.5 - 0.5 * (1.0 - gap)
		var u1 := 0.5 + 0.5 * (1.0 - gap)
		for r in armor_rows:
			var ta := lerpf(0.12, 0.92, float(r) / armor_rows)
			var tb := lerpf(0.12, 0.92, float(r + 1) / armor_rows)
			var tm := (ta + tb) * 0.5
			var hd := (tb - ta) * 0.5 * (1.0 - gap)
			for ci in cols:
				var a_lo: float
				var a_hi: float
				if sides < 12:
					a_lo = TAU * (ci + a0) / sides
					a_hi = TAU * (ci + 1 + a0) / sides
				else:
					a_lo = lerpf(-0.3, PI + 0.3, float(ci) / cols)
					a_hi = lerpf(-0.3, PI + 0.3, float(ci + 1) / cols)
				var am := (a_lo + a_hi) * 0.5
				if am > TAU - 0.35:
					am -= TAU
				if am < -0.35 or am > PI + 0.35:
					continue
				var bot := PackedVector3Array([
					plate_pt(p, tm - hd, a_lo, a_hi, u0), plate_pt(p, tm - hd, a_lo, a_hi, u1),
					plate_pt(p, tm + hd, a_lo, a_hi, u1), plate_pt(p, tm + hd, a_lo, a_hi, u0)])
				var top := PackedVector3Array()
				for i in 4:
					top.append(bot[i] * Vector3(thick, thick, 1.0))
					bot[i] *= Vector3(0.99, 0.99, 1.0)
				prism(st, bot, top, plate_col, uvs)

	# Hangars: 1 = belly, 2 = both flanks, 3 = flanks + belly.
	var hangars: Array[Dictionary] = []
	var hangar_n := int(p.hangar_count)
	if hangar_n > 0:
		var ht: float = p.hangar_pos
		var hf := profile(p, ht)
		var hz := z_at(p, ht)
		var hs: float = p.hangar_size
		var hcol := part_col.lightened(0.1)
		if hangar_n >= 2:
			for sgn in [-1.0, 1.0]:
				hangars.append(hangar(st, Vector3(sgn * width * 0.5 * hf, 0, hz),
					Vector3(sgn, 0, 0), Vector3.BACK, Vector3.UP, hs, hcol, uvs))
		if hangar_n != 2:
			hangars.append(hangar(st, Vector3(0, -height * 0.5 * hf * float(p.belly), hz),
				Vector3.DOWN, Vector3.BACK, Vector3.RIGHT, hs, hcol, uvs))

	# Exposed struts: long thin beams lying along the outside of the hull.
	for i in int(p.strut_count):
		var a := rng.randf_range(0.0, TAU)
		var len_f := rng.randf_range(0.2, 0.5)
		var tc := rng.randf_range(len_f * 0.5, 1.0 - len_f * 0.5)
		var hp := section(p, tc, a)
		var th := 0.25 * gsize + 0.05
		box(st, Vector3(hp.x * 1.06, hp.y * 1.06, hp.z), Vector3(th, th, len_f * length),
			part_col.darkened(0.3), uvs)

	st.generate_normals()

	# Rough half-extents of the whole ship, used to size the shield bubble.
	var top_extra := 0.0
	if fin_count > 0:
		top_extra = maxf(top_extra, float(p.fin_height))
	if spires > 0:
		top_extra = maxf(top_extra, float(p.spire_height))
	if int(p.antenna_count) > 0:
		top_extra = maxf(top_extra, ah)
	if turret_n > 0:
		top_extra = maxf(top_extra, ts * 1.2)
	var hx := maxf(width * 0.5, width * 0.2 + maxf(float(p.wing_span), float(p.canard_span)))
	var hy := height * 0.5 + top_extra * 0.5
	var out_z := maxf(float(p.engine_out), 0.0) if eng_n > 0 else 0.0
	var cs: float = p.cockpit_size
	var ct: float = p.cockpit_pos
	return {
		"bounds": Vector3(hx, hy, length * 0.5 + out_z * 0.5),
		"center": Vector3(0, top_extra * 0.25, out_z * 0.5),
		"hangars": hangars,
		"mesh": st.commit(),
		"engines": engines,
		"engine_r": float(p.engine_radius) * 0.85,
		"cockpit_pos": Vector3(0, height * 0.5 * profile(p, ct) * 0.7, z_at(p, ct)),
		"cockpit_scale": Vector3(width * 0.5, height * 0.45, length * 0.2) * cs,
	}
