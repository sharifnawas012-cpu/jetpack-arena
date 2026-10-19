extends Node
## Injects raw touch events into the main menu and checks that Play Offline starts a match.
class Driver extends Node:
	var f := 0
	var menu
	func _ready() -> void:
		Engine.max_fps = 0
		menu = load("res://scenes/main.tscn").instantiate()
		get_tree().root.add_child(menu)
	func _tap(p: Vector2) -> void:
		# events are given in window pixels; the viewport maps them back with the stretch transform
		p = get_window().get_final_transform() * p
		var d := InputEventScreenTouch.new(); d.index = 0; d.pressed = true; d.position = p
		Input.parse_input_event(d)
		var u := InputEventScreenTouch.new(); u.index = 0; u.pressed = false; u.position = p
		Input.parse_input_event(u)
	func _find(n: Node, txt: String) -> Button:
		for k in n.get_children():
			if k is Button and k.text == txt:
				return k
			var r := _find(k, txt)
			if r != null:
				return r
		return null
	func _process(_dt: float) -> void:
		f += 1
		if f == 10:
			var b := _find(menu, "Play Offline")
			print("[touch] button rect=", b.get_global_rect())
			_tap(b.get_global_rect().get_center())
		if f == 60:
			print("[touch] in_match=", Net.in_match, " game=", Net.game != null)
			print("[touch] PASS" if Net.in_match else "[touch] FAIL")
			get_tree().quit()
func _ready() -> void:
	get_tree().root.add_child.call_deferred(Driver.new())
