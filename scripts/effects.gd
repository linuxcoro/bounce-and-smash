extends Node2D
## Pools de tamaño fijo para fragmentos, chispas y números flotantes.
## Todos los arrays se reservan una sola vez y el ring buffer reutiliza slots:
## durante la partida no se instancian nodos ni se reserva memoria nueva.

const MAX_FRAGMENTS := 240
const MAX_SPARKS := 180
const MAX_FLOATERS := 24
const GRAVITY := 1400.0
const FRAG_DRAG := 0.995

var frag_pos := PackedVector2Array()
var frag_vel := PackedVector2Array()
var frag_rot := PackedFloat32Array()
var frag_spin := PackedFloat32Array()
var frag_life := PackedFloat32Array()
var frag_max := PackedFloat32Array()
var frag_size := PackedFloat32Array()
var frag_col := PackedColorArray()
var frag_next := 0

var spark_pos := PackedVector2Array()
var spark_vel := PackedVector2Array()
var spark_life := PackedFloat32Array()
var spark_max := PackedFloat32Array()
var spark_size := PackedFloat32Array()
var spark_col := PackedColorArray()
var spark_next := 0

var floater_pos := PackedVector2Array()
var floater_life := PackedFloat32Array()
var floater_max := PackedFloat32Array()
var floater_points := PackedInt32Array()
var floater_col := PackedColorArray()
var floater_next := 0

var shake_time := 0.0
var shake_duration := 0.24
var shake_amount := 0.0
var shake_offset := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var configured := false


func _ready() -> void:
	configure(Vector2(720.0, 1280.0))


func configure(_size: Vector2) -> void:
	if configured:
		return
	configured = true
	rng.randomize()
	frag_pos.resize(MAX_FRAGMENTS)
	frag_vel.resize(MAX_FRAGMENTS)
	frag_rot.resize(MAX_FRAGMENTS)
	frag_spin.resize(MAX_FRAGMENTS)
	frag_life.resize(MAX_FRAGMENTS)
	frag_max.resize(MAX_FRAGMENTS)
	frag_size.resize(MAX_FRAGMENTS)
	frag_col.resize(MAX_FRAGMENTS)
	spark_pos.resize(MAX_SPARKS)
	spark_vel.resize(MAX_SPARKS)
	spark_life.resize(MAX_SPARKS)
	spark_max.resize(MAX_SPARKS)
	spark_size.resize(MAX_SPARKS)
	spark_col.resize(MAX_SPARKS)
	floater_pos.resize(MAX_FLOATERS)
	floater_life.resize(MAX_FLOATERS)
	floater_max.resize(MAX_FLOATERS)
	floater_points.resize(MAX_FLOATERS)
	floater_col.resize(MAX_FLOATERS)
	_reset_all()


func _reset_all() -> void:
	for i in MAX_FRAGMENTS:
		frag_life[i] = 0.0
	for i in MAX_SPARKS:
		spark_life[i] = 0.0
	for i in MAX_FLOATERS:
		floater_life[i] = 0.0
	frag_next = 0
	spark_next = 0
	floater_next = 0
	shake_time = 0.0
	shake_amount = 0.0
	shake_offset = Vector2.ZERO
	queue_redraw()


func reset() -> void:
	if configured:
		_reset_all()


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)
	shake_time = shake_duration


func emit_smash(pos: Vector2, color: Color, count: int = 14) -> void:
	for i in count:
		var ang := rng.randf() * TAU
		var sp := rng.randf_range(120.0, 520.0)
		var c2: Color = color.lightened(rng.randf_range(0.0, 0.35))
		frag_pos[frag_next] = pos + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-16.0, 16.0))
		frag_vel[frag_next] = Vector2(cos(ang), sin(ang)) * sp + Vector2(0.0, -120.0)
		frag_rot[frag_next] = rng.randf() * TAU
		frag_spin[frag_next] = rng.randf_range(-9.0, 9.0)
		frag_life[frag_next] = rng.randf_range(0.45, 1.05)
		frag_max[frag_next] = frag_life[frag_next]
		frag_size[frag_next] = rng.randf_range(7.0, 15.0)
		frag_col[frag_next] = c2
		frag_next = (frag_next + 1) % MAX_FRAGMENTS
	for i in 24:
		var ang2 := rng.randf() * TAU
		var sp2 := rng.randf_range(80.0, 620.0)
		spark_pos[spark_next] = pos
		spark_vel[spark_next] = Vector2(cos(ang2), sin(ang2)) * sp2
		spark_life[spark_next] = rng.randf_range(0.18, 0.55)
		spark_max[spark_next] = spark_life[spark_next]
		spark_size[spark_next] = rng.randf_range(2.0, 5.0)
		spark_col[spark_next] = Color(1.0, 1.0, 1.0, 0.9)
		spark_next = (spark_next + 1) % MAX_SPARKS
	queue_redraw()


