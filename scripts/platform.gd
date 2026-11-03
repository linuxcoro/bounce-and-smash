extends StaticBody2D
## Disco destructible de la torre.
## El collider detiene la bola; el sensor de la cara superior mide el impacto.
## El nodo nunca se libera: la torre lo reutiliza (object pooling estricto).

signal smashed(platform, impact_vy)

const WIDTH := 280.0
const THICK := 20.0
const SENSOR_WIDTH := 256.0
const SENSOR_HEIGHT := 34.0
const SENSOR_Y := -12.0
const FLASH_TIME := 0.18

var alive := false
var configured := false
var threshold := 650.0
var color := Color(0.20, 0.85, 0.95)
var flash := 0.0
var slot := 0
var level := 1
var body_shape: CollisionShape2D
var sensor: Area2D
var sensor_shape: CollisionShape2D
var slab: RectangleShape2D


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	if configured:
		return
	configured = true
	collision_layer = 2
	collision_mask = 0
	slab = RectangleShape2D.new()
	slab.size = Vector2(WIDTH, THICK)
	body_shape = CollisionShape2D.new()
	body_shape.shape = slab
	add_child(body_shape)

	sensor = Area2D.new()
	sensor.name = "Sensor"
	sensor.collision_layer = 0
	sensor.collision_mask = 1
	sensor.monitoring = true
	sensor.monitorable = false
	sensor_shape = CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(SENSOR_WIDTH, SENSOR_HEIGHT)
	sensor_shape.shape = sensor_rect
	sensor_shape.position = Vector2(0.0, SENSOR_Y)
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.body_entered.connect(_on_body_entered)


func activate(p_slot: int, p_level: int, p_threshold: float, p_color: Color) -> void:
	_ensure_nodes()
	slot = p_slot
	level = p_level
	threshold = p_threshold
	color = p_color
	alive = true
	flash = 0.0
	visible = true
	body_shape.disabled = false
	sensor.monitoring = true
	queue_redraw()


func deactivate() -> void:
	alive = false
	visible = false
	flash = 0.0
	if configured:
		body_shape.set_deferred("disabled", true)
		sensor.set_deferred("monitoring", false)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not alive or not body.has_method("is_ball"):
		return
	var impact_vy: float = body.last_velocity.y
	if impact_qualifies(impact_vy, threshold):
		_break(impact_vy)
	else:
		# Impacto lento o ascendente: rebota sin romperse.
		flash = FLASH_TIME
		queue_redraw()


static func impact_qualifies(impact_vy: float, threshold_value: float) -> bool:
	## Solo destruye si viene cayendo (vy positiva, hacia abajo) con fuerza suficiente.
	return impact_vy > 0.0 and impact_vy >= threshold_value


func _break(impact_vy: float) -> void:
	if not alive:
		return
	alive = false
	visible = false
	flash = 0.0
	if configured:
		body_shape.set_deferred("disabled", true)
		sensor.set_deferred("monitoring", false)
	emit_signal("smashed", self, impact_vy)


func _draw() -> void:
	if not configured or not alive:
		return
	var n := 44
	var pts := PackedVector2Array()
	var shadow := PackedVector2Array()
	var inner := PackedVector2Array()
	var half := Vector2(WIDTH * 0.5, WIDTH * 0.18)
	for i in n:
		var a := TAU * float(i) / float(n)
		var p := Vector2(cos(a) * half.x, sin(a) * half.y)
		pts.append(p)
		shadow.append(p + Vector2(0.0, 12.0))
		inner.append(p * 0.74)
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))
	draw_colored_polygon(pts, Color(color.r * 0.32, color.g * 0.40, color.b * 0.52, 1.0))
	draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.32))
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	draw_polyline(ring, Color(color.r, color.g, color.b, 0.95), 3.0, true)
	var gloss := PackedVector2Array()
	for i in range(n / 2 + 1):
		var a2 := TAU * float(i) / float(n)
		gloss.append(Vector2(cos(a2) * half.x * 0.92, sin(a2) * half.y * 0.92 - 3.0))
	draw_polyline(gloss, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
	if flash > 0.0:
		var k := flash / FLASH_TIME
		draw_polyline(ring, Color(1.0, 1.0, 1.0, 0.85 * k), 6.0, true)
