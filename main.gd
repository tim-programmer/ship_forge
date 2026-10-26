extends Node3D
## Ship Forge: tweak numbers, get a textured spaceship.

const ShipMesh = preload("res://ship_mesh.gd")
const ShipTexture = preload("res://ship_texture.gd")

# group, key, label, min, max, step, default, kind
# kind: "mesh" rebuilds geometry, "tex" regenerates the texture,
#       "mat" only updates material values, "both" does mesh + texture.
const SLIDERS := [
	["Hull", "length", "Length", 6.0, 30.0, 0.1, 14.0, "mesh"],
	["Hull", "width", "Width", 1.0, 12.0, 0.1, 4.0, "mesh"],
	["Hull", "height", "Height", 0.8, 8.0, 0.1, 2.4, "mesh"],
	["Hull", "nose_len", "Nose length", 0.05, 0.8, 0.01, 0.35, "mesh"],
	["Hull", "nose_round", "Nose bluntness (high = pointy)", 0.4, 2.5, 0.05, 1.0, "mesh"],
	["Hull", "tail_len", "Tail taper length", 0.05, 0.8, 0.01, 0.3, "mesh"],
	["Hull", "tail_scale", "Tail size", 0.0, 1.2, 0.01, 0.7, "mesh"],
	["Hull", "bulge", "Mid-body bulge", -0.3, 0.8, 0.01, 0.15, "mesh"],
	["Hull", "squareness", "Squareness (2 = round)", 2.0, 6.0, 0.1, 2.6, "mesh"],
	["Hull", "belly", "Belly depth", 0.2, 1.5, 0.01, 0.7, "mesh"],
	["Hull", "hull_sides", "Cross-section sides (32 = round)", 3.0, 32.0, 1.0, 32.0, "mesh"],
	["Hull", "hull_steps", "Stepped segments (0 = smooth)", 0.0, 12.0, 1.0, 0.0, "mesh"],
	["Hull", "asymmetry", "Asymmetry", 0.0, 1.0, 0.01, 0.0, "mesh"],
	["Wings", "wing_pos", "Position", 0.1, 0.9, 0.01, 0.5, "mesh"],
	["Wings", "wing_span", "Span", 0.0, 16.0, 0.1, 6.0, "mesh"],
	["Wings", "wing_chord", "Root chord", 1.0, 12.0, 0.1, 5.0, "mesh"],
	["Wings", "wing_taper", "Taper (tip / root)", 0.05, 1.0, 0.01, 0.4, "mesh"],
	["Wings", "wing_sweep", "Sweep back", -3.0, 10.0, 0.1, 3.0, "mesh"],
	["Wings", "wing_thick", "Thickness", 0.05, 1.0, 0.01, 0.25, "mesh"],
	["Wings", "wing_dihedral", "Dihedral (tip lift)", -3.0, 4.0, 0.1, 0.5, "mesh"],
	["Wings", "wing_y", "Height on hull", -1.0, 1.0, 0.01, -0.2, "mesh"],
	["Canards", "canard_pos", "Position", 0.05, 0.6, 0.01, 0.2, "mesh"],
	["Canards", "canard_span", "Span", 0.0, 8.0, 0.1, 2.0, "mesh"],
	["Canards", "canard_chord", "Chord", 0.5, 5.0, 0.1, 2.0, "mesh"],
	["Canards", "canard_sweep", "Sweep back", -1.0, 4.0, 0.1, 1.0, "mesh"],
	["Tail fins", "fin_count", "Count", 0.0, 3.0, 1.0, 1.0, "mesh"],
	["Tail fins", "fin_height", "Height", 0.5, 8.0, 0.1, 3.0, "mesh"],
	["Tail fins", "fin_chord", "Chord", 1.0, 10.0, 0.1, 4.0, "mesh"],
	["Tail fins", "fin_sweep", "Sweep back", -1.0, 8.0, 0.1, 2.5, "mesh"],
	["Tail fins", "fin_pos", "Position", 0.3, 0.95, 0.01, 0.7, "mesh"],
	["Tail fins", "fin_splay", "Splay angle (deg)", 0.0, 90.0, 1.0, 35.0, "mesh"],
	["Tail fins", "fin_thick", "Thickness", 0.05, 0.8, 0.01, 0.2, "mesh"],
	["Engines", "engine_count", "Count", 0.0, 4.0, 1.0, 2.0, "mesh"],
	["Engines", "engine_radius", "Radius", 0.2, 2.0, 0.01, 0.8, "mesh"],
	["Engines", "engine_len", "Length", 1.0, 8.0, 0.1, 3.0, "mesh"],
	["Engines", "engine_spacing", "Spacing", 0.5, 5.0, 0.1, 1.8, "mesh"],
	["Engines", "engine_y", "Vertical offset", -1.5, 1.5, 0.01, 0.0, "mesh"],
	["Engines", "engine_out", "Sticks out past tail", -1.0, 2.0, 0.05, 0.3, "mesh"],
	["Cockpit", "cockpit_size", "Size", 0.0, 1.6, 0.01, 1.0, "mesh"],
	["Cockpit", "cockpit_pos", "Position", 0.1, 0.7, 0.01, 0.3, "mesh"],
	["Details", "greeble_count", "Surface bits", 0.0, 150.0, 1.0, 25.0, "mesh"],
	["Details", "greeble_size", "Surface bit size", 0.1, 1.5, 0.01, 0.5, "mesh"],
	["Details", "spire_count", "Spires", 0.0, 6.0, 1.0, 0.0, "mesh"],
	["Details", "spire_height", "Spire height", 1.0, 12.0, 0.1, 5.0, "mesh"],
	["Details", "strut_count", "Exposed struts", 0.0, 24.0, 1.0, 0.0, "mesh"],
	["Details", "seed", "Random seed", 0.0, 999.0, 1.0, 1.0, "both"],
	["Surface", "metallic", "Metallic", 0.0, 1.0, 0.01, 0.6, "mat"],
	["Surface", "roughness", "Roughness", 0.0, 1.0, 0.01, 0.45, "mat"],
	["Surface", "emission_energy", "Window glow", 0.0, 8.0, 0.1, 2.0, "mat"],
	["Surface", "tex_scale", "Texture size (small = big pattern)", 0.03, 0.6, 0.01, 0.15, "mesh"],
	["Paint", "panels", "Panel count", 2.0, 40.0, 1.0, 10.0, "tex"],
	["Paint", "panel_var", "Panel shade variation", 0.0, 0.6, 0.01, 0.18, "tex"],
	["Paint", "line_dark", "Seam darkness", 0.0, 1.0, 0.01, 0.5, "tex"],
	["Paint", "line_width", "Seam width", 0.0, 5.0, 0.1, 1.5, "tex"],
	["Paint", "stripe_pos", "Stripe position", 0.0, 1.0, 0.01, 0.5, "tex"],
	["Paint", "stripe_width", "Stripe width", 0.0, 0.5, 0.01, 0.08, "tex"],
	["Paint", "grime", "Grime", 0.0, 1.0, 0.01, 0.5, "tex"],
	["Paint", "window_density", "Window density", 0.0, 1.0, 0.01, 0.25, "tex"],
]

