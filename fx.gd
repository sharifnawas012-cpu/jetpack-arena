extends Node2D
## Dynamic visuals: bullets, crates, particles, explosions. Capped particle count for mobile.

const MAX_PARTS := 260
var game
var parts: Array = []   # [pos, vel, life, maxlife, color, size]
var rings: Array = []   # [pos, radius, t]
var clouds: Array = []  # [pos, kind, t, dur]

func cloud(p: Vector2, kind: int, dur: float) -> void:
	if clouds.size() >= 8:
		clouds.pop_front()
	clouds.append([p, kind, 0.0, dur])

func spark(p: Vector2, col: Color, n: int) -> void:
	for i in n:
		if parts.size() >= MAX_PARTS:
			parts.pop_front()
		var a := randf() * TAU
		var v := Vector2.from_angle(a) * randf_range(40.0, 260.0)
		parts.append([p, v, 0.0, randf_range(0.2, 0.5), col, randf_range(2.0, 4.5)])

func boom(p: Vector2, r: float) -> void:
	rings.append([p, r, 0.0])
	spark(p, Color(1, 0.6, 0.15), 18)
	spark(p, Color(0.4, 0.4, 0.4), 8)

func _process(dt: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var pt: Array = parts[i]
		pt[2] += dt
		if pt[2] >= pt[3]:
			parts.remove_at(i)
		else:
			pt[0] += pt[1] * dt
			pt[1] = pt[1] * (1.0 - 2.5 * dt)
		i -= 1
	i = clouds.size() - 1
	while i >= 0:
		clouds[i][2] += dt
		if clouds[i][2] >= clouds[i][3]:
			clouds.remove_at(i)
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		rings[i][2] += dt
		if rings[i][2] > 0.35:
			rings.remove_at(i)
		i -= 1
	queue_redraw()

func _draw_bullet(p: Vector2, ang: float, spd: float, kind: int) -> void:
	var dir := Vector2.from_angle(ang)
	match kind:
		Cfg.KIND_BULLET:
			var l := clampf(spd * 0.03, 8.0, 46.0)
			draw_line(p - dir * l, p, Color(1, 0.95, 0.6, 0.9), 3.0)
		Cfg.KIND_ROCKET:
			draw_line(p - dir * 22.0, p, Color(1, 0.55, 0.15), 6.0)
			draw_circle(p, 5.0, Color(1, 0.9, 0.6))
		Cfg.KIND_GRENADE:
			draw_circle(p, 6.0, Color(0.2, 0.35, 0.15))
			draw_circle(p + Vector2(-1.5, -1.5), 2.0, Color(0.6, 0.8, 0.5))
		Cfg.KIND_FLAME:
			draw_circle(p, 8.0, Color(1, 0.45, 0.1, 0.5))
			draw_circle(p, 4.0, Color(1, 0.9, 0.4, 0.8))

func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	for i in game.crates.size():
		var c: Dictionary = game.crates[i]
		var wi: int = c.w
		if wi < 0:
			continue
		var p: Vector2 = c.pos
		var col: Color = Cfg.weapons[wi].color
		draw_rect(Rect2(p - Vector2(14, 14), Vector2(28, 28)), Color(0.15, 0.17, 0.2))
		draw_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)), col.darkened(0.15))
		draw_string(font, p + Vector2(-20, -18), String(Cfg.weapons[wi].name).left(9), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color(1, 1, 1, 0.9))
	if game.is_host:
		for b in game.pool:
			if b.active:
				_draw_bullet(b.pos, b.vel.angle(), b.vel.length(), b.kind)
	else:
		var bs: PackedFloat32Array = game.view_bullets
		var age: float = game.view_age
		var k := 0
		while k + 4 < bs.size():
			var ang := bs[k + 2]
			var spd := bs[k + 3]
			var p := Vector2(bs[k], bs[k + 1]) + Vector2.from_angle(ang) * spd * minf(age, 0.12)
			_draw_bullet(p, ang, spd, int(bs[k + 4]))
			k += 5
	for it in game.items:
		var ty: int = it.ty
		if ty < 0:
			continue
		var ip: Vector2 = it.pos
		var cols := [Color(0.95, 0.3, 0.4), Color(1, 0.9, 0.2), Color(0.3, 0.8, 1), Color(1, 0.45, 0.2)]
		var lab := ["+", "S", "O", "X2"]
		var bob := sin(Time.get_ticks_msec() * 0.005 + ip.x) * 3.0
		draw_circle(ip + Vector2(0, bob), 15.0, cols[ty])
		draw_arc(ip + Vector2(0, bob), 15.0, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 2.0)
		draw_string(font, ip + Vector2(-15, 7 + bob), lab[ty], HORIZONTAL_ALIGNMENT_CENTER, 30, 18, Color(1, 1, 1))
	for c in clouds:
		var t: float = c[2] / c[3]
		var base: Color = Color(0.75, 0.75, 0.78) if int(c[1]) == 2 else Color(0.4, 0.9, 0.25)
		var fade := 1.0 - maxf(0.0, (t - 0.7) / 0.3)
		for k in 7:
			var off := Vector2.from_angle(k * 0.9 + t * 0.4) * (30.0 + 12.0 * sin(t * 6.0 + k))
			draw_circle(c[0] + off, 62.0, Color(base, 0.30 * fade))
		draw_circle(c[0], 70.0, Color(base, 0.35 * fade))
	for r in rings:
		var t: float = r[2] / 0.35
		var rad: float = r[1] * (0.3 + 0.7 * t)
		draw_circle(r[0], rad, Color(1, 0.6, 0.2, 0.35 * (1.0 - t)))
		draw_arc(r[0], rad, 0.0, TAU, 32, Color(1, 0.9, 0.5, 0.8 * (1.0 - t)), 3.0)
	for pt in parts:
		var a: float = 1.0 - pt[2] / pt[3]
		var col: Color = pt[4]
		draw_circle(pt[0], pt[5], Color(col.r, col.g, col.b, a))
