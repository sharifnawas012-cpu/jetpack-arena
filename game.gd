extends Node2D
## Match scene. The HOST (or the local machine in solo) simulates everything.
## Clients send input, receive snapshots, interpolate remote fighters and predict their own movement.

const WorldScript := preload("res://scripts/world.gd")
const FxScript := preload("res://scripts/fx.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch.gd")
const TapHelper := preload("res://scripts/tap_helper.gd")

const GRAV := 1500.0
const RUN := 270.0
const JUMP := 520.0
const HALF := Vector2(20, 38)
const SIZE := Vector2(40, 76)
const SNAP_DT := 1.0 / 30.0
const IN_DT := 1.0 / 30.0
const STATE_DT := 0.5
const POOL_SIZE := 220

class Bullet:
	var active := false
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var dmg := 0.0
	var owner_id := 0
	var team := 0
	var kind := 0
	var radius := 0.0
	var grav := 0.0
	var wi := 0
	var gt := 0
	var stuck := false

var S: Dictionary
var map: Dictionary
var solids: Array = []
var gas_zones: Array = []
var fighters: Dictionary = {}
var order: Array = []
var pool: Array = []
var crates: Array = []
var is_host := true
var local_id := 1
var time_left := 300.0
var ended := false
var team_mode := false
var team_scores: Array = []
var snap_acc := 0.0
var in_acc := 0.0
var sync_acc := 0.0
var view_bullets := PackedFloat32Array()
var view_age := 0.0
var rin: Dictionary = {}
var acts: Dictionary = {}
var feed: Array = []
var elapsed := 0.0
var gravity_mul := 1.0
var show_board := false
var fx: Node2D
var cam: Camera2D
var hud: Control
var touch: Control
var pause_ui: CanvasLayer
var result_ui: CanvasLayer
var fighter_root: Node2D
var notice: Label
var items: Array = []
var jet_acc := 0.0
var clouds: Array = []
var zoom_on := false
var zoom_k := 1.0

func _ready() -> void:
	Net.game = self
	S = Net.match_settings
	team_mode = String(S.mode) != "ffa"
	map = Cfg.maps[clampi(int(S.map), 0, Cfg.maps.size() - 1)]
	solids = map.solids
	gas_zones = map.gas
	gravity_mul = float(map.grav)
	is_host = (not Net.online) or Net.is_host
	local_id = multiplayer.get_unique_id() if Net.online else 1
	time_left = float(S.duration)
	for i in 12:
		team_scores.append(0)
	var world = WorldScript.new()
	world.map = map
	world.z_index = -10
	add_child(world)
	fighter_root = Node2D.new()
	add_child(fighter_root)
	fx = FxScript.new()
	fx.game = self
	add_child(fx)
	for i in map.crates.size():
		crates.append({"pos": map.crates[i], "w": -1, "t": 1.0 + i * 0.3})
	for i in map.spawns.size():
		if i % 3 == 1:
			items.append({"pos": map.spawns[i] + Vector2(0, 8), "ty": -1, "t": 0.5 + items.size() * 0.4})
	var idx := 0
	for r in Net.roster:
		var f := Fighter.new()
		f.id = int(r.id)
		f.pname = String(r.name)
		f.team = int(r.team)
		f.is_bot = bool(r.bot)
		f.color = Cfg.TEAM_COLORS[f.team % 4] if team_mode else Cfg.FFA_COLORS[idx % 12]
		f.style = idx % 4
		fighter_root.add_child(f)
		fighters[f.id] = f
		order.append(f.id)
		acts[f.id] = []
		idx += 1
		if is_host:
			_spawn(f)
	if is_host:
		for i in POOL_SIZE:
			pool.append(Bullet.new())
		Net.player_left.connect(on_player_left)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map.w)
	cam.limit_bottom = int(map.h)
	add_child(cam)
	cam.make_current()
	var f0: Fighter = fighters.get(local_id)
	if f0 != null:
		cam.global_position = f0.pos
	_build_ui()

func _exit_tree() -> void:
	if Net.game == self:
		Net.game = null
	if Net.player_left.is_connected(on_player_left):
		Net.player_left.disconnect(on_player_left)
	get_tree().paused = false

func _ui_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 28
	return th

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	touch = TouchScript.new()
	touch.game = self
	layer.add_child(touch)
	var pref := int(Cfg.prefs.touch)
	touch.visible = pref == 1 or (pref == 0 and DisplayServer.is_touchscreen_available())
	pause_ui = CanvasLayer.new()
	pause_ui.layer = 20
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_ui.visible = false
	add_child(pause_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.theme = _ui_theme()
	pause_ui.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	cc.add_child(box)
	var t := Label.new()
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b1 := Button.new()
	b1.text = "Resume"
	b1.custom_minimum_size = Vector2(360, 70)
	b1.pressed.connect(toggle_pause)
	box.add_child(b1)
	var b2 := Button.new()
	b2.text = "Leave Match"
	b2.custom_minimum_size = Vector2(360, 70)
	b2.pressed.connect(func() -> void: Net.quit_to_menu())
	box.add_child(b2)
	var hint := Label.new()
	hint.text = "Online matches keep running while paused."
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)
	notice = Label.new()
	notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notice.position = Vector2(0, 90)
	notice.add_theme_font_size_override("font_size", 30)
	notice.visible = false
	layer.add_child(notice)
	var ph := TapHelper.new()
	ph.root = pause_ui
	pause_ui.add_child(ph)
	Net.host_lost.connect(_on_host_lost)