# group, key, label, default, kind
const COLORS := [
	["Colors", "hull_col", "Hull", Color(0.62, 0.66, 0.72), "tex"],
	["Colors", "accent_col", "Stripe", Color(0.85, 0.25, 0.12), "tex"],
	["Colors", "window_col", "Windows", Color(1.0, 0.85, 0.5), "tex"],
	["Colors", "part_col", "Wings / fins tint", Color(0.8, 0.8, 0.85), "mesh"],
	["Colors", "engine_col", "Engine glow", Color(0.4, 0.7, 1.0), "mat"],
	["Colors", "cockpit_col", "Cockpit glass", Color(0.1, 0.25, 0.4), "mat"],
]

# Faction looks. Each preset resets everything to defaults, then applies these overrides.
const FACTIONS := {
	"Caldari": {
		"length": 16.0, "width": 5.0, "height": 3.6, "hull_sides": 4.0, "hull_steps": 5.0,
		"nose_len": 0.3, "tail_len": 0.25, "tail_scale": 0.8, "bulge": 0.0, "belly": 1.0,
		"wing_span": 0.0, "canard_span": 0.0, "fin_count": 0.0,
		"engine_count": 4.0, "engine_radius": 0.6, "engine_spacing": 1.4, "engine_len": 2.5,
		"greeble_count": 45.0, "greeble_size": 0.6,
		"panels": 6.0, "panel_var": 0.1, "line_dark": 0.7, "line_width": 2.0,
		"stripe_width": 0.04, "grime": 0.25, "window_density": 0.2,
		"metallic": 0.7, "roughness": 0.5,
		"hull_col": Color(0.38, 0.45, 0.55), "accent_col": Color(0.2, 0.55, 0.85),
		"window_col": Color(0.7, 0.85, 1.0), "part_col": Color(0.5, 0.55, 0.62),
		"engine_col": Color(0.4, 0.7, 1.0),
	},
	"Gallente": {
		"length": 13.0, "width": 6.0, "height": 4.2, "hull_sides": 32.0,
		"nose_len": 0.45, "nose_round": 0.7, "tail_len": 0.35, "tail_scale": 0.5,
		"bulge": 0.35, "squareness": 2.0, "belly": 1.0,
		"wing_span": 3.5, "wing_chord": 5.0, "wing_taper": 0.5, "wing_sweep": 2.0,
		"wing_thick": 0.5, "wing_dihedral": 0.0, "wing_y": -0.4,
		"canard_span": 0.0, "fin_count": 0.0,
		"engine_count": 1.0, "engine_radius": 1.3, "engine_len": 3.0,
		"greeble_count": 12.0, "panels": 5.0, "panel_var": 0.12, "line_dark": 0.3,
		"stripe_pos": 0.6, "stripe_width": 0.1, "grime": 0.3, "window_density": 0.1,
		"metallic": 0.5, "roughness": 0.4,
		"hull_col": Color(0.38, 0.5, 0.42), "accent_col": Color(0.75, 0.8, 0.3),
		"window_col": Color(0.7, 1.0, 0.7), "part_col": Color(0.3, 0.38, 0.33),
		"engine_col": Color(0.4, 1.0, 0.6),
	},
	"Amarr": {
		"length": 20.0, "width": 4.5, "height": 3.2, "hull_sides": 8.0,
		"nose_len": 0.4, "nose_round": 1.6, "tail_len": 0.2, "tail_scale": 0.6,
		"bulge": 0.3, "belly": 0.8,
		"wing_pos": 0.45, "wing_span": 4.0, "wing_chord": 6.0, "wing_taper": 0.3,
		"wing_sweep": 5.0, "wing_thick": 0.35, "wing_dihedral": 1.5, "wing_y": 0.1,
		"canard_span": 2.5, "canard_chord": 2.0, "canard_sweep": 2.0, "fin_count": 0.0,
		"spire_count": 4.0, "spire_height": 5.0,
		"engine_count": 3.0, "engine_radius": 0.7, "engine_spacing": 1.6,
		"greeble_count": 30.0, "greeble_size": 0.4,
		"panels": 14.0, "panel_var": 0.15, "line_dark": 0.4, "stripe_width": 0.15,
		"grime": 0.15, "window_density": 0.3,
		"metallic": 0.9, "roughness": 0.3,
		"hull_col": Color(0.78, 0.6, 0.22), "accent_col": Color(0.45, 0.12, 0.08),
		"window_col": Color(1.0, 0.8, 0.4), "part_col": Color(0.7, 0.55, 0.25),
		"engine_col": Color(1.0, 0.65, 0.25),
	},
	"Minmatar": {
		"length": 15.0, "width": 3.2, "height": 2.6, "hull_sides": 6.0,
		"nose_len": 0.3, "nose_round": 0.8, "tail_len": 0.3, "tail_scale": 0.6,
		"bulge": 0.1, "belly": 0.9, "asymmetry": 0.7,
		"wing_pos": 0.55, "wing_span": 5.0, "wing_chord": 3.5, "wing_taper": 0.3,
		"wing_sweep": 4.0, "wing_thick": 0.2, "wing_dihedral": 1.0,
		"canard_span": 3.0, "canard_chord": 1.5, "canard_sweep": 2.0,
		"fin_count": 2.0, "fin_height": 3.5, "fin_chord": 3.0, "fin_splay": 55.0,
		"engine_count": 2.0, "engine_radius": 0.9, "engine_spacing": 2.0, "engine_len": 4.0,
		"strut_count": 14.0, "greeble_count": 40.0,
		"panels": 8.0, "panel_var": 0.4, "line_dark": 0.6, "line_width": 2.5,
		"stripe_pos": 0.3, "stripe_width": 0.1, "grime": 0.85, "window_density": 0.08,
		"metallic": 0.5, "roughness": 0.7,
		"hull_col": Color(0.5, 0.33, 0.24), "accent_col": Color(0.75, 0.2, 0.1),
		"window_col": Color(1.0, 0.6, 0.3), "part_col": Color(0.42, 0.3, 0.24),
		"engine_col": Color(1.0, 0.5, 0.2),
	},
}

