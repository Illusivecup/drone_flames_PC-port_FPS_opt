extends RefCounted











static var reports: Array = []
static var _busy: bool = false


static func watch(stack: Control, root: Control) -> void :
	if stack == null or root == null:
		return
	var cb: Callable = check.bind(stack, root)
	if not stack.minimum_size_changed.is_connected(cb):
		stack.minimum_size_changed.connect(cb)
	if not root.resized.is_connected(cb):
		root.resized.connect(cb)



static func check(stack: Control, root: Control) -> bool:
	if _busy or not is_instance_valid(stack) or not is_instance_valid(root) or not stack.is_visible_in_tree():
		return true
	var vw: float = root.size.x
	if vw < 100.0:
		return true
	var mw: float = stack.get_combined_minimum_size().x
	if mw <= vw + 0.5:
		return true
	_busy = true
	for i in 8:
		mw = stack.get_combined_minimum_size().x
		if mw <= vw + 0.5:
			break
		var leaf: Control = _culprit(stack, vw)
		var path: String = str(root.get_path_to(leaf)) if leaf != null else str(stack.name)
		var lw: float = leaf.get_combined_minimum_size().x if leaf != null else mw
		reports.append({"path": path, "min_w": lw, "vp_w": vw})
		push_warning("UI width guard: stack %.0f px > screen %.0f px; culprit %s (min %.0f px) - clipped" % [mw, vw, path, lw])
		if leaf == null or not _heal(leaf, mw - vw):
			break
	_busy = false
	return stack.get_combined_minimum_size().x <= vw + 0.5




static func _culprit(n: Control, vw: float) -> Control:
	var best: Control = null
	var bw: float = 0.0
	for ch: Node in n.get_children():
		if not (ch is Control) or not (ch as Control).visible or (ch as Control).top_level:
			continue
		var w: float = (ch as Control).get_combined_minimum_size().x
		if w > bw:
			bw = w
			best = ch as Control
	if best == null or n is ScrollContainer and (n as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return n
	if n is HBoxContainer and bw < vw * 0.6:
		return n
	if not (n is Container):
		return n
	return _culprit(best, vw)



static func _heal(n: Control, need: float) -> bool:
	if n is Label:
		var l: Label = n as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.clip_text:
			return false
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return true
	if n is Button and (n as Button).text != "" and not (n as Button).clip_text:
		(n as Button).clip_text = true
		(n as Button).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		return true

	var kids: Array = []
	for ch: Node in n.get_children():
		if ch is Control and (ch as Control).visible and not (ch as Control).top_level:
			kids.append(ch)
	kids.sort_custom( func(a: Control, b: Control) -> bool: return a.get_combined_minimum_size().x > b.get_combined_minimum_size().x)
	var done: bool = false
	for ch: Control in kids:
		var w0: float = ch.get_combined_minimum_size().x
		if _heal(ch, need):
			done = true
			need -= w0 - ch.get_combined_minimum_size().x
			if need <= 0.0:
				break
	return done





static func fit_btn(b: Button, sizes: Array) -> void :
	var apply: = func() -> void :
		if not is_instance_valid(b) or b.size.x <= 2.0:
			return
		var shown: String = b.atr(b.text) if b.can_auto_translate() else b.text
		var f: Font = b.get_theme_font("font")
		var pad: float = 0.0
		var sb: StyleBox = b.get_theme_stylebox("normal")
		if sb != null:
			pad = sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT)
		if b.icon != null:
			pad += minf(float(b.icon.get_width()), b.size.y) + float(b.get_theme_constant("h_separation"))
		var pick: int = int(sizes[sizes.size() - 1])
		var one: bool = false
		for s: Variant in sizes:
			if f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x + pad <= b.size.x:
				pick = int(s)
				one = true
				break
		if b.get_theme_font_size("font_size") != pick:
			b.add_theme_font_size_override("font_size", pick)
		if not one and b.clip_text:
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.resized.connect(apply)
	b.set_meta("fit", apply)
