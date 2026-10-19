extends Control
const TapHelper := preload("res://scripts/tap_helper.gd")
## All menu screens, built in code: main, practice, local multiplayer, host, join, lobby, settings, help.

var content: VBoxContainer
var screen := "main"
var form_mode := "practice"   # practice | host_new | host_edit
var status: Label
var join_ip: LineEdit
var join_code: LineEdit
var found_box: VBoxContainer
var lobby_box: VBoxContainer
var _t := 0.0
var scroll_ref: ScrollContainer

func _ready() -> void:
	var th := Theme.new()
	th.default_font_size = 26
	theme = th
	var bg := ColorRect.new()
	bg.color = Color("10182a")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 36)
	add_child(mc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mc.add_child(sc)
	scroll_ref = sc
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	sc.add_child(content)
	var helper := TapHelper.new()
	helper.root = self
	helper.scroll = scroll_ref
	add_child(helper)
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.host_lost.connect(_on_host_lost)
	if Net.menu_start == "lobby" and Net.online:
		_lobby()
	else:
		_main()
	Net.menu_start = "main"

func _exit_tree() -> void:
	Net.lobby_changed.disconnect(_on_lobby_changed)
	Net.joined.disconnect(_on_joined)
	Net.join_failed.disconnect(_on_join_failed)
	Net.host_lost.disconnect(_on_host_lost)
	Net.stop_listen()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "main":
			get_tree().quit()
		elif screen == "lobby":
			_leave_lobby()
		else:
			_main()

# ---------------------------------------------------------------- helpers
func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	if screen == "join":
		Net.stop_listen()
	status = null
	found_box = null
	lobby_box = null

func _lbl(text: String, parent: Node, size: int = 26, col: Color = Color.WHITE, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _btn(text: String, cb: Callable, parent: Node, w: int = 340) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 66)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r

func _title(t: String, sub: String = "") -> void:
	_lbl(t, content, 46, Color("ffd36b"), true)
	if sub != "":
		_lbl(sub, content, 22, Color(1, 1, 1, 0.7), true)

func _fmt(key: String, v: float) -> String:
	match key:
		"duration": return "%d:%02d" % [int(v) / 60, int(v) % 60]
		"respawn": return "%.1fs" % v
		"dmg_mult", "throw_power", "ui_scale", "volume", "touch_opacity": return "%.2f" % v
		"view_w": return "%d" % int(v)
	return "%d" % int(v)

func _stepper(d: Dictionary, label: String, key: String, mn: float, mx: float, step: float) -> void:
	var row := _row(content)
	var l := _lbl(label, row)
	l.custom_minimum_size.x = 380
	var vl := _lbl(_fmt(key, float(d[key])), row, 26, Color("9fe0ff"), true)
	vl.custom_minimum_size.x = 130
	var f := func(delta: float) -> void:
		var v := clampf(float(d[key]) + delta, mn, mx)
		d[key] = v if (step < 1.0 or key == "volume") else int(round(v))
		vl.text = _fmt(key, float(d[key]))
	var bm := Button.new()
	bm.text = "-"
	bm.custom_minimum_size = Vector2(70, 60)
	bm.pressed.connect(func() -> void: f.call(-step))
	row.add_child(bm)
	row.move_child(bm, 1)
	var bp := Button.new()
	bp.text = "+"
	bp.custom_minimum_size = Vector2(70, 60)
	bp.pressed.connect(func() -> void: f.call(step))
	row.add_child(bp)

func _choice(d: Dictionary, label: String, key: String, opts: Array) -> void:
	var row := _row(content)
	var l := _lbl(label, row)
	l.custom_minimum_size.x = 380
	var cur := 0
	for i in opts.size():
		if opts[i][0] == d[key]:
			cur = i
	var vl := _lbl(String(opts[cur][1]), row, 24, Color("9fe0ff"), true)
	vl.custom_minimum_size.x = 260
	var f := func(delta: int) -> void:
		cur = (cur + delta + opts.size()) % opts.size()
		d[key] = opts[cur][0]
		vl.text = String(opts[cur][1])
	var bm := Button.new()
	bm.text = "<"
	bm.custom_minimum_size = Vector2(70, 60)
	bm.pressed.connect(func() -> void: f.call(-1))
	row.add_child(bm)
	row.move_child(bm, 1)
	var bp := Button.new()
	bp.text = ">"
	bp.custom_minimum_size = Vector2(70, 60)
	bp.pressed.connect(func() -> void: f.call(1))
	row.add_child(bp)

func _toggle(d: Dictionary, label: String, key: String) -> void:
	var row := _row(content)
	var l := _lbl(label, row)
	l.custom_minimum_size.x = 380
	var b := Button.new()
	b.custom_minimum_size = Vector2(160, 60)
	b.text = "ON" if bool(d[key]) else "OFF"
	b.pressed.connect(func() -> void:
		d[key] = not bool(d[key])
		b.text = "ON" if bool(d[key]) else "OFF")
	row.add_child(b)

# ---------------------------------------------------------------- screens
func _main() -> void:
	screen = "main"
	_clear()
	_title("JETPACK ARENA", "Offline 2D multiplayer jetpack shooter  -  v" + Cfg.VERSION)
	if Net.last_msg != "":
		_lbl(Net.last_msg, content, 24, Color("ff9a8a"), true)
		Net.last_msg = ""
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 14)
	content.add_child(g)
	_btn("Play Offline", _quick_play, g, 420)
	_btn("Practice With Bots", func() -> void: _form("practice"), g, 420)
	_btn("Local Multiplayer", _local_mp, g, 420)
	_btn("Host Match", func() -> void: _form("host_new"), g, 420)
	_btn("Join Match", _join, g, 420)
	_btn("Settings", _settings, g, 420)
	_btn("How To Play", _help, g, 420)
	_btn("Exit", func() -> void: get_tree().quit(), g, 420)

