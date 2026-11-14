extends CharacterBody2D
class_name MarsEngineer

const MOVE_SPEED: float = 220.0
const JUMP_SPEED: float = -420.0
const GRAVITY: float = 1050.0
const CLIMB_SPEED: float = 170.0
const COLONY_ART = preload("res://scripts/colony_art.gd")

var world
var facing: int = 1
var mine_cooldown: float = 0.0
var climbing: bool = false
var anim_time: float = 0.0
var walk_phase: float = 0.0
var mining_now: bool = false
var mine_point: Vector2 = Vector2.ZERO
var darkness: float = 0.0

var headlamp: PointLight2D
var glow: PointLight2D
var beam_light: PointLight2D
var dust: CPUParticles2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var capsule := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 10.0
	shape.height = 44.0
	capsule.shape = shape
	add_child(capsule)
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	headlamp = PointLight2D.new()
	headlamp.texture = COLONY_ART.light_texture()
	headlamp.color = Color(1.0, 0.93, 0.8)
	headlamp.texture_scale = 2.0
	headlamp.position = Vector2(26, -16)
	add_child(headlamp)
	glow = PointLight2D.new()
	glow.texture = COLONY_ART.light_texture()
	glow.color = Color(0.85, 0.9, 1.0)
	glow.texture_scale = 1.1
	glow.position = Vector2(0, -8)
	add_child(glow)
	beam_light = PointLight2D.new()
	beam_light.texture = COLONY_ART.light_texture()
	beam_light.color = Color(1.0, 0.65, 0.3)
	beam_light.texture_scale = 0.7
	beam_light.energy = 1.2
	beam_light.enabled = false
	add_child(beam_light)

	dust = CPUParticles2D.new()
	dust.position = Vector2(0, 24)
	dust.amount = 18
	dust.lifetime = 0.55
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(6, 1)
	dust.direction = Vector2(0, -1)
	dust.spread = 70.0
	dust.initial_velocity_min = 10.0
	dust.initial_velocity_max = 35.0
	dust.gravity = Vector2(0, 40)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.55, 0.38, 0.65))
	ramp.set_color(1, Color(0.85, 0.55, 0.38, 0.0))
	dust.color_ramp = ramp
	dust.emitting = false
	add_child(dust)

func _physics_process(delta: float) -> void:
	anim_time += delta
	if mine_cooldown > 0.0:
		mine_cooldown -= delta

	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = axis * MOVE_SPEED
	if axis != 0.0:
		facing = 1 if axis > 0.0 else -1

	var on_ladder: bool = is_instance_valid(world) and world.has_method("is_on_ladder") and world.is_on_ladder(global_position)
	var climb_axis := Input.get_axis("move_up", "move_down")
	if not on_ladder:
		climbing = false
	elif climb_axis != 0.0:
		climbing = true

	if climbing:
		velocity.y = climb_axis * CLIMB_SPEED
		if Input.is_action_just_pressed("jump"):
			climbing = false
			velocity.y = JUMP_SPEED * 0.75
	elif not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_SPEED

	move_and_slide()
	global_position.x = clampf(global_position.x, 16.0, 2032.0)

	var walking: bool = is_on_floor() and absf(velocity.x) > 1.0 and not climbing
	if walking:
		walk_phase += delta * 11.0
	elif climbing and absf(velocity.y) > 1.0:
		walk_phase += delta * 9.0
	else:
		walk_phase = lerpf(walk_phase, roundf(walk_phase / PI) * PI, clampf(delta * 10.0, 0.0, 1.0))
	dust.emitting = walking and global_position.y < 520.0

	mining_now = false
	if Input.is_action_pressed("mine") and is_instance_valid(world):
		var target := get_global_mouse_position()
		var cell: Vector2i = world.mine_target_cell
		if cell.x > -100:
			mining_now = true
			mine_point = Vector2((cell.x + 0.5) * 32.0, (cell.y + 0.5) * 32.0)
			facing = 1 if mine_point.x >= global_position.x else -1
		if mine_cooldown <= 0.0 and world.has_method("mine_at") and world.mine_at(target, global_position):
			mine_cooldown = 0.38

	headlamp.position = Vector2(26 * facing, -16)
	headlamp.energy = 0.1 + 1.25 * darkness
	glow.energy = 0.05 + 0.5 * darkness
	beam_light.enabled = mining_now
	if mining_now:
		beam_light.position = mine_point - global_position
		beam_light.energy = 0.8 + 0.4 * sin(anim_time * 40.0)
	queue_redraw()