func _on_host_lost(reason: String) -> void:
	# Net.leave() already ran; the lobby no longer exists, so return to the main menu with a message.
	notice.text = reason + " Returning to menu..."
	notice.visible = true
	get_tree().create_timer(2.0).timeout.connect(func() -> void: Net.quit_to_menu(reason))

func toggle_zoom() -> void:
	zoom_on = not zoom_on

func toggle_pause() -> void:
	pause_ui.visible = not pause_ui.visible
	if not Net.online:
		get_tree().paused = pause_ui.visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and pause_ui != null:
		toggle_pause()

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
	if touch != null and touch.visible:
		return
	if e is InputEventKey and not e.echo:
		if e.keycode == KEY_TAB:
			show_board = e.pressed
		elif e.pressed:
			match e.keycode:
				KEY_SPACE: queue_act(0)
				KEY_G: queue_act(1)
				KEY_F: queue_act(3)
				KEY_C: queue_act(4)
				KEY_Z: toggle_zoom()
				KEY_Q, KEY_E: queue_act(2)
				KEY_ESCAPE: toggle_pause()
	elif e is InputEventMouseButton and e.pressed:
		match e.button_index:
			MOUSE_BUTTON_RIGHT: queue_act(1)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN: queue_act(2)

func queue_act(kind: int) -> void:
	var f: Fighter = fighters.get(local_id)
	if f == null or ended or not f.alive:
		return
	if kind == 0:
		f.jump_req = true
	if is_host:
		if kind != 0:
			acts[local_id].append(kind)
	else:
		Net.rpc_id(1, "srv_act", kind)

func _local_input(f: Fighter) -> Dictionary:
	if touch != null and touch.visible:
		return touch.get_state()
	var mx := 0.0
	var my := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mx += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): my -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): my += 1.0
	var jet := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var aim := (get_global_mouse_position() - f.pos).angle()
	return {"mx": mx, "my": my, "jet": jet, "fire": fire, "aim": aim}

func on_input(id: int, mx: float, my: float, jet: bool, fire: bool, aim: float) -> void:
	rin[id] = {"mx": clampf(mx, -1.0, 1.0), "my": clampf(my, -1.0, 1.0), "jet": jet, "fire": fire, "aim": aim}

func on_act(id: int, kind: int) -> void:
	var f: Fighter = fighters.get(id)
	if f == null or not f.alive:
		return
	if kind == 0:
		f.jump_req = true
	elif acts.has(id) and acts[id].size() < 8:
		acts[id].append(kind)

func on_player_left(id: int) -> void:
	if fighters.has(id):
		remove_fighter(id)
		if Net.online:
			Net.rpc("cli_left", id)

func remove_fighter(id: int) -> void:
	var f: Fighter = fighters.get(id)
	if f != null:
		f.queue_free()
	fighters.erase(id)
	order.erase(id)
	acts.erase(id)
	rin.erase(id)

# ------------------------------------------------------------------ main loop
func _physics_process(dt: float) -> void:
	if ended:
		return
	if is_host:
		_host_step(dt)
		if Net.online:
			snap_acc += dt
			if snap_acc >= SNAP_DT:
				snap_acc = 0.0
				_send_snapshot()
			sync_acc += dt
			if sync_acc >= STATE_DT:
				sync_acc = 0.0
				_send_state()
	else:
		_client_step(dt)

func _process(dt: float) -> void:
	for f: Fighter in fighters.values():
		if is_host:
			f.cur_weapon = int(f.slots[f.slot])
		elif not (f.id == local_id and f.alive):
			f.pos = f.pos.lerp(f.tpos, 1.0 - exp(-20.0 * dt))
	if not is_host and not ended:
		view_age += dt
		time_left = maxf(0.0, time_left - dt)
	jet_acc += dt
	if jet_acc > 0.04:
		jet_acc = 0.0
		for f: Fighter in fighters.values():
			if f.alive and f.jets:
				fx.puff(f.pos + Vector2(-f.facing * 18.0, 40.0), Vector2(randf_range(-40.0, 40.0), randf_range(120.0, 210.0)))
	var i := feed.size() - 1
	while i >= 0:
		feed[i][2] -= dt
		if feed[i][2] <= 0.0:
			feed.remove_at(i)
		i -= 1
	var me: Fighter = fighters.get(local_id)
	if me != null and cam != null:
		zoom_k = lerpf(zoom_k, 0.62 if zoom_on else 1.0, 1.0 - exp(-8.0 * dt))
		var vw := float(Cfg.prefs.zoom_w) * zoom_k
		var z := get_viewport_rect().size.x / vw
		cam.zoom = Vector2(z, z)
		cam.global_position = cam.global_position.lerp(me.pos, 1.0 - exp(-9.0 * dt))

func _host_step(dt: float) -> void:
	elapsed += dt
	time_left -= dt
	if time_left <= 0.0:
		_finish()
		return
	for id in order:
		var f: Fighter = fighters[id]
		if f.is_bot:
			_bot_think(f, dt)
		elif id == local_id:
			var inp := _local_input(f)
			f.inp = inp
		else:
			f.inp = rin.get(id, {"mx": 0.0, "my": 0.0, "jet": false, "fire": false, "aim": f.aim})
		_sim_fighter(f, dt)
	_sim_bullets(dt)
	_sim_crates(dt)
	_sim_items(dt)
	_sim_clouds(dt)