func _quick_play() -> void:
	Net.settings = Cfg.default_settings()
	Net.settings.bots = 5
	Net.settings.map = randi() % Cfg.maps.size()
	Net.start_solo()

func _local_mp() -> void:
	screen = "lmp"
	_clear()
	_title("Local Multiplayer", "Up to 12 players on one Wi-Fi network or phone hotspot - no internet needed")
	_lbl("1. One player turns on their phone hotspot (or everyone joins the same Wi-Fi).\n2. Everyone installs the same APK and connects to that network.\n3. The hotspot owner taps Host Match, the others tap Join Match.\n4. Joiners pick the host from the list, or type the IP shown in the host's lobby.", content, 24)
	var r := _row(content)
	_btn("Host Match", func() -> void: _form("host_new"), r)
	_btn("Join Match", _join, r)
	_btn("Back", _main, content, 200)

func _form(mode: String) -> void:
	form_mode = mode
	screen = "form"
	_clear()
	var maps: Array = []
	for i in Cfg.maps.size():
		maps.append([i, Cfg.maps[i].name])
	var d := Net.settings
	_title("Practice With Bots" if mode == "practice" else "Match Settings")
	_choice(d, "Map", "map", maps)
	_choice(d, "Game mode", "mode", [["ffa", "Free-for-all"], ["team", "Team Deathmatch"], ["custom", "Custom teams"]])
	_stepper(d, "Teams (custom mode)", "teams", 2, 4, 1)
	_stepper(d, "Bots", "bots", 0, 11, 1)
	_choice(d, "Bot difficulty", "bot_diff", [[0, "Easy"], [1, "Normal"], [2, "Hard"]])
	if mode != "practice":
		_stepper(d, "Max players", "max_players", 1, 12, 1)
	_stepper(d, "Match time", "duration", 60, 1200, 60)
	_stepper(d, "Kill limit", "kill_limit", 5, 100, 5)
	_stepper(d, "Respawn delay", "respawn", 1, 10, 1)
	_stepper(d, "Player health", "health", 50, 300, 25)
	_stepper(d, "Weapon damage x", "dmg_mult", 0.25, 3.0, 0.25)
	_toggle(d, "Friendly fire", "friendly_fire")
	_toggle(d, "Unlimited ammo", "unl_ammo")
	_toggle(d, "No reload", "no_reload")
	_toggle(d, "Unlimited grenades", "unl_nades")
	_stepper(d, "Grenade throw power", "throw_power", 0.5, 1.5, 0.25)
	_toggle(d, "Unlimited jetpack", "unl_jet")
	_toggle(d, "Toxic gas damage", "gas_damage")
	_toggle(d, "Everyone immune to gas", "gas_immune")
	_toggle(d, "Explosions hurt thrower", "self_damage")
	if mode == "host_new" or mode == "host_edit":
		var row := _row(content)
		_lbl("Room code (optional)", row).custom_minimum_size.x = 380
		var le := LineEdit.new()
		le.text = String(d.code)
		le.max_length = 8
		le.custom_minimum_size = Vector2(240, 60)
		le.text_changed.connect(func(t: String) -> void: d["code"] = t.strip_edges())
		row.add_child(le)
	var r := _row(content)
	if mode == "practice":
		_btn("Start Match", func() -> void: Net.start_solo(), r)
		_btn("Back", _main, r, 200)
	elif mode == "host_new":
		status = _lbl("", content, 22, Color("ff9a8a"))
		_btn("Create Lobby", _create_lobby, r)
		_btn("Back", _main, r, 200)
	else:
		_btn("Done", func() -> void:
			Net.push_lobby()
			_lobby(), r)