func emit_floater(pos: Vector2, points: int, color: Color) -> void:
	floater_pos[floater_next] = pos
	floater_life[floater_next] = 0.9
	floater_max[floater_next] = 0.9
	floater_points[floater_next] = points
	floater_col[floater_next] = color.lightened(0.2)
	floater_next = (floater_next + 1) % MAX_FLOATERS


func step(delta: float) -> void:
	var t := minf(delta, 0.033)
	for i in MAX_FRAGMENTS:
		var life: float = frag_life[i]
		if life <= 0.0:
			continue
		life = maxf(0.0, life - t)
		frag_life[i] = life
		if life <= 0.0:
			continue
		var v: Vector2 = frag_vel[i]
		v.y += GRAVITY * t
		v *= FRAG_DRAG
		frag_vel[i] = v
		frag_pos[i] = frag_pos[i] + v * t
		frag_rot[i] = frag_rot[i] + frag_spin[i] * t
	for i in MAX_SPARKS:
		var life2: float = spark_life[i]
		if life2 <= 0.0:
			continue
		life2 = maxf(0.0, life2 - t)
		spark_life[i] = life2
		if life2 <= 0.0:
			continue
		var v2: Vector2 = spark_vel[i]
		v2.y += GRAVITY * 0.45 * t
		v2 *= 0.985
		spark_vel[i] = v2
		spark_pos[i] = spark_pos[i] + v2 * t
	for i in MAX_FLOATERS:
		if floater_life[i] <= 0.0:
			continue
		floater_life[i] = maxf(0.0, floater_life[i] - t)
		floater_pos[i] = floater_pos[i] + Vector2(0.0, -70.0) * t
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - t)
		var k: float = shake_time / shake_duration
		if k > 0.0:
			shake_offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_amount * k
		else:
			shake_amount = 0.0
			shake_offset = Vector2.ZERO
	queue_redraw()


func active_fragments() -> int:
	var n := 0
	for i in MAX_FRAGMENTS:
		if frag_life[i] > 0.0:
			n += 1
	return n


func _draw() -> void:
	for i in MAX_FRAGMENTS:
		var life: float = frag_life[i]
		if life <= 0.0:
			continue
		var k: float = clampf(life / maxf(0.001, frag_max[i]), 0.0, 1.0)
		var c: Color = frag_col[i]
		var s: float = frag_size[i]
		draw_set_transform(frag_pos[i], frag_rot[i], Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), Color(c.r, c.g, c.b, 0.92 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in MAX_SPARKS:
		var life2: float = spark_life[i]
		if life2 <= 0.0:
			continue
		var k2: float = clampf(life2 / maxf(0.001, spark_max[i]), 0.0, 1.0)
		var c2: Color = spark_col[i]
		draw_circle(spark_pos[i], spark_size[i] * (0.4 + 0.6 * k2), Color(c2.r, c2.g, c2.b, 0.9 * k2))
	var font := ThemeDB.fallback_font
	for i in MAX_FLOATERS:
		var life3: float = floater_life[i]
		if life3 <= 0.0:
			continue
		var k3: float = clampf(life3 / maxf(0.001, floater_max[i]), 0.0, 1.0)
		var c3: Color = floater_col[i]
		draw_string(font, floater_pos[i], "+%d" % floater_points[i], HORIZONTAL_ALIGNMENT_CENTER, -1.0, 30, Color(c3.r, c3.g, c3.b, k3))
