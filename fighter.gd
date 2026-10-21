class_name Fighter
extends Node2D
## A player or bot: state + procedural animated drawing (original cartoon soldier).
## Simulation lives in game.gd (host only). Art is drawn in "art units" and scaled by K.

const SIZE := Vector2(40, 76)
const K := 1.9
const SKIN := [Color("f2cfa6"), Color("d9a679"), Color("a8744f")]
const HAIR := [Color("2b1d14"), Color("6b3e1f"), Color("c9a24a"), Color("222a3a")]
const OUT := Color(0.08, 0.09, 0.13)

var id := 0
var pname := ""
var team := 0
var color := Color.WHITE
var style := 0
var skin_i := 0
var bot_force := false
var show_overlay := true
var is_bot := false
var alive := false
var hp := 100.0
var vel := Vector2.ZERO
var pos := Vector2.ZERO
var tpos := Vector2.ZERO
var aim := 0.0
var facing := 1
var on_floor := false
var jets := false
var slots: Array = [1, 0]
var slot := 0
var ammo: Array = [0, 0]
var reserve: Array = [0, 0]
var reload_t := 0.0
var fire_cd := 0.0
var nades := 3
var nade_cd := 0.0
var fuel := 100.0
var air_jumps := 1
var respawn_t := 0.0
var prot := 0.0
var flash := 0.0
var hurt := 0.0
var kills := 0
var deaths := 0
var jump_req := false
var gtype := 0
var melee_cd := 0.0
var melee_t := 0.0
var shield_t := 0.0
var dmg_t := 0.0
var speed_t := 0.0
var cur_weapon := 1
var gas_acc := 0.0
var inp: Dictionary = {"mx": 0.0, "my": 0.0, "jet": false, "fire": false, "aim": 0.0}
# bot state
var bot_t := 0.0
var bot_target := 0
var bot_los := false
var bot_block := false
var bot_strafe := 1.0
var bot_dest := Vector2.ZERO
var bot_has := false
var bot_flee := Vector2.ZERO
var bot_flee_t := 0.0
# animation state
var phase := 0.0
var av := Vector2.ZERO
var land_t := 0.0
var death_t := 0.0
var spawn_t := 0.0
var _was_alive := false
var _was_floor := false
var _last := Vector2.ZERO

func _process(dt: float) -> void:
	flash = maxf(0.0, flash - dt)
	hurt = maxf(0.0, hurt - dt)
	melee_t = maxf(0.0, melee_t - dt)
	land_t = maxf(0.0, land_t - dt)
	spawn_t = maxf(0.0, spawn_t - dt)
	position = pos
	if absf(cos(aim)) > 0.15:
		facing = 1 if cos(aim) >= 0.0 else -1
	if dt > 0.0:
		av = av.lerp((pos - _last) / dt, 1.0 - exp(-14.0 * dt))
	_last = pos
	if alive != _was_alive:
		if alive:
			spawn_t = 0.45
			death_t = 0.0
		else:
			death_t = 0.9
		_was_alive = alive
	if alive:
		if on_floor and not _was_floor and av.y > 160.0:
			land_t = 0.14
		_was_floor = on_floor
		if on_floor:
			phase += absf(av.x) * dt * 0.05
		else:
			phase += dt * 6.0
	else:
		death_t = maxf(0.0, death_t - dt)
		_was_floor = false
	queue_redraw()