func _create_lobby() -> void:
	var err := Net.host_game()
	if err != OK:
		status.text = "Could not start server (error %d). Is the port already in use?" % err
		return
	_lobby()

func _join() -> void:
	screen = "join"
	_clear()
	Net.start_listen()
	_title("Join Match", "Same Wi-Fi / hotspot as the host. Hosts on your network appear below.")
	var row := _row(content)
	_lbl("Host IP", row).custom_minimum_size.x = 200
	join_ip = LineEdit.new()
	join_ip.text = String(Cfg.prefs.last_ip)
	join_ip.placeholder_text = "e.g. 192.168.43.1"
	join_ip.custom_minimum_size = Vector2(400, 60)
	row.add_child(join_ip)
	var row2 := _row(content)
	_lbl("Room code", row2).custom_minimum_size.x = 200
	join_code = LineEdit.new()
	join_code.placeholder_text = "(if the host set one)"
	join_code.custom_minimum_size = Vector2(400, 60)
	row2.add_child(join_code)
	var r := _row(content)
	_btn("Join", _do_join, r, 240)
	_btn("Back", _main, r, 200)
	status = _lbl("", content, 22, Color("ffd36b"))
	_lbl("Hosts found automatically:", content, 22, Color(1, 1, 1, 0.7))
	found_box = VBoxContainer.new()
	content.add_child(found_box)
	_lbl("If nothing appears, some hotspots block broadcasts - type the host's IP instead.", content, 18, Color(1, 1, 1, 0.55))

func _do_join() -> void:
	var ip := join_ip.text.strip_edges()
	if ip == "":
		status.text = "Enter the host's IP address."
		return
	Cfg.prefs.last_ip = ip
	Cfg.save_prefs()
	Net.join_code = join_code.text.strip_edges()
	var err := Net.join_game(ip)
	if err != OK:
		status.text = "Invalid address."
		return
	status.text = "Connecting to %s ..." % ip

func _on_join_failed(reason: String) -> void:
	if screen == "join" and status != null:
		status.text = reason
		Net.start_listen()

func _on_joined() -> void:
	_lobby()

func _on_host_lost(reason: String) -> void:
	_main()
	Net.last_msg = ""
	_lbl(reason + " You were returned to the main menu.", content, 24, Color("ff9a8a"), true)

func _leave_lobby() -> void:
	Net.leave()
	_main()

func _lobby() -> void:
	screen = "lobby"
	_clear()
	var d := Net.settings
	_title("Lobby")
	if Net.is_host:
		var ips := Net.local_ips()
		_lbl("Your IP: %s   (port %d)%s" % [", ".join(PackedStringArray(ips)) if ips.size() > 0 else "unknown - is hotspot/Wi-Fi on?", Cfg.PORT, ("   Room code: " + String(d.code)) if String(d.code) != "" else ""], content, 24, Color("9fe0ff"), true)
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 8)
	content.add_child(lobby_box)
	_refresh_lobby()