const NO_RANDOM := ["tex_scale", "metallic", "roughness", "emission_energy"]
const TEX_SIZES := [256, 512, 1024]

var params := {}
var controls := {}   # key -> HSlider or ColorPickerButton
var value_labels := {}  # key -> Label

var ship_root: Node3D
var mesh_inst: MeshInstance3D
var cockpit: MeshInstance3D
var glows: Array[MeshInstance3D] = []
var mat := StandardMaterial3D.new()
var glow_mat := StandardMaterial3D.new()
var cockpit_mat := StandardMaterial3D.new()
var albedo_img: Image
var emission_img: Image

var cam: Camera3D
var yaw := -0.7
var pitch := 0.3
var dist := 24.0
var auto_rotate := true

var tex_timer: Timer
var tex_res := 256
var status: Label


func _ready() -> void:
	for s in SLIDERS:
		params[s[1]] = s[6]
	for c in COLORS:
		params[c[1]] = c[3]

	_build_world()
	_build_ui()
	rebuild_mesh()
	apply_material()
	rebuild_texture()


# --- scene ------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.06, 0.14)
	sky_mat.sky_horizon_color = Color(0.3, 0.33, 0.45)
	sky_mat.ground_horizon_color = Color(0.3, 0.33, 0.45)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.05)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)

	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)

	ship_root = Node3D.new()
	ship_root.name = "Ship"
	add_child(ship_root)

	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color.BLACK  # Godot ADDS this to the emission texture, so it must be black
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "Hull"
	mesh_inst.material_override = mat
	ship_root.add_child(mesh_inst)

	cockpit_mat.metallic = 0.9
	cockpit_mat.roughness = 0.08
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	cockpit = MeshInstance3D.new()
	cockpit.name = "Cockpit"
	cockpit.mesh = sphere
	cockpit.material_override = cockpit_mat
	ship_root.add_child(cockpit)

	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled = true
	glow_mat.emission_energy_multiplier = 3.0

	tex_timer = Timer.new()
	tex_timer.one_shot = true
	tex_timer.wait_time = 0.25
	tex_timer.timeout.connect(rebuild_texture)
	add_child(tex_timer)

	_update_camera()