func _client_step(dt: float) -> void:
	var f: Fighter = fighters.get(local_id)
	if f == null:
		return
	var inp := _local_input(f)
	f.inp = inp
	f.aim = float(inp.aim)
	if f.alive:
		_move(f, dt)
	in_acc += dt
	if in_acc >= IN_DT:
		in_acc = 0.0
		Net.rpc_id(1, "srv_input", float(inp.mx), float(inp.my), bool(inp.jet), bool(inp.fire), float(inp.aim))

# ------------------------------------------------------------------ fighter simulation
func _fill_loadout(f: Fighter) -> void:
	f.slots = [1, 0]
	f.slot = 0
	for i in 2:
		var mag := int(Cfg.weapons[f.slots[i]].mag)
		f.ammo[i] = mag
		f.reserve[i] = -1 if bool(S.unl_ammo) else mag * 3
	f.nades = 99 if bool(S.unl_nades) else 3
	f.reload_t = 0.0
	f.fuel = 100.0

func _spawn(f: Fighter) -> void:
	var best := Vector2(map.w * 0.5, map.h * 0.5)
	var best_d := -1.0
	var sps: Array = map.spawns
	for i in 4:
		var c: Vector2 = sps[randi() % sps.size()]
		var md := 99999.0
		for o: Fighter in fighters.values():
			if o != f and o.alive:
				md = minf(md, o.pos.distance_to(c))
		if md > best_d:
			best_d = md
			best = c
	f.pos = best
	f.tpos = best
	f.vel = Vector2.ZERO
	f.alive = true
	f.hp = float(S.health)
	f.prot = 2.0
	f.air_jumps = 1
	f.gas_acc = 0.0
	_fill_loadout(f)

func _sim_fighter(f: Fighter, dt: float) -> void:
	if not f.alive:
		f.respawn_t -= dt
		if f.respawn_t <= 0.0 and not ended:
			_spawn(f)
		return
	f.fire_cd = maxf(0.0, f.fire_cd - dt)
	f.nade_cd = maxf(0.0, f.nade_cd - dt)
	f.prot = maxf(0.0, f.prot - dt)
	f.melee_cd = maxf(0.0, f.melee_cd - dt)
	f.speed_t = maxf(0.0, f.speed_t - dt)
	f.shield_t = maxf(0.0, f.shield_t - dt)
	f.dmg_t = maxf(0.0, f.dmg_t - dt)
	f.aim = float(f.inp.aim)
	if f.reload_t > 0.0:
		f.reload_t -= dt
		if f.reload_t <= 0.0:
			_finish_reload(f)
	var al: Array = acts[f.id]
	for k in al:
		match int(k):
			1: _throw_nade(f)
			2:
				f.slot = 1 - f.slot
				f.reload_t = 0.0
			3: _melee(f)
			4: f.gtype = (f.gtype + 1) % 4
	al.clear()
	_move(f, dt)
	if bool(f.inp.fire) and f.fire_cd <= 0.0 and f.reload_t <= 0.0:
		_fire(f)
	if bool(S.gas_damage) and not bool(S.gas_immune) and f.on_floor and f.prot <= 0.0:
		var body := Rect2(f.pos - HALF, SIZE)
		for g: Rect2 in gas_zones:
			if g.intersects(body):
				f.gas_acc += 14.0 * dt
				if f.gas_acc >= 1.0:
					damage(f, f.gas_acc, 0, -2)
					f.gas_acc = 0.0
				break

func _move(f: Fighter, dt: float) -> void:
	var inp: Dictionary = f.inp
	var acc := 2200.0 if f.on_floor else 1100.0
	f.vel.x = move_toward(f.vel.x, float(inp.mx) * RUN * (1.45 if f.speed_t > 0.0 else 1.0), acc * dt)
	var can_jet: bool = bool(S.unl_jet) or f.fuel > 0.0
	f.jets = bool(inp.jet) and can_jet
	if f.jets:
		var my := float(inp.my)
		var ty := my * 320.0 - 90.0 * (1.0 - absf(my))
		f.vel.y = move_toward(f.vel.y, ty, 1700.0 * dt)
		if not bool(S.unl_jet):
			f.fuel = maxf(0.0, f.fuel - 38.0 * dt)
	else:
		f.vel.y = minf(f.vel.y + GRAV * gravity_mul * dt, 900.0)
		if float(inp.my) > 0.55 and not f.on_floor:
			f.vel.y = minf(f.vel.y + 1400.0 * dt, 900.0)
		if not bool(S.unl_jet) and f.on_floor:
			f.fuel = minf(100.0, f.fuel + 30.0 * dt)
	if f.on_floor:
		f.air_jumps = 1
	if f.jump_req:
		f.jump_req = false
		if f.on_floor:
			f.vel.y = -JUMP
		elif f.air_jumps > 0:
			f.vel.y = -JUMP * 0.9
			f.air_jumps -= 1
	f.pos.x += f.vel.x * dt
	var r := Rect2(f.pos - HALF, SIZE)
	for s: Rect2 in solids:
		if r.intersects(s):
			if f.vel.x > 0.0:
				f.pos.x = s.position.x - HALF.x - 0.01
			elif f.vel.x < 0.0:
				f.pos.x = s.end.x + HALF.x + 0.01
			f.vel.x = 0.0
			r = Rect2(f.pos - HALF, SIZE)
	f.on_floor = false
	f.pos.y += f.vel.y * dt
	r = Rect2(f.pos - HALF, SIZE)
	for s: Rect2 in solids:
		if r.intersects(s):
			if f.vel.y > 0.0:
				f.pos.y = s.position.y - HALF.y - 0.01
				f.on_floor = true
			elif f.vel.y < 0.0:
				f.pos.y = s.end.y + HALF.y + 0.01
			f.vel.y = 0.0
			r = Rect2(f.pos - HALF, SIZE)
	f.pos.x = clampf(f.pos.x, HALF.x, float(map.w) - HALF.x)
	f.pos.y = clampf(f.pos.y, HALF.y, float(map.h) - HALF.y)

