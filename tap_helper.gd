extends Node
## Makes buttons and text fields work from raw touch events (no touch->mouse emulation needed),
## and scrolls the ScrollContainer by dragging. Add as a child of any menu/overlay.

var root: Node               # search for buttons under this node (Control or CanvasLayer)
var scroll: ScrollContainer  # optional: drag-scroll target
var _tp: Dictionary = {}

func _input(e: InputEvent) -> void:
	if root == null or not _root_visible():
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_tp[e.index] = [e.position, false]
		elif _tp.has(e.index):
			var t: Array = _tp[e.index]
			_tp.erase(e.index)
			if not t[1]:
				_tap(e.position)
	elif e is InputEventScreenDrag and _tp.has(e.index):
		var t: Array = _tp[e.index]
		if not t[1] and e.position.distance_to(t[0]) > 14.0:
			t[1] = true
		if t[1] and scroll != null:
			scroll.scroll_vertical -= int(e.relative.y)

func _root_visible() -> bool:
	if root is CanvasLayer:
		return (root as CanvasLayer).visible
	if root is Control:
		return (root as Control).is_visible_in_tree()
	return true

func _tap(pos: Vector2) -> void:
	var c := _find(root, pos)
	if c is BaseButton:
		if not (c as BaseButton).disabled:
			(c as BaseButton).pressed.emit()
		DisplayServer.virtual_keyboard_hide()
		get_viewport().set_input_as_handled()
	elif c is LineEdit:
		(c as LineEdit).grab_focus()
		DisplayServer.virtual_keyboard_show((c as LineEdit).text)
		get_viewport().set_input_as_handled()
	else:
		DisplayServer.virtual_keyboard_hide()

func _find(n: Node, pos: Vector2) -> Control:
	var kids := n.get_children()
	kids.reverse()
	for k in kids:
		if k is Control:
			var c: Control = k
			if not c.visible:
				continue
			if (c is BaseButton or c is LineEdit) and c.get_global_rect().has_point(pos):
				return c
		var r := _find(k, pos)
		if r != null:
			return r
	return null
