extends Node2D
## Fondo neón, paredes laterales y pad de lanzamiento. Todo dibujado por código.

const WALL_LAYER := 4

var screen_size := Vector2(720.0, 1280.0)
var pad_pos := Vector2(360.0, 1140.0)
var walls: Array = []
var stars: Array = []
var rng := RandomNumberGenerator.new()
var t := 0.0
var shake_offset := Vector2.ZERO
var configured := false


func configure(size: Vector2) -> void:
	screen_size = size
	pad_pos = Vector2(size.x * 0.5, size.y - 140.0)
	rng.seed = 2026
	stars.clear()
	for i in 84:
		stars.append({
			"p": Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.8),
			"r": rng.randf_range(1.0, 2.4),
			"ph": rng.randf() * TAU,
		})
	_ensure_walls()
	configured = true
	queue_redraw()


func _ensure_walls() -> void:
	if walls.is_empty():
		for i in 2:
			var body := StaticBody2D.new()
			body.name = "Wall%d" % i
			body.collision_layer = WALL_LAYER
			body.collision_mask = 0
			var mat := PhysicsMaterial.new()
			mat.bounce = 0.9
			mat.friction = 0.05
			body.physics_material_override = mat
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(40.0, 3000.0)
			cs.shape = rect
			body.add_child(cs)
			add_child(body)
			walls.append(body)
	walls[0].position = Vector2(-20.0, screen_size.y * 0.5)
	walls[1].position = Vector2(screen_size.x + 20.0, screen_size.y * 0.5)


func set_shake(offset: Vector2) -> void:
	shake_offset = offset
	queue_redraw()


func step(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if not configured:
		return
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	var top := Color(0.016, 0.020, 0.050)
	var bottom := Color(0.060, 0.045, 0.150)
	var bands := 28
	var band_h: float = screen_size.y / float(bands)
	for i in bands:
		var k: float = float(i) / float(bands)
		draw_rect(Rect2(0.0, band_h * float(i), screen_size.x, band_h + 1.0), top.lerp(bottom, k))
	for s in stars:
		var tw: float = 0.30 + 0.55 * absf(sin(t * 1.6 + float(s["ph"])))
		draw_circle(s["p"], float(s["r"]), Color(0.72, 0.90, 1.0, 0.55 * tw))
	# Halo vertical detrás de la torre.
	draw_circle(Vector2(screen_size.x * 0.5, screen_size.y * 0.42), screen_size.x * 0.62, Color(0.20, 0.30, 0.75, 0.10))
	draw_circle(Vector2(screen_size.x * 0.5, screen_size.y * 0.42), screen_size.x * 0.40, Color(0.13, 0.83, 0.93, 0.05))
	# Cuadrícula de perspectiva.
	for k in 12:
		var x: float = float(k) * screen_size.x / 11.0
		draw_line(Vector2(x, screen_size.y), Vector2(x * 0.55 + screen_size.x * 0.225, screen_size.y - 260.0), Color(0.20, 0.55, 0.75, 0.06), 2.0)
	for k in 8:
		var y: float = screen_size.y - float(k) * 34.0
		draw_line(Vector2(0.0, y), Vector2(screen_size.x, y), Color(0.20, 0.55, 0.75, 0.05), 1.0)
	# Paredes laterales.
	draw_line(Vector2(1.0, 0.0), Vector2(1.0, screen_size.y), Color(0.13, 0.83, 0.93, 0.55), 3.0)
	draw_line(Vector2(screen_size.x - 1.0, 0.0), Vector2(screen_size.x - 1.0, screen_size.y), Color(0.96, 0.45, 0.71, 0.55), 3.0)
	# Pad de lanzamiento.
	var pad := pad_pos
	draw_circle(pad + Vector2(0.0, 6.0), 62.0, Color(0.13, 0.83, 0.93, 0.08))
	draw_set_transform(pad + shake_offset, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 58.0, Color(0.04, 0.08, 0.18, 1.0))
	draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 48, Color(0.13, 0.83, 0.93, 0.75), 3.0, true)
	draw_arc(Vector2.ZERO, 44.0, 0.35, PI - 0.35, 32, Color(1.0, 0.72, 0.16, 0.45), 2.0, true)
	draw_line(Vector2(0.0, -22.0), Vector2(0.0, 14.0), Color(0.55, 0.90, 1.0, 0.7), 4.0)
	draw_line(Vector2(-12.0, -10.0), Vector2(0.0, -22.0), Color(0.55, 0.90, 1.0, 0.7), 4.0)
	draw_line(Vector2(12.0, -10.0), Vector2(0.0, -22.0), Color(0.55, 0.90, 1.0, 0.7), 4.0)
	draw_set_transform(shake_offset, 0.0, Vector2.ONE)
	# Suelo inferior.
	draw_rect(Rect2(0.0, screen_size.y - 16.0, screen_size.x, 16.0), Color(0.08, 0.10, 0.22, 1.0))
	draw_line(Vector2(0.0, screen_size.y - 16.0), Vector2(screen_size.x, screen_size.y - 16.0), Color(0.13, 0.83, 0.93, 0.45), 2.0)
