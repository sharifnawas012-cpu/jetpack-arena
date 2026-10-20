extends Control
## Twin-stick touch controls (Mini-Militia style layout, original look).
## LEFT stick (fixed, bottom-left): run, push UP to fly, push DOWN to dive.
## RIGHT stick (fixed, bottom-right): aim 360 degrees; pushing it fires automatically.
## Buttons: JET (hold), JUMP, NADE, SWAP, pause.

var game
var touches: Dictionary = {}
var l_v := Vector2.ZERO
var r_v := Vector2.ZERO
var l_on := false
var r_on := false
var held := {"jet": false}
var last_aim := 0.0
var btns: Dictionary = {}
var sc := 1.0
var l_c := Vector2.ZERO
var r_c := Vector2.ZERO
var stick_r := 110.0
var lay_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout() -> void:
	sc = clampf(float(Cfg.prefs.ui_scale), 0.6, 1.6)
	var vs := get_viewport_rect().size
	var w := vs.x
	var h := vs.y
	lay_size = vs
	stick_r = 110.0 * sc
	l_c = Vector2(190.0 * sc, h - 190.0 * sc)
	r_c = Vector2(w - 200.0 * sc, h - 190.0 * sc)
	btns = {
		"jet": [Vector2(w - 90.0 * sc, h - 405.0 * sc), 52.0 * sc, "JET"],
		"nade": [Vector2(w - 235.0 * sc, h - 405.0 * sc), 46.0 * sc, "NADE"],
		"melee": [Vector2(w - 380.0 * sc, h - 405.0 * sc), 44.0 * sc, "MELEE"],
		"sw": [Vector2(w - 410.0 * sc, h - 290.0 * sc), 40.0 * sc, "SWAP"],
		"jump": [Vector2(410.0 * sc, h - 110.0 * sc), 46.0 * sc, "JUMP"],
		"zoom": [Vector2(540.0 * sc, h - 110.0 * sc), 38.0 * sc, "ZOOM"],
		"gt": [Vector2(410.0 * sc, h - 235.0 * sc), 40.0 * sc, "GREN"],
		"pause": [Vector2(w - 50.0, 50.0), 26.0, "II"],
	}

func _input(e: InputEvent) -> void:
	if not visible or game == null:
		return
	if lay_size != get_viewport_rect().size or btns.is_empty():
		_layout()
	if game.ended:
		return
	if game.pause_ui != null and game.pause_ui.visible:
		return
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
		if p.distance_to(b[0]) <= float(b[1]) * 1.25:
			touches[i] = k
			match k:
				"jet": held["jet"] = true
				"jump": game.queue_act(0)
				"nade": game.queue_act(1)
				"sw": game.queue_act(2)
				"melee": game.queue_act(3)
				"gt": game.queue_act(4)
				"zoom": game.toggle_zoom()
				"pause": game.toggle_pause()
			return
	if p.x < lay_size.x * 0.42 and not l_on:
		touches[i] = "L"
		l_on = true
		_drag(i, p)
	elif p.x > lay_size.x * 0.58 and not r_on:
		touches[i] = "R"
		r_on = true
		_drag(i, p)

func _drag(i: int, p: Vector2) -> void:
	var role = touches.get(i, "")
	if role == "L":
		l_v = ((p - l_c) / stick_r).limit_length(1.0)
	elif role == "R":
		var v := p - r_c
		r_v = (v / stick_r).limit_length(1.0)
		if v.length() > 8.0:
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
	elif role == "jet":
		held["jet"] = false

func get_state() -> Dictionary:
	var mx := l_v.x
	if absf(mx) < 0.15:
		mx = 0.0
	return {"mx": mx, "my": l_v.y, "jet": bool(held.jet) or l_v.y < -0.5,
		"fire": r_on and r_v.length() > 0.3, "aim": last_aim}

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()

func _draw_stick(c: Vector2, v: Vector2, col: Color, op: float) -> void:
	draw_circle(c, stick_r, Color(col, 0.16 * op + 0.06))
	draw_arc(c, stick_r, 0.0, TAU, 40, Color(1, 1, 1, op), 4.0)
	draw_arc(c, stick_r * 0.5, 0.0, TAU, 28, Color(1, 1, 1, op * 0.4), 2.0)
	for a in 4:
		var d := Vector2.from_angle(a * PI * 0.5)
		var tip := c + d * (stick_r - 14.0)
		draw_colored_polygon(PackedVector2Array([tip + d * 10.0, tip + d.rotated(2.4) * 12.0, tip + d.rotated(-2.4) * 12.0]), Color(1, 1, 1, op * 0.7))
	draw_circle(c + v * stick_r, 40.0 * sc, Color(col, minf(1.0, op + 0.25)))
	draw_arc(c + v * stick_r, 40.0 * sc, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 3.0)

func _draw() -> void:
	if lay_size != get_viewport_rect().size or btns.is_empty():
		_layout()
	var op := float(Cfg.prefs.touch_opacity)
	var font := ThemeDB.fallback_font
	_draw_stick(l_c, l_v, Color(0.4, 0.7, 1.0), op)
	_draw_stick(r_c, r_v, Color(1.0, 0.45, 0.35), op)
	draw_string(font, l_c + Vector2(-stick_r, stick_r + 26), "MOVE  (push up = fly)", HORIZONTAL_ALIGNMENT_CENTER, stick_r * 2.0, 15, Color(1, 1, 1, 0.85))
	draw_string(font, r_c + Vector2(-stick_r, stick_r + 26), "AIM + SHOOT", HORIZONTAL_ALIGNMENT_CENTER, stick_r * 2.0, 15, Color(1, 1, 1, 0.85))
	for k in btns:
		var b: Array = btns[k]
		var down: bool = held.get(k, false)
		var col := Color(1.0, 0.6, 0.2) if k == "jet" else Color(0.5, 0.7, 1.0)
		draw_circle(b[0], b[1], Color(col, op * (0.9 if down else 0.5)))
		draw_arc(b[0], b[1], 0.0, TAU, 28, Color(1, 1, 1, op), 3.0)
		var lab := String(b[2])
		if k == "gt":
			var me = game.fighters.get(game.local_id)
			if me != null:
				lab = ["FRAG", "STICKY", "SMOKE", "GAS"][me.gtype]
		draw_string(font, b[0] + Vector2(-b[1], 6), lab, HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2.0, int(15.0 * sc) if k != "pause" else 16, Color(1, 1, 1, 1))
