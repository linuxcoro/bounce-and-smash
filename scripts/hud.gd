extends CanvasLayer
## HUD creado por código: marcador, récord, nivel, combo, banners y pausa.

signal resume_requested

var w := 720.0
var h := 1280.0
var root: Control
var dim: ColorRect
var score_label: Label
var best_label: Label
var level_label: Label
var combo_label: Label
var banner_label: Label
var title_label: Label
var subtitle_label: Label
var prompt_label: Label
var pause_label: Label
var t := 0.0
var intro_visible := true
var last_score := -1
var last_best := -1
var last_level := -1
var last_combo := -1


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	score_label = _make_label(46, Color(0.30, 0.90, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
	best_label = _make_label(22, Color(0.55, 0.62, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	level_label = _make_label(24, Color(0.62, 0.72, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	combo_label = _make_label(36, Color(1.0, 0.72, 0.16), HORIZONTAL_ALIGNMENT_LEFT)
	banner_label = _make_label(40, Color(1.0, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	title_label = _make_label(66, Color(0.30, 0.90, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label = _make_label(26, Color(0.85, 0.90, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label = _make_label(28, Color(1.0, 0.72, 0.16), HORIZONTAL_ALIGNMENT_CENTER)
	pause_label = _make_label(34, Color(1.0, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	title_label.add_theme_constant_override("outline_size", 16)
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.95))
	title_label.add_theme_color_override("font_shadow_color", Color(0.13, 0.83, 0.93, 0.35))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	dim.visible = false
	score_label.visible = false
	best_label.visible = false
	level_label.visible = false
	combo_label.visible = false
	banner_label.visible = false
	title_label.visible = false
	subtitle_label.visible = false
	prompt_label.visible = false
	pause_label.visible = false


func _make_label(font_size: int, c: Color, align: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set("horizontal_alignment", align)
	l.set("vertical_alignment", VERTICAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.85))
	l.visible = false
	root.add_child(l)
	return l


func resize(size: Vector2) -> void:
	if root == null:
		return
	w = size.x
	h = size.y
	dim.position = Vector2.ZERO
	dim.size = size
	score_label.position = Vector2(26.0, 14.0)
	score_label.size = Vector2(w - 52.0, 62.0)
	best_label.position = Vector2(26.0, 16.0)
	best_label.size = Vector2(w - 52.0, 42.0)
	level_label.position = Vector2(0.0, 90.0)
	level_label.size = Vector2(w, 36.0)
	combo_label.position = Vector2(26.0, 70.0)
	combo_label.size = Vector2(280.0, 52.0)
	banner_label.position = Vector2(0.0, h * 0.38)
	banner_label.size = Vector2(w, 80.0)
	title_label.position = Vector2(0.0, h * 0.15)
	title_label.size = Vector2(w, 92.0)
	subtitle_label.position = Vector2(36.0, h * 0.15 + 100.0)
	subtitle_label.size = Vector2(w - 72.0, 160.0)
	prompt_label.position = Vector2(0.0, h * 0.70)
	prompt_label.size = Vector2(w, 52.0)
	pause_label.position = Vector2(0.0, h * 0.45)
	pause_label.size = Vector2(w, 64.0)


func step(delta: float) -> void:
	t += delta
	if prompt_label.visible:
		prompt_label.modulate.a = 0.62 + 0.38 * absf(sin(t * 2.6))


func set_score(value: int) -> void:
	if value == last_score:
		return
	last_score = value
	score_label.text = str(value)
	score_label.visible = not intro_visible


func set_best(value: int) -> void:
	if value == last_best:
		return
	last_best = value
	best_label.text = "RÉCORD %d" % value
	best_label.visible = not intro_visible


func set_level(value: int) -> void:
	if value == last_level:
		return
	last_level = value
	level_label.text = "NIVEL %d" % value
	level_label.visible = not intro_visible


func set_combo(value: int) -> void:
	if value == last_combo:
		return
	last_combo = value
	if value <= 1:
		combo_label.visible = false
		return
	combo_label.text = "COMBO x%d" % value
	combo_label.visible = not intro_visible


func show_intro(best_value: int) -> void:
	intro_visible = true
	dim.visible = true
	title_label.visible = true
	title_label.text = "BOUNCE & SMASH"
	subtitle_label.visible = true
	subtitle_label.text = "Arrastra hacia atrás y suelta.\nRompe los discos cayendo con fuerza.\nRÉCORD  %d" % best_value
	prompt_label.visible = true
	prompt_label.text = "ARRASTRA Y SUELTA PARA JUGAR"
	score_label.visible = false
	best_label.visible = false
	level_label.visible = false
	combo_label.visible = false
	banner_label.visible = false


func hide_intro() -> void:
	if not intro_visible:
		return
	intro_visible = false
	dim.visible = false
	title_label.visible = false
	subtitle_label.visible = false
	prompt_label.visible = false


func show_playing() -> void:
	hide_intro()
	dim.visible = false
	score_label.visible = true
	best_label.visible = true
	level_label.visible = true
	banner_label.visible = false
	if last_combo > 1:
		combo_label.visible = true


func show_level_clear(level_number: int, bonus: int) -> void:
	banner_label.visible = true
	banner_label.text = "¡NIVEL %d SUPERADO!  +%d" % [level_number, bonus]
	score_label.visible = true
	best_label.visible = true
	level_label.visible = true


func show_paused(paused: bool) -> void:
	pause_label.visible = paused
	if paused:
		pause_label.text = "EN PAUSA\nTOCA PARA SEGUIR"
		dim.visible = true
	else:
		pause_label.text = ""
		if not intro_visible:
			dim.visible = false


func _input(event: InputEvent) -> void:
	if not get_tree().paused:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		emit_signal("resume_requested")
		get_viewport().set_input_as_handled()
