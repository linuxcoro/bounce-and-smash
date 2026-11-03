extends SceneTree
## Smoke test headless de Bounce & Smash (lógica + integración básica).
## Se ejecuta en CI:  godot --headless --path . --script res://tests/smoke.gd

const Trajectory := preload("res://scripts/trajectory.gd")
const Platform := preload("res://scripts/platform.gd")
const SAVE_PATH := "user://bounce_smash_save.json"

var fails := 0


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   - ", label)
	else:
		fails += 1
		print("  FAIL - ", label)


func _run() -> void:
	print("BOUNCE & SMASH · smoke test")
	_test_trajectory()
	_test_platform()
	await process_frame
	await _test_game()
	_finish()


func _test_trajectory() -> void:
	var dead := Trajectory.compute_launch_velocity(Vector2(300.0, 900.0), Vector2(300.0, 912.0))
	_check(dead == Vector2.ZERO, "zona muerta: un toque corto no lanza")

	var full := Trajectory.compute_launch_velocity(Vector2(360.0, 500.0), Vector2(360.0, 1200.0))
	_check(full.length() <= Trajectory.MAX_SPEED + 1.0, "la tracción máxima no supera MAX_SPEED")
	_check(full.y < 0.0, "arrastrar hacia abajo lanza hacia arriba")

	var sideways := Trajectory.compute_launch_velocity(Vector2(500.0, 1000.0), Vector2(300.0, 800.0))
	_check(sideways.y < 0.0, "la dirección se limita al semicírculo superior")

	var arc: Array = Trajectory.predict_arc(Vector2(360.0, 1140.0), Vector2(420.0, -1500.0))
	_check(not arc.is_empty(), "la predicción devuelve puntos")
	_check(arc[0].y < 1140.0, "la predicción empieza subiendo")
	_check(arc.size() <= Trajectory.PREDICT_STEPS, "la predicción está acotada a 90 puntos")


func _test_platform() -> void:
	_check(Platform.impact_qualifies(1000.0, 700.0), "impacto rápido rompe el disco")
	_check(not Platform.impact_qualifies(500.0, 700.0), "impacto lento no rompe el disco")
	_check(not Platform.impact_qualifies(-1000.0, 700.0), "impacto ascendente no rompe el disco")


func _test_game() -> void:
	var packed = load("res://scenes/Main.tscn")
	_check(packed != null, "carga Main.tscn")
	if packed == null:
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	_check(game.state == 0, "arranca en READY")
	_check(game.ball != null and game.hud != null, "nodos del juego creados")
	_check(game.tower.platforms.size() == 12, "pool fijo de 12 plataformas")
	_check(game.tower.alive_count == 6, "el nivel 1 arranca con 6 discos")
	_check(game.effects.frag_life.size() == 240, "pool de fragmentos reservado")
	_check(game.effects.spark_life.size() == 180, "pool de chispas reservado")

	var score0: int = game.score
	game._on_platform_smashed(game.tower.platforms[0], 1000.0)
	_check(game.score == score0 + 10, "el primer disco suma 10")
	game._on_platform_smashed(game.tower.platforms[1], 1000.0)
	_check(game.score == score0 + 30, "el segundo disco suma 20 por combo")
	game.state = 1
	game._reset_ball()
	_check(game.combo == 1, "el reset del vuelo reinicia el combo")
	_check(game.state == 3, "el reset pasa a RESETTING")

	var frag_size: int = game.effects.frag_life.size()
	for i in 300:
		game.effects.emit_smash(Vector2(360.0, 600.0), Color(0.2, 0.8, 1.0), 14)
	_check(game.effects.frag_life.size() == frag_size, "los pools no crecen con 300 estallidos")
	_check(game.effects.active_fragments() <= 240, "los fragmentos activos no superan el tope")

	var ids: Array = []
	for p in game.tower.platforms:
		ids.append(p.get_instance_id())
	game.tower.build_level(2)
	var same := true
	for i in game.tower.platforms.size():
		if game.tower.platforms[i].get_instance_id() != ids[i]:
			same = false
	_check(same, "la torre reutiliza las mismas instancias")
	_check(game.tower.alive_count == 7, "el nivel 2 tiene 7 discos")
	_check(is_equal_approx(game.tower.threshold, 720.0), "el umbral sube con el nivel")

	game.level = 1
	game.tower.build_level(1)
	game.state = 0
	game._start_next_level()
	_check(game.level == 2, "start_next_level sube el nivel")
	_check(game.state == 0, "tras el nivel se vuelve a READY")

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	game.best = 1234
	game.max_level = 7
	game._save()
	game.best = 0
	game.max_level = 1
	game._load_save()
	_check(game.best == 1234 and game.max_level == 7, "el guardado persiste récord y nivel")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	game.state = 0
	game.tower.build_level(1)
	game.ball.reset_to(game.pad_pos)
	game._on_launched(Vector2(0.0, -1800.0))
	_check(game.state == 1, "el lanzamiento pasa a FLYING")
	await physics_frame
	await physics_frame
	_check(game.ball.position.y < game.pad_pos.y - 10.0, "la bola sube tras el lanzamiento")
	for i in 60:
		await physics_frame
	_check(game.ball != null, "la física sigue sana tras 60 pasos")

	# Limpiar la torre completa: bonus, banner y transición de nivel.
	game.level = 1
	game.tower.build_level(1)
	game.state = 0
	var score_clear: int = game.score
	var discs: Array = game.tower.alive_platforms()
	for p in discs:
		p._break(1000.0)
	_check(game.state == 2, "limpiar la torre pasa a LEVEL_CLEAR")
	_check(game.score >= score_clear + 100, "el nivel superado da bonus")
	await physics_frame
	game.level_timer = 0.0
	game._physics_process(0.016)
	_check(game.level == 2, "la transición avanza al nivel 2")
	_check(game.state == 0, "la transición deja el juego en READY")

	# Impacto real contra el sensor del disco superior: lento rebota, rápido rompe.
	game.level = 1
	game.tower.build_level(1)
	game.state = 0
	game.rest_time = 0.0
	var top = game.tower.platforms[game.tower.disc_count - 1]
	game.ball.reset_to(top.position + Vector2(0.0, -150.0))
	await physics_frame
	game.ball.launch(Vector2(0.0, 220.0))
	for i in 40:
		await physics_frame
	_check(top.alive, "una caída lenta rebota sin romper el disco")

	var score_before: int = game.score
	game.state = 0
	game.rest_time = 0.0
	game.ball.reset_to(top.position + Vector2(0.0, -150.0))
	await physics_frame
	game.ball.launch(Vector2(0.0, 1500.0))
	for i in 40:
		await physics_frame
	_check(not top.alive, "una caída rápida destruye el disco")
	_check(game.score > score_before, "la destrucción del disco suma puntos")
	game.ball.reset_to(game.pad_pos)


func _finish() -> void:
	if fails == 0:
		print("SMOKE OK")
		quit(0)
	else:
		print("SMOKE FAIL (", fails, " fallas)")
		quit(1)
