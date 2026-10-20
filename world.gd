extends Node2D
## Static map rendering (drawn once).

var map: Dictionary

func _draw() -> void:
	var w: float = map.w
	var h: float = map.h
	var top: Color = map.cols[0]
	var bot: Color = map.cols[1]
	var solid: Color = map.cols[2]
	var edge: Color = map.cols[3]
	draw_polygon(PackedVector2Array([Vector2(-700, -700), Vector2(w + 700, -700), Vector2(w + 700, h + 700), Vector2(-700, h + 700)]),
		PackedColorArray([top, top, bot, bot]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var dec: int = map.decor
	match dec:
		0:  # base: distant hangars
			for i in 7:
				var x := rng.randf() * w
				draw_rect(Rect2(x, h - 330.0 - rng.randf() * 120.0, 180.0, 330.0), Color(0, 0, 0, 0.10))
		1:  # desert: sun + dunes
			draw_circle(Vector2(w * 0.72, 210), 110, Color(1, 0.95, 0.7, 0.55))
			for i in 6:
				draw_circle(Vector2(i * 480.0, h - 40.0), 320, Color(0.7, 0.45, 0.2, 0.18))
		2:  # jungle: trunks
			for i in 22:
				var x := rng.randf() * w
				draw_rect(Rect2(x, 0, 24.0 + rng.randf() * 30.0, h), Color(0.05, 0.18, 0.08, 0.35))
		3:  # factory: pipes
			for i in 8:
				var y := 120.0 + rng.randf() * (h - 300.0)
				draw_rect(Rect2(0, y, w, 16), Color(0, 0, 0, 0.22))
			for i in 10:
				draw_rect(Rect2(rng.randf() * w, 0, 18, h), Color(0, 0, 0, 0.15))
		4:  # bunker: lamps
			for i in 9:
				var x := 150.0 + i * 260.0
				draw_rect(Rect2(x, 130, 60, 8), Color(1, 0.9, 0.6, 0.8))
				draw_colored_polygon(PackedVector2Array([Vector2(x, 138), Vector2(x + 60, 138), Vector2(x + 140, 560), Vector2(x - 80, 560)]), Color(1, 0.9, 0.6, 0.05))
		5:  # space: stars + planet
			for i in 160:
				draw_circle(Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(1.0, 3.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
			draw_circle(Vector2(w * 0.3, 330), 150, Color(0.25, 0.4, 0.8, 0.8))
			draw_circle(Vector2(w * 0.3 - 40, 300), 100, Color(0.35, 0.55, 0.95, 0.5))
	if dec == 6:
		for i in 140:
			draw_circle(Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(2.0, 5.0), Color(1, 1, 1, 0.55))
	elif dec == 7:
		draw_circle(Vector2(w * 0.78, 190), 100, Color(1, 0.95, 0.6, 0.7))
		for i in 12:
			draw_rect(Rect2(i * 220.0, h - 160.0 + sin(i) * 20.0, 160.0, 6.0), Color(1, 1, 1, 0.35))
	for g in map.gas:
		draw_rect(g, Color(0.3, 0.9, 0.2, 0.28))
		draw_rect(g, Color(0.5, 1.0, 0.35, 0.7), false, 3.0)
	for s in map.solids:
		var r: Rect2 = s
		draw_rect(r, solid)
		var hx := r.position.x + 20.0
		while hx < r.end.x - 4.0 and r.size.y > 20.0:
			draw_line(Vector2(hx, r.position.y + 8.0), Vector2(hx, r.end.y - 3.0), Color(0, 0, 0, 0.13), 2.0)
			hx += 40.0
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - minf(6.0, r.size.y * 0.3)), Vector2(r.size.x, minf(6.0, r.size.y * 0.3))), Color(0, 0, 0, 0.28))
		draw_rect(Rect2(r.position, Vector2(r.size.x, minf(9.0, r.size.y))), edge)
		draw_rect(Rect2(r.position + Vector2(0, minf(9.0, r.size.y)), Vector2(r.size.x, minf(3.0, r.size.y))), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(0, 0, w, h), Color(edge, 0.55), false, 4.0)