func _draw() -> void:
	var suit_white := Color("e9e4d6")
	var suit_mid := Color("c4c6bf")
	var suit_shadow := Color("7c807d")
	var orange := Color("e07a38")
	var dark := Color("23272c")
	var visor := Color("1f3644")

	var step: float = sin(walk_phase)
	var bob: float = absf(step) * -1.5 if not climbing else 0.0
	var leg_a: float = step * 3.0
	var leg_b: float = -step * 3.0

	draw_set_transform(Vector2(0, 0), 0.0, Vector2(facing, 1))
	# Ground shadow.
	if is_on_floor():
		draw_rect(Rect2(-12, 24, 24, 3), Color(0.0, 0.0, 0.0, 0.30))

	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	# Life-support pack.
	draw_rect(Rect2(-16, -10, 9, 24), dark)
	draw_rect(Rect2(-15, -9, 7, 21), Color("6f7472"))
	draw_rect(Rect2(-14, -6, 5, 4), orange)
	draw_rect(Rect2(-14, 4, 5, 3), Color("3c5157"))
	draw_rect(Rect2(-13, 8, 3, 2), Color(0.5, 1.0, 0.8, 0.6 + 0.4 * sin(anim_time * 3.0)))
	draw_rect(Rect2(-17, -14, 2, 8), Color("8a8f8c"))

	# Legs (back leg darker) and boots.
	if climbing:
		leg_a = sin(walk_phase) * 4.0
		leg_b = -leg_a
	draw_rect(Rect2(-6 + leg_b, 10, 7, 13), suit_shadow)
	draw_rect(Rect2(-7 + leg_b, 21, 10, 5), Color("1c1f23"))
	draw_rect(Rect2(0 + leg_a, 10, 7, 13), suit_mid)
	draw_rect(Rect2(1 + leg_a, 11, 5, 11), suit_white)
	draw_rect(Rect2(-1 + leg_a, 21, 11, 5), dark)
	draw_rect(Rect2(0 + leg_a, 21, 9, 2), Color("aeb4ad"))
	draw_rect(Rect2(1 + leg_a, 15, 5, 2), orange)

	# Torso.
	draw_rect(Rect2(-11, -12, 22, 25), dark)
	draw_rect(Rect2(-10, -11, 20, 23), suit_mid)
	draw_rect(Rect2(-9, -11, 17, 20), suit_white)
	draw_rect(Rect2(-5, -6, 12, 9), Color("d4d6cf"))
	draw_rect(Rect2(-4, -5, 6, 3), Color("f6f3ea"))
	draw_rect(Rect2(-9, 3, 18, 3), orange)
	draw_rect(Rect2(2, -4, 4, 3), Color("2e3c42"))
	draw_rect(Rect2(3, -3, 2, 1), Color(0.55, 1.0, 0.8, 0.9))
	draw_rect(Rect2(-9, 9, 18, 3), Color("9a9d97"))

	# Arm: points at the mining target while drilling.
	var shoulder := Vector2(2, -6)
	if mining_now:
		var local_target: Vector2 = mine_point - global_position - Vector2(0, bob)
		local_target.x *= float(facing)
		var dir: Vector2 = (local_target - shoulder).normalized()
		var hand: Vector2 = shoulder + dir * 13.0
		draw_line(shoulder, hand, dark, 7.0)
		draw_line(shoulder, hand, suit_white, 5.0)
		draw_rect(Rect2(hand.x - 3, hand.y - 3, 7, 6), Color("3a4044"))
		draw_rect(Rect2(hand.x - 1, hand.y - 1, 3, 2), orange)
		# Cutting laser.
		var flick: float = 0.75 + 0.25 * sin(anim_time * 50.0)
		draw_line(hand, local_target, Color(1.0, 0.55, 0.2, 0.35 * flick), 6.0)
		draw_line(hand, local_target, Color(1.0, 0.82, 0.45, 0.9 * flick), 2.0)
		draw_line(hand, local_target, Color(1.0, 1.0, 0.9, flick), 1.0)
		draw_circle(local_target, 5.0 + 2.0 * flick, Color(1.0, 0.7, 0.3, 0.45))
		draw_circle(local_target, 2.5, Color(1.0, 1.0, 0.85, 0.95))
		for k in range(3):
			var a: float = anim_time * 23.0 + float(k) * 2.1
			var spark: Vector2 = local_target + Vector2(cos(a), sin(a) - 0.6) * (4.0 + fmod(anim_time * 60.0 + float(k) * 5.0, 9.0))
			draw_rect(Rect2(spark.x, spark.y, 2, 2), Color(1.0, 0.85, 0.5, 0.9))
	else:
		var swing: float = -step * 2.5 if not climbing else -4.0
		draw_rect(Rect2(-1 + swing, -6, 7, 15), dark)
		draw_rect(Rect2(0 + swing, -5, 5, 13), suit_white)
		draw_rect(Rect2(0 + swing, 4, 5, 3), orange)
		draw_rect(Rect2(0 + swing, 8, 5, 3), Color("3a4044"))

	# Helmet with a reflective visor facing forward.
	draw_rect(Rect2(-9, -29, 19, 19), dark)
	draw_rect(Rect2(-8, -28, 17, 17), suit_mid)
	draw_rect(Rect2(-7, -28, 15, 14), suit_white)
	draw_rect(Rect2(-1, -24, 10, 9), visor)
	draw_rect(Rect2(0, -23, 4, 2), Color("a8e0e0"))
	draw_rect(Rect2(6, -19, 2, 2), Color("6aa7ad"))
	draw_rect(Rect2(-1, -16, 10, 1), Color("0f1c24"))
	draw_rect(Rect2(-9, -24, 3, 9), orange)
	# Helmet lamp.
	draw_rect(Rect2(7, -30, 4, 3), Color("3a4044"))
	draw_rect(Rect2(9, -29, 2, 2), Color(1.0, 0.95, 0.75, 0.4 + 0.6 * darkness))
	draw_rect(Rect2(-4, -31, 2, 3), Color("8a8f8c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