func _update_camera() -> void:
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	cam.look_at_from_position(dir * dist, Vector3.ZERO, Vector3.UP)


func _process(delta: float) -> void:
	if auto_rotate:
		yaw += delta * 0.35
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= mm.relative.x * 0.008
			pitch = clampf(pitch + mm.relative.y * 0.008, -1.4, 1.4)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist * 0.92, 3.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist * 1.08, 200.0)


# --- building the ship ------------------------------------------------------

func rebuild_mesh() -> void:
	var res := ShipMesh.build(params)
	mesh_inst.mesh = res.mesh
	cockpit.visible = float(params.cockpit_size) > 0.01
	cockpit.position = res.cockpit_pos
	cockpit.scale = res.cockpit_scale

	for g in glows:
		ship_root.remove_child(g)
		g.queue_free()
	glows.clear()
	var disc := CylinderMesh.new()
	disc.top_radius = res.engine_r
	disc.bottom_radius = res.engine_r
	disc.height = 0.06
	disc.radial_segments = 24
	disc.rings = 1
	for pos in res.engines:
		var g := MeshInstance3D.new()
		g.name = "EngineGlow"
		g.mesh = disc
		g.material_override = glow_mat
		g.rotation_degrees = Vector3(90, 0, 0)
		g.position = pos + Vector3(0, 0, 0.03)
		ship_root.add_child(g)
		glows.append(g)


