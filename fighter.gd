class_name Fighter
extends Node2D
## A player or bot. Holds state + draws itself. Simulation lives in game.gd (host only).

const SIZE := Vector2(22, 40)

var id := 0
var pname := ""
var team := 0
var color := Color.WHITE
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

func _process(dt: float) -> void:
	flash = maxf(0.0, flash - dt)
	hurt = maxf(0.0, hurt - dt)
	melee_t = maxf(0.0, melee_t - dt)
	position = pos
	if absf(cos(aim)) > 0.15:
		facing = 1 if cos(aim) >= 0.0 else -1
	queue_redraw()

func _draw() -> void:
	if not alive:
		return
	var font := ThemeDB.fallback_font
	var c := color
	if hurt > 0.0:
		c = c.lerp(Color.WHITE, 0.75)
	var fl := float(facing)
	var jx := -fl * 13.0
	draw_rect(Rect2(jx - 3.0, -6.0, 6.0, 18.0), Color(0.35, 0.37, 0.42))
	if jets:
		var fh := 10.0 + randf() * 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(jx - 4.0, 12.0), Vector2(jx + 4.0, 12.0), Vector2(jx, 12.0 + fh)]),
			Color(1.0, 0.55 + randf() * 0.35, 0.1))
	draw_rect(Rect2(-9, -6, 18, 22), c)
	draw_rect(Rect2(-8, 16, 6, 4), c.darkened(0.4))
	draw_rect(Rect2(2, 16, 6, 4), c.darkened(0.4))
	draw_circle(Vector2(0, -13), 8.0, Color(0.95, 0.8, 0.65))
	draw_rect(Rect2(fl * 3.0 - 2.0, -16.0, 5.0, 3.0), Color(0.1, 0.12, 0.18))
	var dir := Vector2.from_angle(aim)
	var wlen := 20.0
	var wcol := Color(0.15, 0.15, 0.18)
	var wid := 5.0
	if cur_weapon >= 0 and cur_weapon < Cfg.weapons.size():
		var w: Dictionary = Cfg.weapons[cur_weapon]
		if int(w.k) == Cfg.KIND_ROCKET:
			wlen = 30.0
			wid = 8.0
		elif int(w.k) == Cfg.KIND_BULLET and float(w.dmg) >= 60.0:
			wlen = 32.0
			wid = 4.0
		elif int(w.pellets) > 1:
			wlen = 24.0
			wid = 7.0
	var o := Vector2(0, 2)
	draw_line(o, o + dir * wlen, wcol, wid)
	if flash > 0.0:
		draw_circle(o + dir * (wlen + 6.0), 6.0, Color(1, 0.9, 0.4, 0.9))
	if prot > 0.0:
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 24, Color(0.5, 0.85, 1.0, 0.75), 2.0)
	if shield_t > 0.0:
		draw_circle(Vector2.ZERO, 28.0, Color(0.3, 0.8, 1.0, 0.22))
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(0.4, 0.9, 1.0, 0.9), 3.0)
	if dmg_t > 0.0:
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.2, 0.8), 2.0)
	if speed_t > 0.0:
		draw_line(Vector2(-fl * 16.0, 4.0), Vector2(-fl * 34.0, 4.0), Color(1, 1, 0.4, 0.8), 3.0)
		draw_line(Vector2(-fl * 16.0, 12.0), Vector2(-fl * 30.0, 12.0), Color(1, 1, 0.4, 0.6), 3.0)
	if melee_t > 0.0:
		var a0 := aim - 0.9
		draw_arc(Vector2(0, 2), 34.0, a0, a0 + 1.8, 10, Color(1, 1, 1, 0.9), 6.0)
	var hpf := clampf(hp / 100.0, 0.0, 1.0)
	draw_rect(Rect2(-16, -36, 32, 4), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-16, -36, 32.0 * hpf, 4), Color(1.0 - hpf, 0.3 + 0.6 * hpf, 0.2))
	draw_string(font, Vector2(-45, -42), pname, HORIZONTAL_ALIGNMENT_CENTER, 90, 13, Color(1, 1, 1, 0.9))
