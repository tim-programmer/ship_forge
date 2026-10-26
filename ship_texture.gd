extends RefCounted
## Procedural hull texture: panels, paint stripe, grime and glowing windows.


static func hash2(x: int, y: int, s: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + s * 144665
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func build(p: Dictionary, size: int) -> Dictionary:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var emi := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	emi.fill(Color.BLACK)

	var noise := FastNoiseLite.new()
	noise.seed = int(p.seed)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 6.0 / size
	var grime_img := noise.get_seamless_image(size, size)

	var hull: Color = p.hull_col
	var accent: Color = p.accent_col
	var window: Color = p.window_col
	var grime_col := Color(0.07, 0.06, 0.05)
	var cells: int = int(p.panels)
	var seed_i: int = int(p.seed)
	var panel_var: float = p.panel_var
	var line_dark: float = p.line_dark
	var line_px: float = float(p.line_width) * size / 256.0
	var stripe_pos: float = p.stripe_pos
	var stripe_half: float = float(p.stripe_width) * 0.5
	var grime: float = p.grime
	# Squared so the low end of the slider is much sparser.
	var win_density: float = pow(float(p.window_density), 2.0)

	for y in size:
		var v := float(y) / size
		var py := v * cells
		var cy := int(floor(py))
		var fy := py - cy
		for x in size:
			var u := float(x) / size
			var px := u * cells
			var cx := int(floor(px))
			var fx := px - cx

			# Per-panel brightness variation.
			var k := 1.0 + (hash2(cx, cy, seed_i) - 0.5) * 2.0 * panel_var
			var col := Color(hull.r * k, hull.g * k, hull.b * k)

			# Painted stripe.
			var in_stripe := absf(v - stripe_pos) < stripe_half
			if in_stripe:
				col = Color(accent.r * k, accent.g * k, accent.b * k)

			# Glowing window strips.
			if not in_stripe and hash2(cx, cy, seed_i + 7) < win_density \
					and fx > 0.15 and fx < 0.85 and fy > 0.4 and fy < 0.6:
				col = Color(0.02, 0.03, 0.05)
				emi.set_pixel(x, y, window)

			# Panel seams.
			var edge := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy)) * size / cells
			if edge < line_px:
				col = col.lerp(Color.BLACK, line_dark)

			# Grime.
			var g := grime_img.get_pixel(x, y).r
			col = col.lerp(grime_col, clampf((g - 0.45) * 2.0, 0.0, 1.0) * grime)

			img.set_pixel(x, y, col)

	img.generate_mipmaps()
	emi.generate_mipmaps()
	return {
		"albedo": ImageTexture.create_from_image(img),
		"emission": ImageTexture.create_from_image(emi),
		"albedo_img": img,
		"emission_img": emi,
	}
