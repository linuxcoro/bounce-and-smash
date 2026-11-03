extends Node2D
## Bounce & Smash — orquestador: estados, puntaje, niveles, guardado y pausa.
## La escena Main.tscn solo aporta este nodo; todo lo demás se construye por código.

const ArenaScript := preload("res://scripts/arena.gd")
const TowerScript := preload("res://scripts/tower.gd")
const BallScript := preload("res://scripts/ball.gd")
const EffectsScript := preload("res://scripts/effects.gd")
const LauncherScript := preload("res://scripts/launcher.gd")
const HudScript := preload("res://scripts/hud.gd")

const SAVE_PATH := "user://bounce_smash_save.json"
const FLIGHT_TIMEOUT := 15.0
const SETTLE_SPEED := 50.0
const SETTLE_TIME := 0.7
const RESET_DELAY := 0.35
const LEVEL_CLEAR_TIME := 1.1
const BASE_SMASH_POINTS := 10
const LEVEL_BONUS := 100

enum State { READY, FLYING, LEVEL_CLEAR, RESETTING }

var state: int = State.READY
var screen_size := Vector2(720.0, 1280.0)
var pad_pos := Vector2(360.0, 1140.0)
var score := 0
var best := 0
var level := 1
var max_level := 1
var combo := 1
var flight_time := 0.0
var rest_time := 0.0
var reset_timer := 0.0
var level_timer := 0.0
var started := false

var arena = null
var tower = null
var ball = null
var effects = null
var launcher = null
var hud = null


func _ready() -> void:
	_load_save()
	_build_nodes()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_layout()
	tower.build_level(level)
	ball.reset_to(pad_pos)
	state = State.READY
	started = false
	hud.set_score(score)
	hud.set_best(best)
	hud.set_level(level)
	hud.set_combo(combo)
	hud.show_intro(best)


func _build_nodes() -> void:
	arena = ArenaScript.new()
	arena.name = "Arena"
	arena.z_index = -10
	add_child(arena)

	tower = TowerScript.new()
	tower.name = "Tower"
	add_child(tower)

	ball = BallScript.new()
	ball.name = "Ball"
	ball.z_index = 5
	add_child(ball)

	effects = EffectsScript.new()
	effects.name = "Effects"
	effects.z_index = 6
	add_child(effects)

	launcher = LauncherScript.new()
	launcher.name = "Launcher"
	add_child(launcher)

	hud = HudScript.new()
	hud.name = "Hud"
	add_child(hud)

	tower.smashed.connect(_on_platform_smashed)
	tower.cleared.connect(_on_tower_cleared)
	launcher.launched.connect(_on_launched)
	hud.resume_requested.connect(_resume)


func _apply_layout() -> void:
	screen_size = get_viewport_rect().size
	if screen_size.x < 1.0 or screen_size.y < 1.0:
		screen_size = Vector2(720.0, 1280.0)
	pad_pos = Vector2(screen_size.x * 0.14, screen_size.y - 130.0)
	arena.configure(screen_size)
	arena.pad_pos = pad_pos
	arena.queue_redraw()
	effects.configure(screen_size)
	tower.configure(screen_size)
	ball.reset_to(pad_pos)
	launcher.configure(self, ball, screen_size)
	hud.resize(screen_size)


func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	var new_size := get_viewport_rect().size
	if absf(new_size.x - screen_size.x) < 1.0 and absf(new_size.y - screen_size.y) < 1.0:
		return
	_apply_layout()
	tower.build_level(level)
	ball.reset_to(pad_pos)
	state = State.READY
	combo = 1
	flight_time = 0.0
	rest_time = 0.0
	hud.set_combo(combo)
	if started:
		hud.show_playing()


func can_aim() -> bool:
	return state == State.READY and not get_tree().paused


func force_launch(velocity: Vector2) -> void:
	if state != State.READY:
		return
	_on_launched(velocity)


func _on_launched(velocity: Vector2) -> void:
	if state != State.READY:
		return
	started = true
	ball.launch(velocity)
	state = State.FLYING
	combo = 1
	flight_time = 0.0
	rest_time = 0.0
	hud.set_combo(1)
	hud.hide_intro()
	hud.show_playing()


func _physics_process(delta: float) -> void:
	var t := minf(delta, 0.033)
	match state:
		State.FLYING:
			flight_time += t
			if ball.position.y > screen_size.y + 120.0:
				_reset_ball()
			elif flight_time > FLIGHT_TIMEOUT:
				_reset_ball()
			elif ball.linear_velocity.length() < SETTLE_SPEED:
				rest_time += t
				if rest_time > SETTLE_TIME:
					_reset_ball()
			else:
				rest_time = 0.0
		State.RESETTING:
			reset_timer -= t
			if reset_timer <= 0.0:
				state = State.READY
		State.LEVEL_CLEAR:
			level_timer -= t
			if level_timer <= 0.0:
				_start_next_level()
	arena.step(t)
	effects.step(t)
	hud.step(t)
	arena.set_shake(effects.shake_offset * 0.5)
	effects.position = effects.shake_offset


func _reset_ball() -> void:
	if state == State.RESETTING or state == State.READY:
		return
	ball.reset_to(pad_pos)
	combo = 1
	flight_time = 0.0
	rest_time = 0.0
	state = State.RESETTING
	reset_timer = RESET_DELAY
	hud.set_combo(1)


func _on_platform_smashed(p, _impact_vy: float) -> void:
	var points := BASE_SMASH_POINTS * combo
	score += points
	combo = mini(combo + 1, 99)
	best = maxi(best, score)
	effects.emit_smash(p.position, p.color, 14)
	effects.emit_floater(p.position + Vector2(0.0, -36.0), points, p.color)
	effects.shake(6.0 + 2.0 * float(mini(combo, 6)))
	hud.set_score(score)
	hud.set_best(best)
	hud.set_combo(combo)


func _on_tower_cleared() -> void:
	if state == State.LEVEL_CLEAR:
		return
	var bonus := LEVEL_BONUS * level
	score += bonus
	best = maxi(best, score)
	max_level = maxi(max_level, level + 1)
	state = State.LEVEL_CLEAR
	level_timer = LEVEL_CLEAR_TIME
	flight_time = 0.0
	rest_time = 0.0
	hud.set_score(score)
	hud.set_best(best)
	hud.show_level_clear(level, bonus)
	call_deferred("_save")


func _start_next_level() -> void:
	level += 1
	tower.build_level(level)
	ball.reset_to(pad_pos)
	combo = 1
	state = State.READY
	flight_time = 0.0
	rest_time = 0.0
	reset_timer = 0.0
	hud.set_level(level)
	hud.set_combo(combo)
	hud.show_playing()
	call_deferred("_save")


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1,
		"best_score": best,
		"max_level": max_level,
	}))
	f.close()


func _load_save() -> void:
	best = 0
	max_level = 1
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var b = data.get("best_score", 0)
	var m = data.get("max_level", 1)
	if typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT:
		best = maxi(0, int(b))
	if typeof(m) == TYPE_INT or typeof(m) == TYPE_FLOAT:
		max_level = maxi(1, int(m))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pause_on_focus_lost()


func _pause_on_focus_lost() -> void:
	if hud == null or launcher == null or not is_inside_tree():
		return
	if get_tree().paused:
		return
	if state == State.READY and not launcher.aiming:
		return
	launcher.cancel_aim()
	get_tree().paused = true
	hud.show_paused(true)
	_save()


func _resume() -> void:
	get_tree().paused = false
	hud.show_paused(false)
