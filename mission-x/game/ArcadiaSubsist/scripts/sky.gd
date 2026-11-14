extends Node2D
## Martian sky on its own CanvasLayer (unaffected by the world's day/night CanvasModulate).
## Draws the painted backdrop, a moving sun with Mars' blue sunset halo, stars and Phobos at night.

const SURFACE_BACKGROUND: Texture2D = preload("res://assets/mars_surface_background.png")
const WORLD_WIDTH: float = 2048.0

var time_of_day: float = 0.3
var daylight: float = 1.0
var storm: float = 0.0
var animation_time: float = 0.0
var _stars: Array = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for i in range(170):
		_stars.append([rng.randf_range(0.0, WORLD_WIDTH), rng.randf_range(-170.0, 400.0), rng.randf_range(0.3, 1.0), rng.randf_range(0.0, TAU), rng.randi_range(1, 2)])

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	var night: float = 1.0 - daylight
	draw_rect(Rect2(0, -400, WORLD_WIDTH, 980), Color("5a2b2c"))
	draw_texture_rect(SURFACE_BACKGROUND, Rect2(0, -180, WORLD_WIDTH, 1152), false)

	# Sun: travels east->west across the day, pale and small as seen from Mars.
	if daylight > 0.0:
		var t: float = clampf((time_of_day - 0.04) / (0.72 - 0.04), 0.0, 1.0)
		var sun := Vector2(lerpf(1900.0, 160.0, t), 400.0 - sin(t * PI) * 330.0)
		var low: float = 1.0 - sin(t * PI)
		# Martian sunsets glow blue around the sun.
		draw_circle(sun, 70.0, Color(0.45, 0.62, 0.95, 0.10 * low * daylight))
		draw_circle(sun, 42.0, Color(0.55, 0.72, 1.0, 0.16 * low * daylight))
		draw_circle(sun, 26.0, Color(1.0, 0.92, 0.78, 0.18 * daylight))
		draw_circle(sun, 9.0, Color(1.0, 0.97, 0.9, 0.85 * daylight))

	# Night falls over the painted backdrop.
	if night > 0.0:
		draw_rect(Rect2(0, -400, WORLD_WIDTH, 980), Color(0.03, 0.03, 0.10, 0.80 * night))
		for star in _stars:
			var twinkle: float = 0.55 + 0.45 * sin(animation_time * (1.0 + float(star[2]) * 2.0) + float(star[3]))
			var alpha: float = night * float(star[2]) * twinkle * (1.0 - storm * 0.9)
			var size: float = float(star[4])
			draw_rect(Rect2(float(star[0]), float(star[1]), size, size), Color(0.92, 0.94, 1.0, alpha))
		# Phobos races across the night sky (it rises in the west).
		var nt: float = fposmod(time_of_day - 0.72, 1.0) / 0.32
		if nt <= 1.0:
			var phobos := Vector2(lerpf(150.0, 1900.0, nt), 330.0 - sin(nt * PI) * 260.0)
			draw_circle(phobos, 7.0, Color(0.72, 0.68, 0.62, night))
			draw_circle(phobos + Vector2(-2, -1), 5.0, Color(0.85, 0.8, 0.74, night))
			draw_rect(Rect2(phobos.x + 1, phobos.y + 1, 2, 2), Color(0.5, 0.46, 0.42, night))
		draw_circle(Vector2(1350, 120), 2.0, Color(0.9, 0.88, 0.82, night * 0.8))

	# Drifting high-altitude dust.
	for i in range(22):
		var x: float = fposmod(float(i * 173 + 49) + animation_time * (6.0 + float(i % 4) * 3.0), WORLD_WIDTH + 200.0) - 100.0
		var y: float = 300.0 + float((i * 37) % 150)
		var width: float = 24.0 + float((i * 11) % 50)
		draw_rect(Rect2(x, y, width, 2), Color(0.98, 0.62, 0.40, (0.10 + 0.2 * storm) * (0.3 + 0.7 * daylight)))

	if storm > 0.0:
		draw_rect(Rect2(0, -400, WORLD_WIDTH, 980), Color(0.62, 0.32, 0.17, 0.55 * storm))
