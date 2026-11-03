extends Node2D
## Torre en hélice de discos destructibles.
## Mantiene un pool fijo de plataformas: al cambiar de nivel se reutilizan
## las mismas instancias (mismos IDs), nunca se crean ni se liberan nodos.

signal smashed(platform, impact_vy)
signal cleared

const PlatformScript := preload("res://scripts/platform.gd")

const MAX_PLATFORMS := 12
const BASE_DISCS := 6
const MAX_DISCS := 8
const TOP_MARGIN := 190.0
const BASE_OFFSET := 340.0
const HELIX_RADIUS := 150.0
const THRESHOLD_BASE := 650.0
const THRESHOLD_STEP := 70.0
const THRESHOLD_MAX := 1300.0
const PALETTE := [
	Color(0.13, 0.83, 0.93),
	Color(0.65, 0.55, 0.98),
	Color(0.96, 0.45, 0.71),
	Color(0.99, 0.72, 0.24),
	Color(0.36, 0.92, 0.65),
]

var platforms: Array = []
var level := 1
var alive_count := 0
var threshold := THRESHOLD_BASE
var disc_count := 0
var screen_size := Vector2(720.0, 1280.0)
var spacing := 107.0
var center_x := 360.0
var base_y := 1080.0
var configured := false


func _ready() -> void:
	_build_pool()


func configure(size: Vector2) -> void:
	screen_size = size
	center_x = size.x * 0.58
	base_y = size.y - BASE_OFFSET
	spacing = clampf((base_y - TOP_MARGIN) / float(MAX_DISCS - 1), 88.0, 112.0)
	configured = true
	queue_redraw()


func _build_pool() -> void:
	if not platforms.is_empty():
		return
	for i in MAX_PLATFORMS:
		var p = PlatformScript.new()
		p.name = "Disc%d" % i
		p.z_index = 2
		add_child(p)
		p.smashed.connect(_on_platform_smashed)
		platforms.append(p)


func build_level(p_level: int) -> void:
	level = p_level
	disc_count = mini(BASE_DISCS + p_level - 1, MAX_DISCS)
	threshold = minf(THRESHOLD_BASE + THRESHOLD_STEP * float(p_level - 1), THRESHOLD_MAX)
	alive_count = 0
	for i in platforms.size():
		var p = platforms[i]
		if i < disc_count:
			var angle := 1.7 * float(p_level) + 0.95 * float(i)
			var x := center_x + sin(angle) * HELIX_RADIUS
			var y := base_y - spacing * float(i)
			p.position = Vector2(x, y)
			p.activate(i, p_level, threshold, PALETTE[i % PALETTE.size()])
			alive_count += 1
		else:
			p.deactivate()
	queue_redraw()


func _on_platform_smashed(p, impact_vy: float) -> void:
	alive_count = maxi(0, alive_count - 1)
	emit_signal("smashed", p, impact_vy)
	queue_redraw()
	if alive_count == 0:
		emit_signal("cleared")


func alive_platforms() -> Array:
	var out: Array = []
	for p in platforms:
		if p.alive:
			out.append(p)
	return out


func _draw() -> void:
	if not configured or platforms.is_empty():
		return
	# Resplandor vertical de la hélice.
	for i in int(disc_count) - 1:
		var a = platforms[i]
		var b = platforms[i + 1]
		draw_line(a.position + Vector2(0.0, 6.0), b.position + Vector2(0.0, 6.0), Color(0.13, 0.83, 0.93, 0.10), 22.0, true)
	# Espina de la hélice.
	for i in int(disc_count) - 1:
		var a2 = platforms[i]
		var b2 = platforms[i + 1]
		draw_line(a2.position, b2.position, Color(0.35, 0.90, 0.98, 0.22), 3.0, true)
	for i in int(disc_count):
		var p = platforms[i]
		if p.alive:
			draw_circle(p.position + Vector2(0.0, -4.0), 8.0, Color(1.0, 1.0, 1.0, 0.22))