func _finish_reload(f: Fighter) -> void:
	var s: int = f.slot
	var mag := int(Cfg.weapons[f.slots[s]].mag)
	if int(f.reserve[s]) < 0:
		f.ammo[s] = mag
	else:
		var take := mini(mag - int(f.ammo[s]), int(f.reserve[s]))
		f.ammo[s] += take
		f.reserve[s] -= take

func _fire(f: Fighter) -> void:
	var s: int = f.slot
	var wi: int = f.slots[s]
	var w: Dictionary = Cfg.weapons[wi]
	if not bool(S.no_reload):
		if int(f.ammo[s]) <= 0:
			if int(f.reserve[s]) != 0:
				f.reload_t = float(w.reload)
			elif int(f.ammo[1 - s]) > 0 or int(f.reserve[1 - s]) != 0:
				f.slot = 1 - s
			return
		f.ammo[s] -= 1
	f.fire_cd = 1.0 / float(w.rate)
	f.flash = 0.06
	var dir := Vector2.from_angle(f.aim)
	var mp := f.pos + Vector2(0, -8) + dir * 58.0
	for i in int(w.pellets):
		var b: Bullet = _new_bullet()
		if b == null:
			break
		var a := f.aim + deg_to_rad(randf_range(-float(w.spread), float(w.spread)))
		var d := Vector2.from_angle(a)
		b.pos = mp
		b.vel = d * float(w.speed)
		b.life = float(w.life)
		b.dmg = float(w.dmg) * (2.0 if f.dmg_t > 0.0 else 1.0)
		b.gt = 0
		b.stuck = false
		b.owner_id = f.id
		b.team = f.team
		b.kind = int(w.k)
		b.radius = float(w.radius)
		b.wi = wi
		b.grav = 900.0 if b.kind == Cfg.KIND_GRENADE else 0.0
	f.vel -= dir * float(w.recoil)
	fx.spark(mp, Color(1, 0.9, 0.5), 2)
	Sfx.play(String(w.sfx), f.pos)

func _throw_nade(f: Fighter) -> void:
	if f.nade_cd > 0.0:
		return
	if not bool(S.unl_nades) and f.nades <= 0:
		return
	var b: Bullet = _new_bullet()
	if b == null:
		return
	if not bool(S.unl_nades):
		f.nades -= 1
	f.nade_cd = 0.8
	var dir := Vector2.from_angle(f.aim)
	b.pos = f.pos + dir * 20.0
	b.vel = dir * 620.0 * float(S.throw_power) + f.vel * 0.4
	b.gt = f.gtype
	b.stuck = false
	b.life = 2.0 if f.gtype < 2 else 1.4
	b.dmg = (85.0 if f.gtype == 0 else 95.0) * (2.0 if f.dmg_t > 0.0 else 1.0)
	b.radius = 110.0 if f.gtype == 0 else 90.0
	b.owner_id = f.id
	b.team = f.team
	b.kind = Cfg.KIND_GRENADE
	b.grav = 1300.0
	b.wi = -1

func _melee(f: Fighter) -> void:
	if f.melee_cd > 0.0 or not f.alive:
		return
	f.melee_cd = 0.5
	f.melee_t = 0.2
	var dir := Vector2.from_angle(f.aim)
	var c := f.pos + dir * 54.0
	Sfx.play("heavy", f.pos)
	for o: Fighter in fighters.values():
		if o == f or not o.alive:
			continue
		if o.team == f.team and not bool(S.friendly_fire):
			continue
		if o.pos.distance_to(c) <= 66.0:
			damage(o, 45.0 * float(S.dmg_mult) * (2.0 if f.dmg_t > 0.0 else 1.0), f.id, -3)
			o.vel += dir * 380.0 + Vector2(0.0, -120.0)
			fx.spark(o.pos, Color(1, 0.3, 0.2), 6)

func _new_bullet() -> Bullet:
	for b: Bullet in pool:
		if not b.active:
			b.active = true
			return b
	return null

# ------------------------------------------------------------------ bullets / explosions
func _point_solid(p: Vector2) -> bool:
	for s: Rect2 in solids:
		if s.has_point(p):
			return true
	return false

func _seg_rect(p0: Vector2, p1: Vector2, r: Rect2) -> float:
	var d := p1 - p0
	var tmin := 0.0
	var tmax := 1.0
	for ax in 2:
		var o: float = p0[ax]
		var dd: float = d[ax]
		var lo: float = r.position[ax]
		var hi: float = r.end[ax]
		if absf(dd) < 0.00001:
			if o < lo or o > hi:
				return -1.0
		else:
			var t1 := (lo - o) / dd
			var t2 := (hi - o) / dd
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin

func _blocked(a: Vector2, b: Vector2) -> bool:
	for s: Rect2 in solids:
		if _seg_rect(a, b, s) >= 0.0:
			return true
	return false

