extends RefCounted
## Cálculos puros de lanzamiento y predicción de trayectoria.
## Sin nodos ni física: se puede probar headless (ver tests/smoke.gd).

const MAX_PULL := 240.0
const MIN_SPEED := 350.0
const MAX_SPEED := 2100.0
const DEAD_ZONE := 24.0
const MIN_UP := -0.15
const GRAVITY := 980.0
const PREDICT_STEPS := 90
const PREDICT_DT := 1.0 / 60.0


static func compute_launch_velocity(press: Vector2, release: Vector2) -> Vector2:
	## El jugador arrastra hacia atrás y suelta: la bola sale en sentido contrario.
	var pull := press - release
	if pull.length() < DEAD_ZONE:
		return Vector2.ZERO
	var dir := pull.normalized()
	# Nunca lanzar hacia abajo: se limita al semicírculo superior.
	if dir.y > MIN_UP:
		dir.y = MIN_UP
		dir = dir.normalized()
	var power := clampf(pull.length() / MAX_PULL, 0.0, 1.0)
	return dir * lerpf(MIN_SPEED, MAX_SPEED, power)


static func predict_arc(start: Vector2, velocity: Vector2, bounds: Rect2 = Rect2(-80.0, -80.0, 880.0, 1560.0)) -> Array:
	## Arco balístico aproximado con la misma gravedad del proyecto, sin damping.
	var points: Array = []
	var pos := start
	var vel := velocity
	for i in PREDICT_STEPS:
		vel += Vector2(0.0, GRAVITY * PREDICT_DT)
		pos += vel * PREDICT_DT
		if i % 2 == 0:
			points.append(pos)
		if not bounds.has_point(pos):
			break
	return points
