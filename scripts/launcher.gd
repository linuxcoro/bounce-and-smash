extends Node2D
## Control de arrastre (drag & release): dibuja la goma, la potencia y la
## trayectoria prevista, y emite el impulso al soltar.

signal launched(velocity: Vector2)

const Trajectory := preload("res://scripts/trajectory.gd")

var game = null
var ball = null
var aiming := false
var press_pos := Vector2.ZERO
var current_pos := Vector2.ZERO
var screen_size := Vector2(720.0, 1280.0)


func configure(p_game, p_ball, size: Vector2) -> void:
	game = p_game
	ball = p_ball
	screen_size = size
	z_index = 8


func cancel_aim() -> void:
	aiming = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.can_aim():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			aiming = true
			press_pos = touch.position
			current_pos = touch.position
			queue_redraw()
		elif aiming:
			var release_pos := touch.position
			aiming = false
			var vel: Vector2 = Trajectory.compute_launch_velocity(press_pos, release_pos)
			queue_redraw()
			if vel != Vector2.ZERO:
				emit_signal("launched", vel)
	elif event is InputEventScreenDrag:
		if aiming:
			current_pos = (event as InputEventScreenDrag).position
			queue_redraw()


func _draw() -> void:
	if not aiming or ball == null:
		return
	var vel: Vector2 = Trajectory.compute_launch_velocity(press_pos, current_pos)
	if vel == Vector2.ZERO:
		return
	var origin: Vector2 = ball.position
	var power := clampf((press_pos - current_pos).length() / Trajectory.MAX_PULL, 0.0, 1.0)
	var dir := vel.normalized()
	var band_len := 34.0 + 58.0 * power
	# Goma del tirachinas en la dirección real del disparo.
	draw_line(origin, origin + dir * band_len, Color(0.96, 0.45, 0.71, 0.55), 6.0, true)
	draw_line(origin, origin + dir * band_len, Color(1.0, 0.85, 0.95, 0.30), 2.0, true)
	# Punta de flecha.
	var tip := origin + dir * band_len
	var left := tip - dir.rotated(0.5) * 18.0
	var right := tip - dir.rotated(-0.5) * 18.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 0.72, 0.16, 0.9))
	# Trayectoria prevista: línea guía + puntos que se desvanecen.
	var pts: Array = Trajectory.predict_arc(origin, vel)
	var n := pts.size()
	if n >= 2:
		var packed := PackedVector2Array()
		for point in pts:
			packed.append(point)
		draw_polyline(packed, Color(0.30, 0.90, 0.98, 0.32), 2.5, true)
	for i in n:
		var k := float(i) / float(maxi(1, n - 1))
		var alpha := 0.9 * (1.0 - k)
		draw_circle(pts[i], 7.0 - 4.0 * k, Color(0.30, 0.90, 0.98, alpha))
	if n > 0:
		draw_arc(pts[n - 1], 10.0, 0.0, TAU, 16, Color(1.0, 0.72, 0.16, 0.7), 2.0, true)
	# Medidor de potencia.
	var meter_pos := Vector2(28.0, screen_size.y - 54.0)
	draw_rect(Rect2(meter_pos, Vector2(200.0, 16.0)), Color(0.05, 0.08, 0.18, 0.9))
	var meter_col := Color(0.30, 0.90, 0.98).lerp(Color(0.99, 0.45, 0.35), power)
	draw_rect(Rect2(meter_pos + Vector2(2.0, 2.0), Vector2(196.0 * power, 12.0)), meter_col)
	draw_rect(Rect2(meter_pos, Vector2(200.0, 16.0)), Color(0.55, 0.75, 0.95, 0.35), false, 2.0)
