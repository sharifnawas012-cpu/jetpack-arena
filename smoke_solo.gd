extends Node
## Headless smoke test: solo match with bots on every map.
## Usage: godot --headless --path . res://tests/smoke_solo.tscn

class Driver extends Node:
	var frames := 0
	var map_i := 0
	const FRAMES_PER_MAP := 600
	func _ready() -> void:
		Engine.max_fps = 0
		_start_map()
	func _start_map() -> void:
		Net.settings = Cfg.default_settings()
		Net.settings.map = map_i
		Net.settings.bots = 6
		Net.settings.bot_diff = 2
		Net.settings.mode = "team" if map_i % 2 == 1 else "ffa"
		Net.settings.duration = 600
		Net.start_solo()
		frames = 0
	func _process(_dt: float) -> void:
		frames += 1
		if frames == FRAMES_PER_MAP:
			var g = Net.game
			if g == null:
				print("[smoke] FAIL: no game node on map %d" % map_i)
				get_tree().quit(1)
				return
			var kills := 0
			var alive := 0
			for f in g.fighters.values():
				kills += f.kills
				if f.alive:
					alive += 1
			print("[smoke] map %d (%s): fighters=%d alive=%d kills=%d" % [map_i, Cfg.maps[map_i].name, g.fighters.size(), alive, kills])
			map_i += 1
			if map_i >= Cfg.maps.size():
				print("[smoke] PASS")
				get_tree().quit(0)
				return
			_start_map()

func _ready() -> void:
	print("[smoke] weapons=%d maps=%d" % [Cfg.weapons.size(), Cfg.maps.size()])
	get_tree().root.add_child.call_deferred(Driver.new())