func _limb(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	draw_line(a, b, OUT, w + 2.0)
	draw_line(a, b, c, w)

func _draw() -> void:
	if alive:
		_draw_char(0.0, false)
		_draw_overlay()
	elif death_t > 0.0:
		var k := 1.0 - death_t / 0.9
		modulate.a = clampf(death_t / 0.9 + 0.1, 0.0, 1.0)
		_draw_char(k * 1.5 * float(facing), true)
	else:
		modulate.a = 1.0
	if alive:
		modulate.a = 1.0

func _draw_char(rot: float, dead: bool) -> void:
	var fl := float(facing)
	var t := Time.get_ticks_msec() / 1000.0
	var moving := on_floor and absf(av.x) > 40.0
	var sy := 1.0 - land_t * 0.9
	var pop := 1.0
	if spawn_t > 0.0:
		pop = 0.4 + 0.6 * (1.0 - spawn_t / 0.45)
	var sink := 0.0
	if dead:
		sink = (1.0 - death_t / 0.9) * 14.0
	draw_set_transform(Vector2(0, 20.0 * K * (1.0 - sy) + sink * K * 0.3), rot, Vector2(K * pop, K * sy * pop))
	var bob := 0.0
	if on_floor and not moving:
		bob = sin(t * 3.0) * 0.7
	elif moving:
		bob = absf(sin(phase)) * 1.4
	var pants := color.darkened(0.55)
	var boot := Color(0.2, 0.16, 0.14)
	# ---- legs
	var a1 := 0.0
	var a2 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	if on_floor:
		if moving:
			a1 = sin(phase) * 0.85
			a2 = sin(phase + PI) * 0.85
			b1 = -maxf(0.0, -cos(phase)) * 0.7
			b2 = -maxf(0.0, cos(phase)) * 0.7
		else:
			a1 = 0.1
			a2 = -0.1
	elif jets:
		a1 = 0.3 + sin(t * 9.0) * 0.05
		a2 = -0.08
		b1 = -0.35
		b2 = -0.2
	elif av.y < 0.0:
		a1 = 0.7
		a2 = 0.2
		b1 = -1.0
		b2 = -0.7
	else:
		a1 = 0.45
		a2 = -0.4
		b1 = -0.2
		b2 = 0.1
	var legs := [[-2.6, a2, b2, pants.darkened(0.15)], [2.6, a1, b1, pants]]
	for lg in legs:
		var hip := Vector2(float(lg[0]) * 0.8, 6.0 + bob * 0.4)
		var knee := hip + Vector2(sin(float(lg[1])) * 7.0 * fl, cos(float(lg[1])) * 7.0)
		var fa: float = float(lg[1]) + float(lg[2])
		var foot := knee + Vector2(sin(fa) * 7.0 * fl, cos(fa) * 7.0)
		_limb(hip, knee, 4.6, lg[3])
		_limb(knee, foot, 4.2, lg[3])
		draw_rect(Rect2(foot.x - 3.0 + (1.0 if fl > 0.0 else -2.0), foot.y - 2.0, 5.5, 4.0), OUT)
		draw_rect(Rect2(foot.x - 2.4 + (1.0 if fl > 0.0 else -2.0), foot.y - 1.4, 4.4, 2.8), boot)
	# ---- back arm (behind body)
	var s := Vector2(-fl * 0.5, -6.0 + bob)
	var dir := Vector2.from_angle(aim)
	var skin: Color = SKIN[skin_i % 3]
	var sleeve := color.darkened(0.15)
	var two_hand := cur_weapon != 0
	var hand_b := s + dir * 17.0 + Vector2(0, 1.5)
	if not two_hand:
		hand_b = s + Vector2(-fl * 3.0, 9.0)
	var elb_b := s.lerp(hand_b, 0.5) + Vector2(0, 2.5)
	_limb(s, elb_b, 4.0, sleeve.darkened(0.2))
	_limb(elb_b, hand_b, 3.6, skin.darkened(0.15))
	# ---- jetpack
	var jx := -fl * 9.5
	draw_rect(Rect2(jx - 4.4, -9.4 + bob, 8.8, 16.4), OUT)
	draw_rect(Rect2(jx - 3.6, -8.6 + bob, 7.2, 14.8), Color(0.42, 0.45, 0.52))
	draw_rect(Rect2(jx - 3.0, -8.0 + bob, 2.6, 13.0), Color(0.62, 0.66, 0.74))
	draw_rect(Rect2(jx + 0.6, -8.0 + bob, 2.6, 13.0), Color(0.34, 0.37, 0.44))
	draw_rect(Rect2(jx - 2.6, 6.0 + bob, 5.2, 2.8), Color(0.2, 0.2, 0.24))
	if jets and not dead:
		var tilt := clampf(-av.x * 0.012, -7.0, 7.0)
		var fh := 12.0 + randf() * 8.0
		var base := Vector2(jx, 8.8 + bob)
		draw_circle(base + Vector2(tilt * 0.5, 7.0), 9.0, Color(1.0, 0.6, 0.15, 0.22))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-3.4, 0), base + Vector2(3.4, 0), base + Vector2(tilt, fh)]), Color(1.0, 0.5 + randf() * 0.2, 0.1, 0.95))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-1.9, 0), base + Vector2(1.9, 0), base + Vector2(tilt * 0.8, fh * 0.62)]), Color(1.0, 0.92, 0.45))
	# ---- torso
	draw_rect(Rect2(-8.8, -10.0 + bob, 17.6, 18.6), OUT)
	draw_rect(Rect2(-7.8, -9.0 + bob, 15.6, 16.6), color)
	draw_rect(Rect2(-7.8, -9.0 + bob, 15.6, 5.0), color.lightened(0.18))
	draw_rect(Rect2(-7.8, 4.6 + bob, 15.6, 3.0), pants.darkened(0.1))
	draw_rect(Rect2(-1.5, 4.2 + bob, 3.0, 3.6), Color(0.85, 0.75, 0.3))
	draw_line(Vector2(-4.5, -9.0 + bob), Vector2(2.5, 4.0 + bob), color.darkened(0.35), 2.0)
	draw_line(Vector2(4.5, -9.0 + bob), Vector2(-2.5, 4.0 + bob), color.darkened(0.35), 2.0)
	draw_rect(Rect2(fl * 2.5 - 2.0, -2.0 + bob, 4.0, 3.2), color.darkened(0.25))
	# ---- head (big doodle-style head)
	var hc := Vector2(fl * 0.8, -19.0 + bob)
	draw_circle(hc, 11.6, OUT)
	draw_circle(hc, 10.3, skin)
	var hcol := color.darkened(0.2)
	var hair: Color = HAIR[style % 4]
	match style % 4:
		0:  # combat helmet + goggles
			draw_colored_polygon(_dome(hc, 11.6, -0.1), OUT)
			draw_colored_polygon(_dome(hc, 10.5, -0.1), hcol)
			draw_rect(Rect2(hc.x - 11.0, hc.y - 1.6, 22.0, 2.8), hcol.darkened(0.3))
			draw_rect(Rect2(hc.x + (0.5 if fl > 0.0 else -10.0), hc.y - 4.4, 9.5, 3.8), Color(0.1, 0.16, 0.28, 0.95))
			draw_rect(Rect2(hc.x + (2.0 if fl > 0.0 else -8.0), hc.y - 3.8, 3.0, 1.2), Color(0.6, 0.85, 1.0, 0.85))
		1:  # cap with peak
			draw_colored_polygon(_dome(hc, 11.6, 0.0), OUT)
			draw_colored_polygon(_dome(hc, 10.5, 0.0), color.lightened(0.05))
			draw_rect(Rect2(hc.x + (4.0 if fl > 0.0 else -15.0), hc.y - 3.6, 11.0, 3.6), OUT)
			draw_rect(Rect2(hc.x + (4.6 if fl > 0.0 else -14.4), hc.y - 3.0, 9.8, 2.4), color.darkened(0.3))
		2:  # spiky hair + bandana
			for k in 5:
				var ang := PI + 0.35 + k * 0.6
				var p1 := hc + Vector2.from_angle(ang) * 8.5
				var p2 := hc + Vector2.from_angle(ang) * 16.0
				draw_colored_polygon(PackedVector2Array([p1 + Vector2(-2.6, 0), p2, p1 + Vector2(2.6, 0)]), OUT)
				draw_colored_polygon(PackedVector2Array([p1 + Vector2(-1.8, 0), p2 + (p1 - p2).normalized() * 1.6, p1 + Vector2(1.8, 0)]), hair)
			draw_rect(Rect2(hc.x - 10.4, hc.y - 6.2, 20.8, 3.8), OUT)
			draw_rect(Rect2(hc.x - 9.8, hc.y - 5.6, 19.6, 2.6), color.lightened(0.25))
		3:  # headset + short hair
			draw_colored_polygon(_dome(hc, 11.4, 0.35), OUT)
			draw_colored_polygon(_dome(hc, 10.4, 0.35), hair)
			draw_circle(hc + Vector2(-fl * 8.0, 0.5), 3.6, OUT)
			draw_circle(hc + Vector2(-fl * 8.0, 0.5), 2.8, Color(0.28, 0.3, 0.36))
			draw_line(hc + Vector2(fl * 5.0, 5.0), hc + Vector2(fl * 9.0, 8.0), Color(0.2, 0.22, 0.28), 1.8)
	draw_circle(hc + Vector2(fl * 4.4, 0.8), 3.2, OUT)
	draw_circle(hc + Vector2(fl * 4.4, 0.8), 2.5, Color.WHITE)
	draw_circle(hc + Vector2(fl * 5.2, 0.9), 1.3, Color(0.08, 0.08, 0.12))
	draw_line(hc + Vector2(fl * 2.2, -2.6), hc + Vector2(fl * 6.4, -3.4), hair.darkened(0.3), 1.4)
	draw_line(hc + Vector2(fl * 2.5, 6.0), hc + Vector2(fl * 6.5, 5.4), Color(0.35, 0.15, 0.12), 1.4)
	# ---- weapon + front arm
	if not dead:
		var hand := s + dir * 9.0
		if melee_t > 0.0:
			hand = s + dir * (9.0 + 9.0 * sin(PI * (1.0 - melee_t / 0.2)))
		var elb := s.lerp(hand, 0.5) + Vector2(0, 2.0)
		draw_set_transform(Vector2(hand.x * K, hand.y * K), aim, Vector2(K, K * fl))
		var kick := 3.0 if flash > 0.0 else 0.0
		_draw_gun(cur_weapon, -kick)
		draw_set_transform(Vector2(0, 20.0 * K * (1.0 - sy)), 0.0, Vector2(K, K * sy))
		_limb(s, elb, 4.4, sleeve)
		_limb(elb, hand, 3.8, skin)
		draw_circle(hand, 2.7, OUT)
		draw_circle(hand, 2.0, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _dome(c: Vector2, r: float, lift: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + float(i) / 12.0 * PI
		pts.append(c + Vector2(cos(a), sin(a)) * r + Vector2(0, lift))
	return pts

func _draw_gun(wi: int, ox: float) -> void:
	var dk := Color(0.16, 0.17, 0.2)
	var md := Color(0.33, 0.35, 0.4)
	var wood := Color(0.5, 0.33, 0.18)
	var acc: Color = Cfg.weapons[clampi(wi, 0, Cfg.weapons.size() - 1)].color
	var tip := 17.0
	match wi:
		0:
			draw_rect(Rect2(ox - 1, -3.6, 13, 5.6), OUT)
			draw_rect(Rect2(ox, -3, 11, 4.4), md)
			draw_rect(Rect2(ox + 10, -2.2, 5, 3), dk)
			draw_rect(Rect2(ox + 1, 1.0, 4.2, 7.0), dk)
			tip = 16.0
		1:
			draw_rect(Rect2(ox - 13, -3.6, 40, 6.6), OUT)
			draw_rect(Rect2(ox - 12, -2.6, 8, 5), wood)
			draw_rect(Rect2(ox - 4, -3, 21, 5), md)
			draw_rect(Rect2(ox + 16, -2, 10, 3), dk)
			draw_rect(Rect2(ox + 2, 1.5, 4, 9), dk)
			draw_rect(Rect2(ox + 8, -5.4, 5, 2.4), dk)
			draw_rect(Rect2(ox + 4, -3, 8, 1.2), acc)
			tip = 27.0
		2:
			draw_rect(Rect2(ox - 4, -3.6, 24, 6.6), OUT)
			draw_rect(Rect2(ox - 3, -3, 14, 5), md)
			draw_rect(Rect2(ox + 10, -2.2, 8, 3), dk)
			draw_rect(Rect2(ox + 2, 1.5, 3.4, 11), dk)
			draw_rect(Rect2(ox - 2, 1.5, 3.8, 6), dk)
			tip = 19.0
		3:
			draw_rect(Rect2(ox - 15, -3.6, 45, 6.4), OUT)
			draw_rect(Rect2(ox - 14, -2.6, 9, 4.6), wood)
			draw_rect(Rect2(ox - 5, -3, 26, 4), md)
			draw_rect(Rect2(ox + 8, 1.0, 10, 3.6), wood)
			draw_rect(Rect2(ox + 20, -3, 9, 3.4), dk)
			tip = 29.0
		4:
			draw_rect(Rect2(ox - 17, -3.6, 54, 6.4), OUT)
			draw_rect(Rect2(ox - 16, -2.6, 9, 5), wood)
			draw_rect(Rect2(ox - 7, -2.6, 30, 3.8), md)
			draw_rect(Rect2(ox + 22, -1.8, 13, 2.2), dk)
			draw_rect(Rect2(ox + 4, -9.0, 12, 4.6), dk)
			draw_rect(Rect2(ox + 14.4, -8.2, 2.0, 3.0), Color(0.5, 0.9, 1.0))
			tip = 36.0
		5:
			draw_rect(Rect2(ox - 13, -4.0, 43, 7.4), OUT)
			draw_rect(Rect2(ox - 12, -3.0, 8, 5.4), wood)
			draw_rect(Rect2(ox - 4, -3.4, 22, 6), md)
			draw_rect(Rect2(ox + 17, -2.2, 11, 3), dk)
			draw_rect(Rect2(ox + 2, 2.5, 10, 7.5), Color(0.25, 0.3, 0.22))
			draw_rect(Rect2(ox + 20, 1.0, 7, 5), dk)
			tip = 29.0
		6:
			draw_rect(Rect2(ox - 12, -6.2, 40, 11.4), OUT)
			draw_rect(Rect2(ox - 11, -5.2, 34, 9.2), Color(0.35, 0.42, 0.28))
			draw_rect(Rect2(ox + 22, -5.2, 6, 9.2), Color(0.85, 0.3, 0.2))
			draw_rect(Rect2(ox - 4, 4.0, 4, 6), dk)
			draw_rect(Rect2(ox + 4, -8.0, 4, 2.6), dk)
			tip = 31.0
		7:
			draw_rect(Rect2(ox - 5, -3.6, 33, 8.0), OUT)
			draw_rect(Rect2(ox - 4, -3, 18, 5.4), md)
			draw_circle(Vector2(ox + 8, 3.0), 6.4, OUT)
			draw_circle(Vector2(ox + 8, 3.0), 5.4, Color(0.28, 0.4, 0.22))
			draw_circle(Vector2(ox + 8, 3.0), 2.0, dk)
			draw_rect(Rect2(ox + 14, -3.6, 13, 6), dk)
			tip = 27.0
		_:
			draw_rect(Rect2(ox - 17, -6.0, 13, 11.5), OUT)
			draw_rect(Rect2(ox - 16, -5.0, 11, 9.5), Color(0.8, 0.25, 0.2))
			draw_rect(Rect2(ox - 4, -2.6, 20, 3.8), md)
			draw_rect(Rect2(ox + 15, -3.6, 6, 5.6), dk)
			draw_circle(Vector2(ox + 22, -0.7), 2.0, Color(1, 0.7, 0.2))
			tip = 22.0
	if flash > 0.0:
		var p := Vector2(ox + tip + 2.0, 0)
		var r := 5.0 + randf() * 3.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), p + Vector2(r * 0.5, -r), p + Vector2(r * 1.8, 0), p + Vector2(r * 0.5, r)]), Color(1, 0.85, 0.3, 0.95))
		draw_circle(p + Vector2(r * 0.4, 0), r * 0.4, Color(1, 1, 0.9))