func _sim_grenade(b: Bullet, dt: float) -> void:
	if b.stuck:
		return
	if b.gt == 1:
		for f: Fighter in fighters.values():
			if f.alive and f.id != b.owner_id and f.team != b.team and Rect2(f.pos - HALF, SIZE).has_point(b.pos):
				b.stuck = true
				b.vel = Vector2.ZERO
				return
	b.vel.y += b.grav * dt
	var np := b.pos + Vector2(b.vel.x * dt, 0.0)
	if _point_solid(np):
		if b.gt == 1:
			b.stuck = true
			b.vel = Vector2.ZERO
			return
		b.vel.x *= -0.45
	else:
		b.pos.x = np.x
	np = b.pos + Vector2(0.0, b.vel.y * dt)
	if _point_solid(np):
		if b.gt == 1:
			b.stuck = true
			b.vel = Vector2.ZERO
			return
		b.vel.y *= -0.35
		b.vel.x *= 0.8
		if absf(b.vel.y) < 40.0:
			b.vel.y = 0.0
	else:
		b.pos.y = np.y

func _grenade_end(b: Bullet) -> void:
	match b.gt:
		2: _make_cloud(b.pos, 2)
		3: _make_cloud(b.pos, 3)
		_: _explode(b.pos, b.radius, b.dmg, b.owner_id, b.team, b.wi)

func _make_cloud(p: Vector2, kind: int) -> void:
	var dur := 6.0 if kind == 3 else 8.0
	clouds.append({"pos": p, "t": dur, "kind": kind})
	fx.cloud(p, kind, dur)
	if Net.online:
		Net.rpc("cli_cloud", p.x, p.y, kind)

func _sim_clouds(dt: float) -> void:
	var i := clouds.size() - 1
	while i >= 0:
		var c: Dictionary = clouds[i]
		c.t -= dt
		if c.t <= 0.0:
			clouds.remove_at(i)
		elif int(c.kind) == 3 and bool(S.gas_damage) and not bool(S.gas_immune):
			for f: Fighter in fighters.values():
				if f.alive and f.prot <= 0.0 and f.pos.distance_to(c.pos) < 120.0:
					f.gas_acc += 16.0 * dt
					if f.gas_acc >= 1.0:
						damage(f, f.gas_acc, 0, -2)
						f.gas_acc = 0.0
		i -= 1

func _sim_items(dt: float) -> void:
	for it in items:
		if int(it.ty) < 0:
			it.t -= dt
			if it.t <= 0.0:
				it.ty = randi() % 4
			continue
		var r := Rect2(Vector2(it.pos) - Vector2(14, 14), Vector2(28, 28))
		for f: Fighter in fighters.values():
			if f.alive and Rect2(f.pos - HALF, SIZE).intersects(r):
				match int(it.ty):
					0: f.hp = minf(float(S.health), f.hp + 50.0)
					1: f.speed_t = 10.0
					2: f.shield_t = 8.0
					3: f.dmg_t = 12.0
				Sfx.play("pick", it.pos)
				if Net.online:
					Net.rpc("cli_pickup", Vector2(it.pos).x, Vector2(it.pos).y)
				it.ty = -1
				it.t = 20.0
				break

func _sim_bullets(dt: float) -> void:
	for b: Bullet in pool:
		if not b.active:
			continue
		b.life -= dt
		if b.kind == Cfg.KIND_GRENADE:
			_sim_grenade(b, dt)
			if b.life <= 0.0:
				_grenade_end(b)
				b.active = false
			continue
		if b.life <= 0.0:
			if b.kind == Cfg.KIND_ROCKET:
				_explode(b.pos, b.radius, b.dmg, b.owner_id, b.team, b.wi)
			b.active = false
			continue
		var p0: Vector2 = b.pos
		var p1: Vector2 = p0 + b.vel * dt
		var tw := 2.0
		for s: Rect2 in solids:
			var t := _seg_rect(p0, p1, s)
			if t >= 0.0 and t < tw:
				tw = t
		var tf := 2.0
		var hit: Fighter = null
		for f: Fighter in fighters.values():
			if not f.alive or f.id == b.owner_id:
				continue
			if f.team == b.team and not bool(S.friendly_fire):
				continue
			var t := _seg_rect(p0, p1, Rect2(f.pos - HALF - Vector2(3, 3), SIZE + Vector2(6, 6)))
			if t >= 0.0 and t < tf:
				tf = t
				hit = f
		if hit != null and tf <= tw:
			b.pos = p0 + (p1 - p0) * tf
			b.active = false
			if b.kind == Cfg.KIND_ROCKET:
				_explode(b.pos, b.radius, b.dmg, b.owner_id, b.team, b.wi)
			else:
				damage(hit, b.dmg * float(S.dmg_mult), b.owner_id, b.wi)
				if b.kind != Cfg.KIND_FLAME:
					fx.spark(b.pos, Color(1, 0.3, 0.2), 4)
					Sfx.play("hit", b.pos)
					if Net.online:
						Net.rpc("cli_hit", b.pos.x, b.pos.y)
		elif tw <= 1.0:
			b.pos = p0 + (p1 - p0) * tw
			b.active = false
			if b.kind == Cfg.KIND_ROCKET:
				_explode(b.pos, b.radius, b.dmg, b.owner_id, b.team, b.wi)
			elif b.kind == Cfg.KIND_BULLET:
				fx.spark(b.pos, Color(0.9, 0.9, 0.8), 3)
		else:
			b.pos = p1

