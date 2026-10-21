extends Control
## In-game HUD: health, weapon, timer, scores, kill feed, off-screen player indicators, scoreboard.

var game

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var sz := get_viewport_rect().size
	var m := 36.0
	var me: Fighter = game.fighters.get(game.local_id)
	var t := int(maxf(game.time_left, 0.0))
	draw_string(font, Vector2(sz.x * 0.5 - 60, m + 6), "%d:%02d" % [t / 60, t % 60], HORIZONTAL_ALIGNMENT_CENTER, 120, 32, Color.WHITE)
	var limit := int(game.S.cap_limit) if game.mode == "ctf" else int(game.S.kill_limit)
	if game.mode == "survival":
		draw_string(font, Vector2(sz.x * 0.5 - 100, m + 40), "WAVE %d   Kills %d" % [int(game.team_scores[10]), me.kills if me != null else 0], HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(1, 0.85, 0.4))
	elif game.team_mode:
		var tc: int = 2 if (game.mode == "team" or game.mode == "ctf") else clampi(int(game.S.teams), 2, 4)
		var x0 := sz.x * 0.5 - tc * 45.0
		for i in tc:
			draw_rect(Rect2(x0 + i * 90.0, m + 14, 84, 30), Color(Cfg.TEAM_COLORS[i], 0.85))
			draw_string(font, Vector2(x0 + i * 90.0, m + 36), "%d / %d" % [game.team_scores[i], limit], HORIZONTAL_ALIGNMENT_CENTER, 84, 20, Color.WHITE)
	elif me != null:
		draw_string(font, Vector2(sz.x * 0.5 - 90, m + 38), "Kills %d / %d" % [me.kills, limit], HORIZONTAL_ALIGNMENT_CENTER, 180, 20, Color(1, 1, 1, 0.9))
	if me != null:
		draw_rect(Rect2(m, m, 260, 22), Color(0, 0, 0, 0.55))
		var hf := clampf(me.hp / maxf(1.0, float(game.S.health)), 0.0, 1.0)
		draw_rect(Rect2(m + 2, m + 2, 256.0 * hf, 18), Color(1.0 - hf, 0.3 + 0.6 * hf, 0.2))
		draw_string(font, Vector2(m + 6, m + 19), "HP %d" % int(me.hp), HORIZONTAL_ALIGNMENT_LEFT, 240, 16, Color.WHITE)
		var ff := 1.0 if bool(game.S.unl_jet) else clampf(me.fuel / 100.0, 0.0, 1.0)
		draw_rect(Rect2(m, m + 26, 260, 16), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(m + 2, m + 28, 256.0 * ff, 12), Color(0.3, 0.65, 1.0))
		draw_string(font, Vector2(m + 6, m + 40), "JET", HORIZONTAL_ALIGNMENT_LEFT, 100, 13, Color.WHITE)
		for cf in game.ctf_flags:
			if int(cf.carrier) == game.local_id:
				draw_string(font, Vector2(sz.x * 0.5 - 220, sz.y * 0.22), "YOU HAVE THE FLAG - bring it to your base!", HORIZONTAL_ALIGNMENT_CENTER, 440, 24, Color(1, 0.9, 0.4))
		var w: Dictionary = Cfg.weapons[me.cur_weapon]
		var ammo_txt := ""
		if game.is_host and not bool(game.S.no_reload):
			var res := int(me.reserve[me.slot])
			ammo_txt = "  %d/%s" % [me.ammo[me.slot], "inf" if res < 0 else str(res)]
			if me.reload_t > 0.0:
				ammo_txt = "  reloading..."
		draw_string(font, Vector2(m, m + 70), String(w.name) + ammo_txt, HORIZONTAL_ALIGNMENT_LEFT, 360, 20, Color(1, 1, 0.8))
		var nd := "inf" if bool(game.S.unl_nades) else str(me.nades)
		var gn: String = ["Frag", "Sticky", "Smoke", "Gas"][me.gtype]
		draw_string(font, Vector2(m, m + 92), "Grenades %s [%s]   K %d  D %d" % [nd, gn, me.kills, me.deaths], HORIZONTAL_ALIGNMENT_LEFT, 360, 18, Color(1, 1, 1, 0.85))
		var st := ""
		if me.speed_t > 0.0: st += "SPEED  "
		if me.shield_t > 0.0: st += "SHIELD  "
		if me.dmg_t > 0.0: st += "DAMAGE x2"
		if st != "":
			draw_string(font, Vector2(m, m + 116), st, HORIZONTAL_ALIGNMENT_LEFT, 360, 18, Color(0.6, 1, 0.8))
		if not me.alive and not game.ended:
			draw_string(font, Vector2(sz.x * 0.5 - 150, sz.y * 0.4), ("Down! Wait for the next wave..." if me.respawn_t > 1e8 else "Respawning in %d..." % int(ceil(maxf(me.respawn_t, 0.0)))) if game.is_host else "Respawning...", HORIZONTAL_ALIGNMENT_CENTER, 300, 30, Color(1, 0.8, 0.6))
	var y := 110.0
	for e in game.feed:
		var a := clampf(float(e[2]), 0.0, 1.0)
		draw_string(font, Vector2(sz.x - 520 - m, y), String(e[0]), HORIZONTAL_ALIGNMENT_RIGHT, 520, 18, Color(e[1], a))
		y += 22.0
	# off-screen indicators
	var ct: Transform2D = game.get_canvas_transform()
	for f: Fighter in game.fighters.values():
		if f.id == game.local_id or not f.alive:
			continue
		var sp: Vector2 = ct * f.pos
		if sp.x > 20.0 and sp.y > 20.0 and sp.x < sz.x - 20.0 and sp.y < sz.y - 20.0:
			continue
		var c := sz * 0.5
		var dir := (sp - c).normalized()
		var edge := Vector2(clampf(sp.x, 40.0, sz.x - 40.0), clampf(sp.y, 40.0, sz.y - 40.0))
		var pts := PackedVector2Array([edge + dir * 14.0, edge + dir.rotated(2.5) * 10.0, edge + dir.rotated(-2.5) * 10.0])
		draw_colored_polygon(pts, Color(f.color, 0.85))
	if game.show_board:
		draw_rect(Rect2(sz.x * 0.25, sz.y * 0.15, sz.x * 0.5, sz.y * 0.7), Color(0, 0, 0, 0.75))
		var yy := sz.y * 0.15 + 34.0
		for id in game.order:
			var f: Fighter = game.fighters[id]
			draw_string(font, Vector2(sz.x * 0.25 + 20, yy), "%s   K %d  D %d" % [f.pname, f.kills, f.deaths], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, f.color)
			yy += 28.0
