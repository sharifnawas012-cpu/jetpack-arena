extends Control
## Multi-touch controls: floating move stick (left), floating aim stick (right, auto-fires when pushed),
## FIRE / JET / JUMP / GRENADE / SWITCH buttons, pause button.

var game
var touches: Dictionary = {}     # touch index -> role
var l_c := Vector2.ZERO
var l_v := Vector2.ZERO
var r_c := Vector2.ZERO
var r_v := Vector2.ZERO
var r_on := false
var l_on := false
var held := {"fire": false, "jet": false}
var last_aim := 0.0
var btns: Dictionary = {}
var sc := 1.0
const STICK_R := 90.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout() -> void:
	sc = clampf(float(Cfg.prefs.ui_scale), 0.6, 1.6)
	var w := size.x
	var h := size.y
	btns = {
		"fire": [Vector2(w - 105.0 * sc, h - 110.0 * sc), 62.0 * sc, "FIRE"],
		"jet": [Vector2(w - 250.0 * sc, h - 80.0 * sc), 48.0 * sc, "JET"],
		"jump": [Vector2(w - 235.0 * sc, h - 190.0 * sc), 42.0 * sc, "JUMP"],
		"nade": [Vector2(w - 95.0 * sc, h - 245.0 * sc), 42.0 * sc, "NADE"],
		"sw": [Vector2(w - 345.0 * sc, h - 95.0 * sc), 38.0 * sc, "SWAP"],
		"pause": [Vector2(w - 50.0, 50.0), 26.0, "II"],
	}

func _input(e: InputEvent) -> void:
	if not visible or game == null:
		return
	if game.ended or (game.pause_ui != null and game.pause_ui.visible and e is InputEventScreenTouch and not (btns.has("pause") and e.position.distance_to(btns["pause"][0]) < 40.0)):
		return
	if btns.is_empty() or btns["pause"][0].x != size.x - 50.0:
		_layout()
	if e is InputEventScreenTouch:
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index)
	elif e is InputEventScreenDrag:
		_drag(e.index, e.position)

func _down(i: int, p: Vector2) -> void:
	for k in btns:
		var b: Array = btns[k]
		if p.distance_to(b[0]) <= float(b[1]) * 1.2:
			touches[i] = k
			match k:
				"fire", "jet": held[k] = true
				"jump": game.queue_act(0)
				"nade": game.queue_act(1)
				"sw": game.queue_act(2)
				"pause": game.toggle_pause()
			return
	if p.x < size.x * 0.45 and not l_on:
		touches[i] = "L"
		l_on = true
		l_c = p
		l_v = Vector2.ZERO
	elif p.x > size.x * 0.5 and not r_on:
		touches[i] = "R"
		r_on = true
		r_c = p
		r_v = Vector2.ZERO

func _drag(i: int, p: Vector2) -> void:
	var role = touches.get(i, "")
	if role == "L":
		l_v = ((p - l_c) / (STICK_R * sc)).limit_length(1.0)
	elif role == "R":
		var v := p - r_c
		r_v = (v / (STICK_R * sc)).limit_length(1.0)
		if v.length() > 10.0:
			last_aim = v.angle()

func _up(i: int) -> void:
	var role = touches.get(i, "")
	touches.erase(i)
	if role == "L":
		l_on = false
		l_v = Vector2.ZERO
	elif role == "R":
		r_on = false
		r_v = Vector2.ZERO
	elif held.has(role):
		held[role] = false

func get_state() -> Dictionary:
	var mx := l_v.x
	if absf(mx) < 0.18:
		mx = 0.0
	return {"mx": mx, "my": l_v.y, "jet": bool(held.jet) or l_v.y < -0.55,
		"fire": bool(held.fire) or (r_on and r_v.length() > 0.8), "aim": last_aim}

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if btns.is_empty():
		_layout()
	var op := float(Cfg.prefs.touch_opacity)
	var font := ThemeDB.fallback_font
	var base_l := l_c if l_on else Vector2(150.0 * sc, size.y - 150.0 * sc)
	var base_r := r_c if r_on else Vector2(size.x * 0.62, size.y - 150.0 * sc)
	draw_circle(base_l, STICK_R * sc, Color(1, 1, 1, 0.08 * op * 2.0))
	draw_arc(base_l, STICK_R * sc, 0.0, TAU, 32, Color(1, 1, 1, op * 0.6), 3.0)
	draw_circle(base_l + (l_v * STICK_R * sc if l_on else Vector2.ZERO), 34.0 * sc, Color(1, 1, 1, op))
	draw_circle(base_r, STICK_R * sc, Color(1, 0.6, 0.5, 0.08 * op * 2.0))
	draw_arc(base_r, STICK_R * sc, 0.0, TAU, 32, Color(1, 0.7, 0.6, op * 0.6), 3.0)
	draw_circle(base_r + (r_v * STICK_R * sc if r_on else Vector2.ZERO), 34.0 * sc, Color(1, 0.7, 0.6, op))
	draw_string(font, base_l + Vector2(-60, STICK_R * sc + 26), "MOVE / FLY UP", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, op * 0.8))
	draw_string(font, base_r + Vector2(-60, STICK_R * sc + 26), "AIM (push to shoot)", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, op * 0.8))
	for k in btns:
		var b: Array = btns[k]
		var down: bool = held.get(k, false)
		var col := Color(0.9, 0.3, 0.3) if k == "fire" else (Color(1.0, 0.6, 0.2) if k == "jet" else Color(0.5, 0.7, 1.0))
		draw_circle(b[0], b[1], Color(col, op * (0.8 if down else 0.45)))
		draw_arc(b[0], b[1], 0.0, TAU, 28, Color(1, 1, 1, op), 3.0)
		draw_string(font, b[0] + Vector2(-b[1], 6), String(b[2]), HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2.0, int(16.0 * sc) if k != "pause" else 16, Color(1, 1, 1, minf(1.0, op + 0.3)))