func _explode(p: Vector2, r: float, dmg: float, owner_id: int, team: int, wi: int) -> void:
	fx.boom(p, r)
	Sfx.play("boom", p)
	if Net.online:
		Net.rpc("cli_boom", p.x, p.y, r)
	for f: Fighter in fighters.values():
		if not f.alive:
			continue
		var d := f.pos.distance_to(p)
		var reach := r + 34.0
		if d > reach:
			continue
		var fall := 1.0 - d / reach
		var dir := (f.pos - p).normalized() if d > 1.0 else Vector2.UP
		f.vel += dir * 750.0 * fall + Vector2(0.0, -150.0 * fall)
		var dd := dmg * fall * float(S.dmg_mult)
		if f.id == owner_id:
			if bool(S.self_damage):
				damage(f, dd * 0.6, owner_id, wi)
		elif f.team != team or bool(S.friendly_fire):
			damage(f, dd, owner_id, wi)

func damage(f: Fighter, amt: float, killer: int, wi: int) -> void:
	if not f.alive or f.prot > 0.0 or ended:
		return
	if f.shield_t > 0.0:
		amt *= 0.25
	f.hp -= amt
	f.hurt = 0.15
	if f.hp > 0.0:
		return
	f.hp = 0.0
	f.alive = false
	f.deaths += 1
	f.respawn_t = float(S.respawn)
	f.jets = false
	var k: Fighter = fighters.get(killer)
	if k != null and k != f:
		if k.team != f.team:
			k.kills += 1
			team_scores[k.team] += 1
		else:
			k.kills -= 1
			team_scores[k.team] -= 1
	show_kill(killer, f.id, wi)
	if Net.online:
		Net.rpc("cli_kill", killer, f.id, wi)
	_check_win()

func _check_win() -> void:
	var limit := int(S.kill_limit)
	if team_mode:
		for i in 4:
			if team_scores[i] >= limit:
				_finish()
				return
	else:
		for f: Fighter in fighters.values():
			if f.kills >= limit:
				_finish()
				return

func _sim_crates(dt: float) -> void:
	for c in crates:
		if int(c.w) < 0:
			c.t -= dt
			if c.t <= 0.0:
				c.w = 1 + randi() % (Cfg.weapons.size() - 1)
			continue
		var cr := Rect2(Vector2(c.pos) - Vector2(14, 14), Vector2(28, 28))
		for f: Fighter in fighters.values():
			if f.alive and Rect2(f.pos - HALF, SIZE).intersects(cr):
				var wi: int = c.w
				if int(f.slots[f.slot]) != wi and int(f.slots[1 - f.slot]) != wi:
					f.slots[f.slot] = wi
					var mag := int(Cfg.weapons[wi].mag)
					f.ammo[f.slot] = mag
					f.reserve[f.slot] = -1 if bool(S.unl_ammo) else mag * 3
					f.reload_t = 0.0
				c.w = -1
				c.t = 15.0
				Sfx.play("pick", c.pos)
				if Net.online:
					Net.rpc("cli_pickup", Vector2(c.pos).x, Vector2(c.pos).y)
				break

# ------------------------------------------------------------------ bots
func _wrange(wi: int) -> float:
	var w: Dictionary = Cfg.weapons[wi]
	return minf(float(w.speed) * float(w.life), 900.0)