func _refresh_lobby() -> void:
	if lobby_box == null:
		return
	for c in lobby_box.get_children():
		lobby_box.remove_child(c)
		c.queue_free()
	var d := Net.settings
	var mode_names := {"ffa": "Free-for-all", "team": "Team Deathmatch", "custom": "Custom teams"}
	_lbl("%s  |  %s  |  %d:%02d  |  first to %d  |  %d bots" % [Cfg.maps[int(d.map)].name, mode_names[d.mode], int(d.duration) / 60, int(d.duration) % 60, int(d.kill_limit), int(d.bots)], lobby_box, 22, Color(1, 1, 1, 0.8), true)
	_lbl("Players (%d / %d)" % [Net.players.size(), int(d.max_players)], lobby_box, 26, Color("ffd36b"))
	var team_mode := String(d.mode) != "ffa"
	var my_id := multiplayer.get_unique_id() if Net.online else 1
	for id in Net.players.keys():
		var p: Dictionary = Net.players[id]
		var row := _row(lobby_box)
		var nm := String(p.name) + ("  (host)" if id == 1 else "") + ("  (you)" if id == my_id else "")
		_lbl(nm, row).custom_minimum_size.x = 420
		if team_mode:
			var tb := Button.new()
			tb.text = "Team " + String(Cfg.TEAM_NAMES[int(p.team) % 4])
			tb.custom_minimum_size = Vector2(220, 56)
			tb.add_theme_color_override("font_color", Cfg.TEAM_COLORS[int(p.team) % 4])
			if Net.is_host:
				tb.pressed.connect(func() -> void: Net.set_team(id, int(p.team) + 1))
			elif id == my_id:
				tb.pressed.connect(func() -> void: Net.rpc_id(1, "srv_team", (int(p.team) + 1) % Net.team_count()))
			else:
				tb.disabled = true
			row.add_child(tb)
	var r := _row(lobby_box)
	if Net.is_host:
		_btn("Match Settings", func() -> void: _form("host_edit"), r, 300)
		_btn("Start Match", func() -> void: Net.start_match_host(), r, 300)
	else:
		_lbl("Waiting for the host to start...", r, 24, Color(1, 1, 1, 0.7))
	_btn("Leave", _leave_lobby, r, 200)
	if Net.is_host:
		_lbl("Bots fill remaining slots up to 12 fighters total.", lobby_box, 18, Color(1, 1, 1, 0.5))

func _on_lobby_changed() -> void:
	if screen == "lobby":
		_refresh_lobby()

func _settings() -> void:
	screen = "settings"
	_clear()
	_title("Settings")
	var d := Cfg.prefs
	var row := _row(content)
	_lbl("Player name", row).custom_minimum_size.x = 380
	var le := LineEdit.new()
	le.text = String(d.name)
	le.max_length = 14
	le.custom_minimum_size = Vector2(300, 60)
	le.text_changed.connect(func(t: String) -> void: d["name"] = t.strip_edges() if t.strip_edges() != "" else "Player")
	row.add_child(le)
	_stepper(d, "Sound volume", "volume", 0.0, 1.0, 0.1)
	_choice(d, "Touch controls", "touch", [[0, "Auto (touchscreens)"], [1, "Always on"], [2, "Off (keyboard+mouse)"]])
	_stepper(d, "Touch button size", "ui_scale", 0.6, 1.6, 0.1)
	_stepper(d, "Touch opacity", "touch_opacity", 0.2, 1.0, 0.1)
	_stepper(d, "Zoom (view width, lower = closer)", "view_w", 700, 1600, 100)
	_choice(d, "Frame rate cap", "fps", [[30, "30 FPS (battery)"], [60, "60 FPS"], [0, "Unlimited"]])
	_btn("Save & Back", func() -> void:
		Cfg.save_prefs()
		_main(), content, 300)

func _help() -> void:
	screen = "help"
	_clear()
	_title("How To Play")
	_lbl("TOUCH CONTROLS\n- Left stick: run. Push it UP to fly with the jetpack.\n- JET button: hold to hover/fly (with the left stick: up/down/forward/back).\n- JUMP: jump (double-jump in the air).\n- Right stick: aim. Push it all the way out to shoot.\n- FIRE: shoot in your last aim direction.\n- NADE: throw a grenade (works while flying).\n- SWAP: switch between your two weapons.\n- Walk over weapon crates to swap your current weapon.\n\nKEYBOARD + MOUSE (PC testing)\nA/D move, W or Shift = jetpack, S = down, Space = jump, mouse aims, left click shoots, right click / G grenade, Q/E or wheel swap weapon, Tab scoreboard, Esc pause.\n\nTips: jetpack fuel is unlimited by default and you cannot leave the arena. Toxic gas only hurts you while standing on the ground - fly over it!", content, 24)
	_btn("Back", _main, content, 200)

func _process(dt: float) -> void:
	if screen == "join" and found_box != null:
		_t -= dt
		if _t <= 0.0:
			_t = 0.5
			for c in found_box.get_children():
				found_box.remove_child(c)
				c.queue_free()
			for ip in Net.found.keys():
				var info: Dictionary = Net.found[ip]
				var txt := "%s - %s - %s - %d/%d%s   [%s]" % [info.name, info.map, info.mode, int(info.n), int(info.max), " (code)" if info.lock else "", ip]
				_btn(txt, func() -> void: join_ip.text = String(ip), found_box, 900)
