extends Control






const MD = preload("res://ui/ui24/map_declutter.gd")
const PAD: float = 4.0
const BODY: = Color(0.075, 0.065, 0.045, 0.84)
const RIM: = Color(0.55, 0.43, 0.2, 0.95)
const LIP: = Color(1.0, 0.86, 0.5, 0.12)

var hud: Node
var _cols: Array[Rect2] = []


func mount(h: Node, above: Control) -> void :
	hud = h
	name = "RailBack"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root.add_child(self)

	h.root.move_child(self, mini(above.get_index() + 1, h.root.get_child_count() - 1) if above != null and above.get_parent() == h.root else mini(2, h.root.get_child_count() - 1))


func _process(_d: float) -> void :
	if hud == null:
		return
	var cols: Array[Rect2] = []
	var keys: Array = []
	for e: Array in hud.cmd_btns:
		keys.append(e[0])
	if hud.get("ore_btn") != null:
		keys.append(hud.ore_btn)
	for k: Variant in keys:
		if not is_instance_valid(k):
			continue
		var b: Control = k as Control
		if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		var r: Rect2 = b.get_global_rect()
		var put: bool = false
		for i in cols.size():
			if absf(cols[i].position.x - r.position.x) < 8.0:
				cols[i] = cols[i].merge(r)
				put = true
				break
		if not put:
			cols.append(r)
	for i2 in cols.size():
		var g: Rect2 = cols[i2].grow(PAD)
		cols[i2] = Rect2(g.position.round(), g.size.round())
	cols.sort_custom( func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	if cols != _cols:
		_cols = cols
		MD.keep_out = cols.duplicate()
		MD.keep_ver += 1
		queue_redraw()


func _exit_tree() -> void :
	MD.keep_out = []
	MD.keep_ver += 1


func _draw() -> void :
	var o: Vector2 = get_global_rect().position
	var prev_end: float = - INF
	for r0: Rect2 in _cols:
		var r: = Rect2(r0.position - o, r0.size)
		if r.position.x < prev_end - o.x:

			var cut: float = prev_end - o.x - r.position.x
			r = Rect2(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y)
		prev_end = r0.end.x

		draw_rect(Rect2(r.position.x + 2.0, r.position.y, r.size.x - 4.0, r.size.y), BODY)
		draw_rect(Rect2(r.position.x, r.position.y + 2.0, 2.0, r.size.y - 4.0), BODY)
		draw_rect(Rect2(r.end.x - 2.0, r.position.y + 2.0, 2.0, r.size.y - 4.0), BODY)
		draw_rect(Rect2(r.position.x + 2.0, r.position.y, r.size.x - 4.0, 1.0), RIM)
		draw_rect(Rect2(r.position.x + 2.0, r.end.y - 1.0, r.size.x - 4.0, 1.0), RIM)
		draw_rect(Rect2(r.position.x, r.position.y + 2.0, 1.0, r.size.y - 4.0), RIM)
		draw_rect(Rect2(r.end.x - 1.0, r.position.y + 2.0, 1.0, r.size.y - 4.0), RIM)
		draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0, 1.0, 1.0), RIM)
		draw_rect(Rect2(r.end.x - 2.0, r.position.y + 1.0, 1.0, 1.0), RIM)
		draw_rect(Rect2(r.position.x + 1.0, r.end.y - 2.0, 1.0, 1.0), RIM)
		draw_rect(Rect2(r.end.x - 2.0, r.end.y - 2.0, 1.0, 1.0), RIM)
		draw_rect(Rect2(r.position.x + 3.0, r.position.y + 1.0, r.size.x - 6.0, 1.0), LIP)