func _bot_think(f: Fighter, dt: float) -> void:
	var d := clampi(int(S.bot_diff), 0, 2)
	var inp: Dictionary = f.inp
	f.bot_t -= dt
	f.bot_flee_t = maxf(0.0, f.bot_flee_t - dt)
	if f.bot_t <= 0.0 and f.alive:
		f.bot_t = [0.5, 0.35, 0.2][d] * randf_range(0.7, 1.3)
		var best := 1e9
		f.bot_target = 0
		for o: Fighter in fighters.values():
			if o == f or not o.alive or o.team == f.team:
				continue
			var dd := f.pos.distance_to(o.pos)
			if dd < best:
				best = dd
				f.bot_target = o.id
		var tf: Fighter = fighters.get(f.bot_target)
		if tf != null:
			f.bot_los = not _blocked(f.pos, tf.pos)
			if randf() < 0.4:
				f.bot_strafe = -f.bot_strafe
			if randf() < 0.25:
				var s0 := absf(_wrange(int(f.slots[f.slot])) - best * 1.3)
				var s1 := absf(_wrange(int(f.slots[1 - f.slot])) - best * 1.3)
				if s1 < s0 - 80.0:
					acts[f.id].append(2)
			if f.bot_los and best > 180.0 and best < 560.0 and randf() < 0.08 * float(d + 1) and f.nade_cd <= 0.0:
				var r := randf()
				f.gtype = 0 if r < 0.7 else (3 if r < 0.88 else 2)
				acts[f.id].append(1)
		# where to go: health when hurt, otherwise weapons / power-ups when idle or far away
		f.bot_has = false
		if f.hp < 40.0:
			var bd := 1e9
			for it in items:
				if int(it.ty) == 0 and f.pos.distance_to(it.pos) < bd:
					bd = f.pos.distance_to(it.pos)
					f.bot_dest = it.pos
					f.bot_has = true
		if not f.bot_has and (tf == null or best > 700.0):
			var bd2 := 900.0
			for c in crates:
				if int(c.w) >= 0 and f.pos.distance_to(c.pos) < bd2:
					bd2 = f.pos.distance_to(c.pos)
					f.bot_dest = c.pos
					f.bot_has = true
			for it in items:
				if int(it.ty) >= 0 and f.pos.distance_to(it.pos) < bd2:
					bd2 = f.pos.distance_to(it.pos)
					f.bot_dest = it.pos
					f.bot_has = true
		# dodge incoming rockets / grenades
		for pb: Bullet in pool:
			if pb.active and (pb.kind == Cfg.KIND_ROCKET or pb.kind == Cfg.KIND_GRENADE) and pb.owner_id != f.id and pb.pos.distance_to(f.pos) < 170.0:
				f.bot_flee = (f.pos - pb.pos).normalized()
				f.bot_flee_t = 0.6
				break
		var sx := signf(float(inp.mx))
		var ahead := Vector2(sx * 34.0, -8.0)
		f.bot_block = _point_solid(f.pos + ahead) or _point_solid(f.pos + ahead + Vector2(0, -34.0)) or _point_solid(f.pos + ahead + Vector2(0, 30.0))
	var tgt: Fighter = fighters.get(f.bot_target)
	var have := tgt != null and tgt.alive
	var to := Vector2.ZERO
	if have:
		to = tgt.pos - f.pos
		if to.length() < 72.0 and f.melee_cd <= 0.0 and randf() < 0.08:
			acts[f.id].append(3)
		var err: float = [0.30, 0.13, 0.05][d]
		inp["aim"] = to.angle() + sin(elapsed * 2.7 + float(f.id)) * err
		var rng := _wrange(int(f.slots[f.slot]))
		inp["fire"] = f.bot_los and to.length() < rng and randf() < [0.5, 0.75, 0.95][d]
	else:
		inp["fire"] = false
	var mx := 0.0
	var my := 0.0
	var jet := false
	if f.bot_flee_t > 0.0:
		mx = signf(f.bot_flee.x)
		my = clampf(f.bot_flee.y, -1.0, 1.0)
		jet = true
	elif f.hp < 30.0 and have and to.length() < 500.0:
		mx = -signf(to.x)
		my = -0.6
		jet = true
	elif f.bot_has and (not have or f.hp < 40.0):
		var dv := f.bot_dest - f.pos
		mx = signf(dv.x) if absf(dv.x) > 24.0 else 0.0
		jet = dv.y < -40.0 or f.bot_block
		my = -1.0 if dv.y < -40.0 else (0.5 if dv.y > 60.0 else 0.0)
	elif have:
		var pref := 360.0
		var ax := absf(to.x)
		if ax > pref + 80.0:
			mx = signf(to.x)
		elif ax < pref * 0.5:
			mx = -signf(to.x)
		else:
			mx = f.bot_strafe * 0.6
		var up := to.y < -90.0
		jet = up or f.bot_block or (f.pos.y > float(map.h) - 170.0 and to.y < 40.0)
		my = -1.0 if (up or f.bot_block) else (0.5 if to.y > 110.0 else 0.0)
	else:
		mx = f.bot_strafe * 0.5
		jet = f.pos.y > float(map.h) * 0.55
	if f.bot_block and f.on_floor and randf() < 0.05:
		f.jump_req = true
	inp["mx"] = mx
	inp["my"] = my
	inp["jet"] = jet

# ------------------------------------------------------------------ networking (snapshots)
func _push64(a: PackedFloat64Array, v: float) -> void:
	a.push_back(v)

func _send_snapshot() -> void:
	var fs := PackedFloat64Array()
	for id in order:
		var f: Fighter = fighters[id]
		var flags := 0
		if f.alive: flags |= 1
		if f.jets: flags |= 2
		if f.flash > 0.0: flags |= 4
		if f.prot > 0.0: flags |= 8
		if f.on_floor: flags |= 16
		if f.shield_t > 0.0: flags |= 32
		if f.dmg_t > 0.0: flags |= 64
		if f.speed_t > 0.0: flags |= 128
		if f.melee_t > 0.0: flags |= 256
		flags |= (f.gtype & 3) << 9
		fs.push_back(float(id))
		fs.push_back(f.pos.x)
		fs.push_back(f.pos.y)
		fs.push_back(f.aim)
		fs.push_back(f.hp)
		fs.push_back(float(f.slots[f.slot]))
		fs.push_back(float(flags))
	var bs := PackedFloat32Array()
	for b: Bullet in pool:
		if b.active and bs.size() < 5 * 140:
			bs.push_back(b.pos.x)
			bs.push_back(b.pos.y)
			bs.push_back(b.vel.angle())
			bs.push_back(b.vel.length())
			bs.push_back(float(b.kind))
	var cs := PackedInt32Array()
	for c in crates:
		cs.push_back(int(c.w))
	for it in items:
		cs.push_back(int(it.ty))
	Net.rpc("cli_snap", fs, bs, cs)

