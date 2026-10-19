extends Node
## Two-process loopback test. Run host and client in parallel:
##   godot --headless --path . res://tests/net_test.tscn -- host
##   godot --headless --path . res://tests/net_test.tscn -- client

class Driver extends Node:
	var role := ""
	var t := 0.0
	var started := false
	var first := {}
	func _ready() -> void:
		Engine.max_fps = 0
		role = OS.get_cmdline_user_args()[0]
		if role == "host":
			Net.settings = Cfg.default_settings()
			Net.settings.bots = 2
			Net.settings.map = 0
			print("[host] listen err=", Net.host_game())
		else:
			Net.join_code = ""
			print("[client] join err=", Net.join_game("127.0.0.1"))
	func _process(dt: float) -> void:
		t += dt
		if role == "host" and not started and Net.players.size() >= 2:
			print("[host] players=", Net.players.size(), " starting")
			started = true
			t = 0.0
			Net.start_match_host()
		if role == "client" and Net.in_match and Net.game != null:
			if not started:
				started = true
				t = 0.0
			var g = Net.game
			if t > 1.0 and first.is_empty():
				for f in g.fighters.values():
					first[f.id] = f.tpos
			if t > 8.0:
				var moved := 0
				var alive := 0
				for f in g.fighters.values():
					if f.alive:
						alive += 1
					if first.has(f.id) and first[f.id].distance_to(f.tpos) > 1.0:
						moved += 1
				print("[client] fighters=%d alive=%d moved=%d bullets_seen=%d time_left=%.0f" % [g.fighters.size(), alive, moved, g.view_bullets.size() / 5, g.time_left])
				print("[client] PASS" if (alive > 0 and moved > 0) else "[client] FAIL")
				get_tree().quit()
		if role == "host" and started and t > 10.0:
			var g = Net.game
			print("[host] fighters=%d kills=%d" % [g.fighters.size(), g.fighters.values().map(func(f): return f.kills).reduce(func(a, b): return a + b)])
			get_tree().quit()
		if t > 25.0 and not started:
			print("[%s] TIMEOUT waiting" % role)
			get_tree().quit(1)

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Driver.new())
