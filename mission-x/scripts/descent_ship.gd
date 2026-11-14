extends Node2D

# A small, hand-drawn pixel-style lander used only by the opening cutscene.
# The ship is made from chunky rectangles so it stays crisp with nearest filtering.

var flight_time: float = 0.0
var landed: bool = false
var dust_time: float = 0.0

func set_landed(value: bool) -> void:
	if value and not landed:
		dust_time = 0.0
	landed = value
	queue_redraw()

func _process(delta: float) -> void:
	flight_time += delta
	if landed:
		dust_time = minf(2.0, dust_time + delta)
	queue_redraw()

func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(flight_time * 19.0)
	var flame_length: int = 20 + int(pulse * 12.0)

	# Engine flames are drawn first, behind the landing capsule.
	if not landed:
		_draw_engine_flame(-23.0, flame_length)
		_draw_engine_flame(23.0, flame_length - 3)
	else:
		_draw_landing_dust()

	# Dark silhouette and armoured hull.
	draw_rect(Rect2(-38, -43, 76, 86), Color("28232a"))
	draw_rect(Rect2(-34, -47, 68, 82), Color("665c58"))
	draw_rect(Rect2(-30, -43, 60, 75), Color("c3b8a6"))
	draw_rect(Rect2(-26, -39, 52, 66), Color("e0d3bd"))

	# Top command pod and orange mission markings.
	draw_rect(Rect2(-25, -58, 50, 23), Color("39343a"))
	draw_rect(Rect2(-21, -58, 42, 19), Color("b8ad9e"))
	draw_rect(Rect2(-9, -55, 18, 10), Color("d97935"))
	draw_rect(Rect2(-4, -73, 8, 17), Color("554c48"))
	draw_rect(Rect2(-2, -78, 4, 7), Color("f05e43"))

	# Front viewport, with a hard-edged cyan reflection.
	draw_rect(Rect2(-17, -33, 34, 25), Color("403b43"))
	draw_rect(Rect2(-13, -30, 26, 19), Color("274e5a"))
	draw_rect(Rect2(-9, -28, 7, 5), Color("8fd4d5"))
	draw_rect(Rect2(5, -19, 6, 5), Color("4d8790"))

	# Chunky side armour, panel seams, and service hatch.
	draw_rect(Rect2(-34, -15, 8, 28), Color("8e5540"))
	draw_rect(Rect2(26, -15, 8, 28), Color("8e5540"))
	draw_rect(Rect2(-29, 1, 58, 7), Color("d97935"))
	draw_rect(Rect2(-24, 12, 48, 5), Color("8f8275"))
	draw_rect(Rect2(-9, 19, 18, 15), Color("5b5553"))
	draw_rect(Rect2(-5, 22, 10, 7), Color("303941"))
	draw_rect(Rect2(-2, 23, 3, 3), Color("e5a15e"))

	# Landing legs: short, angular pieces rather than smooth vector lines.
	draw_rect(Rect2(-34, 22, 7, 19), Color("3b3537"))
	draw_rect(Rect2(27, 22, 7, 19), Color("3b3537"))
	draw_rect(Rect2(-43, 37, 16, 6), Color("8d8175"))
	draw_rect(Rect2(27, 37, 16, 6), Color("8d8175"))
	draw_rect(Rect2(-46, 39, 20, 5), Color("d97935"))
	draw_rect(Rect2(26, 39, 20, 5), Color("d97935"))

	# Tiny status lights give the silhouette a bit of life.
	draw_rect(Rect2(-29, -3, 4, 4), Color("f2bd65"))
	draw_rect(Rect2(25, -3, 4, 4), Color("f2bd65"))
	draw_rect(Rect2(-4, 11, 8, 3), Color("6bbbc0"))

func _draw_engine_flame(engine_x: float, length: int) -> void:
	draw_rect(Rect2(engine_x - 7.0, 42.0, 14.0, float(length)), Color("d95b32"))
	draw_rect(Rect2(engine_x - 4.0, 42.0, 8.0, float(length) * 0.72), Color("ffb24f"))
	draw_rect(Rect2(engine_x - 2.0, 42.0, 4.0, float(length) * 0.42), Color("fff0b2"))

func _draw_landing_dust() -> void:
	var puff: float = clampf(dust_time / 1.2, 0.0, 1.0)
	var fade: float = 1.0 - clampf((dust_time - 0.45) / 1.5, 0.0, 1.0)
	var alpha: float = puff * fade * 0.7
	var dust_color: Color = Color(0.91, 0.48, 0.30, alpha)
	var shadow_color: Color = Color(0.39, 0.20, 0.20, alpha * 0.8)

	# Pixel clusters spread sideways after touchdown.
	draw_rect(Rect2(-80.0 - dust_time * 17.0, 42, 28, 8), shadow_color)
	draw_rect(Rect2(-68.0 - dust_time * 12.0, 32, 20, 9), dust_color)
	draw_rect(Rect2(-48.0 - dust_time * 8.0, 39, 22, 7), dust_color)
	draw_rect(Rect2(52.0 + dust_time * 8.0, 38, 24, 8), dust_color)
	draw_rect(Rect2(66.0 + dust_time * 12.0, 29, 20, 10), dust_color)
	draw_rect(Rect2(78.0 + dust_time * 16.0, 43, 28, 7), shadow_color)