func apply_snapshot(fs: PackedFloat64Array, bs: PackedFloat32Array, cs: PackedInt32Array) -> void:
	if ended or is_host:
		return
	var i := 0
	while i + 6 < fs.size():
		var id := int(fs[i])
		var f: Fighter = fighters.get(id)
		if f != null:
			var np := Vector2(fs[i + 1], fs[i + 2])
			var flags := int(fs[i + 6])
			var was_alive := f.alive
			f.alive = (flags & 1) != 0
			f.jets = (flags & 2) != 0
			if (flags & 4) != 0 and f.flash <= 0.0:
				f.flash = 0.05
				var wsf := int(fs[i + 5])
				if wsf >= 0 and wsf < Cfg.weapons.size():
					Sfx.play(String(Cfg.weapons[wsf].sfx), np)
			f.prot = 1.0 if (flags & 8) != 0 else 0.0
			f.on_floor = (flags & 16) != 0
			f.shield_t = 1.0 if (flags & 32) != 0 else 0.0
			f.dmg_t = 1.0 if (flags & 64) != 0 else 0.0
			f.speed_t = 1.0 if (flags & 128) != 0 else 0.0
			if (flags & 256) != 0 and f.melee_t <= 0.0:
				f.melee_t = 0.2
			f.gtype = (flags >> 9) & 3
			f.hp = float(fs[i + 4])
			f.cur_weapon = int(fs[i + 5])
			f.tpos = np
			if id != local_id:
				f.aim = float(fs[i + 3])
			if f.alive and (not was_alive or f.pos == Vector2.ZERO):
				f.pos = np
				f.vel = Vector2.ZERO
			if id == local_id and f.alive:
				var e := f.pos.distance_to(np)
				if e > 200.0:
					f.pos = np
				elif e > 48.0:
					f.pos = f.pos.lerp(np, 0.2)
		i += 7
	view_bullets = bs
	view_age = 0.0
	for k in mini(cs.size(), crates.size()):
		crates[k].w = cs[k]
	var nc := crates.size()
	for k in items.size():
		if nc + k < cs.size():
			items[k].ty = cs[nc + k]

func _send_state() -> void:
	var kd := PackedInt32Array()
	for id in order:
		var f: Fighter = fighters[id]
		kd.push_back(id)
		kd.push_back(f.kills)
		kd.push_back(f.deaths)
	var ts := PackedInt32Array()
	for v in team_scores:
		ts.push_back(int(v))
	Net.rpc("cli_state", time_left, kd, ts)

func apply_state(tl: float, kd: PackedInt32Array, ts: PackedInt32Array) -> void:
	time_left = tl
	var i := 0
	while i + 2 < kd.size():
		var f: Fighter = fighters.get(kd[i])
		if f != null:
			f.kills = kd[i + 1]
			f.deaths = kd[i + 2]
		i += 3
	for k in mini(ts.size(), team_scores.size()):
		team_scores[k] = ts[k]

# ------------------------------------------------------------------ feed / results
func show_kill(killer: int, victim: int, wi: int) -> void:
	var v: Fighter = fighters.get(victim)
	var k: Fighter = fighters.get(killer)
	if v == null:
		return
	var wn := "Grenade" if wi == -1 else ("Toxic gas" if wi == -2 else ("Melee" if wi == -3 else String(Cfg.weapons[wi].name)))
	var txt := "%s died (%s)" % [v.pname, wn]
	var col := v.color
	if k != null and k != v:
		txt = "%s > %s  [%s]" % [k.pname, v.pname, wn]
		col = k.color
	feed.append([txt, col, 5.0])
	while feed.size() > 5:
		feed.pop_front()
	Sfx.play("die", v.pos)

func _finish() -> void:
	if ended:
		return
	var res: Array = []
	for id in order:
		var f: Fighter = fighters[id]
		res.append([id, f.pname, f.team, f.kills, f.deaths])
	res.sort_custom(func(a: Array, b: Array) -> bool:
		return a[3] > b[3] or (a[3] == b[3] and a[4] < b[4]))
	var win := "Draw"
	if team_mode:
		var bt := 0
		for i in 4:
			if team_scores[i] > team_scores[bt]:
				bt = i
		var ties := 0
		for i in 4:
			if team_scores[i] == team_scores[bt]:
				ties += 1
		if ties == 1:
			win = "%s team wins!" % Cfg.TEAM_NAMES[bt]
	elif res.size() > 0 and (res.size() == 1 or res[0][3] > res[1][3]):
		win = "%s wins!" % res[0][1]
	if Net.online:
		Net.rpc("cli_end", res, win)
	show_results(res, win)

func show_results(res: Array, win: String) -> void:
	ended = true
	if result_ui != null:
		return
	result_ui = CanvasLayer.new()
	result_ui.layer = 30
	result_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(result_ui)
	var rh := TapHelper.new()
	rh.root = result_ui
	result_ui.add_child(rh)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_ui.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 24
	cc.theme = th
	result_ui.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	cc.add_child(box)
	var t := Label.new()
	t.text = win
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	box.add_child(t)
	var hdr := Label.new()
	hdr.text = "%-16s %6s %6s" % ["Player", "Kills", "Deaths"]
	box.add_child(hdr)
	var shown := 0
	for r in res:
		if shown >= 12:
			break
		var l := Label.new()
		l.text = "%-16s %6d %6d" % [String(r[1]).left(14), int(r[3]), int(r[4])]
		var col: Color = Cfg.TEAM_COLORS[int(r[2]) % 4] if team_mode else Color.WHITE
		l.add_theme_color_override("font_color", col)
		box.add_child(l)
		shown += 1
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	if not Net.online:
		var again := Button.new()
		again.text = "Play Again"
		again.custom_minimum_size = Vector2(260, 64)
		again.pressed.connect(func() -> void:
			get_tree().paused = false
			Net.start_solo())
		row.add_child(again)
	var back := Button.new()
	back.text = "Back to Lobby" if Net.online else "Main Menu"
	back.custom_minimum_size = Vector2(260, 64)
	back.pressed.connect(func() -> void:
		get_tree().paused = false
		Net.back_to_lobby_or_menu())
	row.add_child(back)