func _draw_overlay() -> void:
	var font := ThemeDB.fallback_font
	if prot > 0.0:
		draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 28, Color(0.5, 0.85, 1.0, 0.75), 3.0)
	if shield_t > 0.0:
		draw_circle(Vector2.ZERO, 55.0, Color(0.3, 0.8, 1.0, 0.2))
		draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 28, Color(0.4, 0.9, 1.0, 0.9), 4.0)
	if dmg_t > 0.0:
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 28, Color(1.0, 0.3, 0.2, 0.8), 3.0)
	if speed_t > 0.0:
		var fl := float(facing)
		draw_line(Vector2(-fl * 24.0, 4.0), Vector2(-fl * 60.0, 4.0), Color(1, 1, 0.4, 0.8), 4.0)
		draw_line(Vector2(-fl * 24.0, 20.0), Vector2(-fl * 52.0, 20.0), Color(1, 1, 0.4, 0.6), 4.0)
	if melee_t > 0.0:
		var a0 := aim - 0.9
		draw_arc(Vector2(0, -6), 68.0, a0, a0 + 1.8, 12, Color(1, 1, 1, 0.9), 7.0)
	if not show_overlay:
		return
	var hpf := clampf(hp / 100.0, 0.0, 1.0)
	draw_rect(Rect2(-26, -66, 52, 7), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-25, -65, 50.0 * hpf, 5), Color(1.0 - hpf, 0.3 + 0.6 * hpf, 0.2))
	draw_string(font, Vector2(-60, -72), pname, HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color(1, 1, 1, 0.92))
