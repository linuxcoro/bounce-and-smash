extends RigidBody2D
## Bola elástica: RigidBody2D con material físico de rebote alto y CCD.
## Registra la velocidad previa al impacto para que el sensor de cada disco
## pueda decidir si el golpe rompe o solo rebota.

const RADIUS := 24.0
const MAX_SPEED := 2400.0
const TRAIL_MAX := 26
const TRAIL_STEP := 0.035
const TRAIL_LIFE := 0.5

var configured := false
var active := false
var last_velocity := Vector2.ZERO
var trail_positions: Array = []
var trail_life: Array = []
var trail_acc := 0.0
var spin := 0.0


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	if configured:
		return
	configured = true
	collision_layer = 1
	collision_mask = 2 | 4
	mass = 1.0
	gravity_scale = 1.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	freeze = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.82
	mat.friction = 0.2
	physics_material_override = mat
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	cs.shape = circle
	add_child(cs)


func is_ball() -> bool:
	return true


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Se ejecuta al inicio del paso físico: esta es la velocidad pre-impacto.
	last_velocity = state.linear_velocity
	if state.linear_velocity.length() > MAX_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)


func _process(delta: float) -> void:
	var t := minf(delta, 0.033)
	spin += linear_velocity.length() * t * 0.012
	if active:
		trail_acc += t
		if trail_acc >= TRAIL_STEP:
			trail_acc = 0.0
			trail_positions.append(position)
			trail_life.append(TRAIL_LIFE)
			if trail_positions.size() > TRAIL_MAX:
				trail_positions.pop_front()
				trail_life.pop_front()
	for i in range(trail_life.size() - 1, -1, -1):
		var life: float = trail_life[i] - t
		trail_life[i] = life
		if life <= 0.0:
			trail_positions.remove_at(i)
			trail_life.remove_at(i)
	queue_redraw()


func reset_to(pos: Vector2) -> void:
	freeze = true
	sleeping = false
	position = pos
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	var body_rid := get_rid()
	if body_rid.is_valid():
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, pos))
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
		PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	last_velocity = Vector2.ZERO
	active = false
	spin = 0.0
	trail_acc = 0.0
	trail_positions.clear()
	trail_life.clear()
	queue_redraw()


func launch(p_velocity: Vector2) -> void:
	var v := p_velocity.limit_length(MAX_SPEED)
	freeze = false
	sleeping = false
	active = true
	last_velocity = v
	apply_central_impulse(v)
	queue_redraw()


func _draw() -> void:
	for i in trail_positions.size():
		var life: float = trail_life[i]
		var k: float = clampf(life / TRAIL_LIFE, 0.0, 1.0)
		var p: Vector2 = to_local(trail_positions[i])
		draw_circle(p, RADIUS * 0.62 * k, Color(0.13, 0.83, 0.93, 0.22 * k))
	draw_circle(Vector2.ZERO, RADIUS * 1.55, Color(0.13, 0.83, 0.93, 0.10))
	draw_circle(Vector2.ZERO, RADIUS * 1.22, Color(0.13, 0.83, 0.93, 0.16))
	draw_circle(Vector2.ZERO, RADIUS, Color(0.13, 0.83, 0.93))
	draw_circle(Vector2(-6.0, -7.0), RADIUS * 0.44, Color(0.78, 0.97, 1.0, 0.9))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 36, Color(0.78, 0.97, 1.0, 0.45), 2.0, true)
	var mark := Vector2(cos(spin), sin(spin)) * RADIUS * 0.55
	draw_circle(mark, 4.0, Color(1.0, 1.0, 1.0, 0.65))