func rebuild_texture() -> void:
	var res := ShipTexture.build(params, tex_res)
	mat.albedo_texture = res.albedo
	mat.emission_texture = res.emission
	albedo_img = res.albedo_img
	emission_img = res.emission_img


func apply_material() -> void:
	mat.metallic = params.metallic
	mat.roughness = params.roughness
	mat.emission_energy_multiplier = params.emission_energy
	glow_mat.albedo_color = params.engine_col
	glow_mat.emission = params.engine_col
	cockpit_mat.albedo_color = params.cockpit_col


func _changed(kind: String) -> void:
	match kind:
		"mesh":
			rebuild_mesh()
		"tex":
			tex_timer.start()
		"mat":
			apply_material()
		"both":
			rebuild_mesh()
			tex_timer.start()


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	margin.add_child(root)

	var title := Label.new()
	title.text = "SHIP FORGE"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var style_row := HBoxContainer.new()
	root.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style: "
	style_row.add_child(style_label)
	var style_opt := OptionButton.new()
	style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_opt.add_item("Pick a faction look...")
	for f in FACTIONS:
		style_opt.add_item(f)
	style_opt.item_selected.connect(func(i: int) -> void:
		if i > 0:
			apply_faction(FACTIONS.keys()[i - 1]))
	style_row.add_child(style_opt)

	var row1 := HBoxContainer.new()
	root.add_child(row1)
	_add_button(row1, "Randomize", randomize_ship)
	_add_button(row1, "Export .glb", export_glb)
	var row2 := HBoxContainer.new()
	root.add_child(row2)
	_add_button(row2, "Save preset", save_preset)
	_add_button(row2, "Load preset", load_preset)

	var row3 := HBoxContainer.new()
	root.add_child(row3)
	var rot := CheckBox.new()
	rot.text = "Auto-rotate"
	rot.button_pressed = auto_rotate
	rot.toggled.connect(func(on: bool) -> void: auto_rotate = on)
	row3.add_child(rot)
	var res_label := Label.new()
	res_label.text = "  Texture:"
	row3.add_child(res_label)
	var res_opt := OptionButton.new()
	for s in TEX_SIZES:
		res_opt.add_item("%d px" % s)
	res_opt.item_selected.connect(func(i: int) -> void:
		tex_res = TEX_SIZES[i]
		tex_timer.start())
	row3.add_child(res_opt)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Drag to orbit, wheel to zoom."
	root.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var group := ""
	for s in SLIDERS:
		if s[0] != group:
			group = s[0]
			_add_header(list, group)
		_add_slider(list, s)
	group = ""
	for c in COLORS:
		if c[0] != group:
			group = c[0]
			_add_header(list, group)
		_add_color(list, c)


func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_header(parent: Control, text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	parent.add_child(sp)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	parent.add_child(l)
	parent.add_child(HSeparator.new())


func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%.2f" % v


func _add_slider(parent: Control, s: Array) -> void:
	var key: String = s[1]
	var step: float = s[5]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = s[2]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_l := Label.new()
	val_l.text = _fmt(params[key], step)
	top.add_child(name_l)
	top.add_child(val_l)
	var sl := HSlider.new()
	sl.min_value = s[3]
	sl.max_value = s[4]
	sl.step = step
	sl.value = params[key]
	sl.value_changed.connect(_on_slider.bind(key, step, s[7]))
	box.add_child(top)
	box.add_child(sl)
	parent.add_child(box)
	controls[key] = sl
	value_labels[key] = val_l


func _on_slider(v: float, key: String, step: float, kind: String) -> void:
	params[key] = v
	value_labels[key].text = _fmt(v, step)
	_changed(kind)


func _add_color(parent: Control, c: Array) -> void:
	var key: String = c[1]
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = c[2]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cp := ColorPickerButton.new()
	cp.custom_minimum_size = Vector2(70, 26)
	cp.edit_alpha = false
	cp.color = params[key]
	cp.color_changed.connect(_on_color.bind(key, c[4]))
	row.add_child(l)
	row.add_child(cp)
	parent.add_child(row)
	controls[key] = cp


func _on_color(color: Color, key: String, kind: String) -> void:
	params[key] = color
	_changed(kind)


# --- actions ----------------------------------------------------------------

func _set_param(key: String, v: Variant) -> void:
	params[key] = v
	var ctl: Control = controls[key]
	if ctl is HSlider:
		(ctl as HSlider).set_value_no_signal(v)
		for s in SLIDERS:
			if s[1] == key:
				value_labels[key].text = _fmt(v, s[5])
	elif ctl is ColorPickerButton:
		(ctl as ColorPickerButton).color = v


func apply_faction(faction: String) -> void:
	for s in SLIDERS:
		_set_param(s[1], s[6])
	for c in COLORS:
		_set_param(c[1], c[3])
	var over: Dictionary = FACTIONS[faction]
	for k in over:
		_set_param(k, over[k])
	_set_param("seed", randi() % 1000)
	rebuild_mesh()
	apply_material()
	tex_timer.start()
	status.text = faction + " style. Tweak anything from here."


func randomize_ship() -> void:
	for s in SLIDERS:
		var key: String = s[1]
		if key in NO_RANDOM:
			continue
		var lo: float = s[3]
		var hi: float = s[4]
		var margin := (hi - lo) * 0.1
		_set_param(key, snappedf(randf_range(lo + margin, hi - margin), s[5]))
	_set_param("hull_col", Color.from_hsv(randf(), randf_range(0.0, 0.45), randf_range(0.4, 0.9)))
	_set_param("accent_col", Color.from_hsv(randf(), randf_range(0.6, 0.95), randf_range(0.6, 1.0)))
	_set_param("window_col", Color.from_hsv(randf_range(0.05, 0.2), 0.5, 1.0))
	_set_param("engine_col", Color.from_hsv(randf(), 0.6, 1.0))
	rebuild_mesh()
	apply_material()
	tex_timer.start()


func export_glb() -> void:
	var dir := "user://exports"
	DirAccess.make_dir_recursive_absolute(dir)
	var base := "%s/ship_%s" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(ship_root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, base + ".glb")
	albedo_img.save_png(base + "_albedo.png")
	emission_img.save_png(base + "_emission.png")
	_write_json(base + "_params.json")
	if err == OK:
		status.text = "Exported to:\n" + ProjectSettings.globalize_path(base + ".glb")
	else:
		status.text = "Export failed (error %d)" % err


func _write_json(path: String) -> void:
	var d := {}
	for k in params:
		d[k] = ("#" + params[k].to_html()) if params[k] is Color else params[k]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))


func save_preset() -> void:
	_write_json("user://ship_preset.json")
	status.text = "Saved preset:\n" + ProjectSettings.globalize_path("user://ship_preset.json")


func load_preset() -> void:
	if not FileAccess.file_exists("user://ship_preset.json"):
		status.text = "No saved preset yet."
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://ship_preset.json"))
	if not data is Dictionary:
		status.text = "Preset file is broken."
		return
	for k in data:
		if params.has(k):
			var v = data[k]
			if params[k] is Color:
				v = Color.html(v)
			_set_param(k, v)
	rebuild_mesh()
	apply_material()
	rebuild_texture()
	status.text = "Preset loaded."
