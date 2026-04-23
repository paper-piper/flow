extends CharacterBody2D

# ── Movement ──────────────────────────────────────────────────────────────────
const SPEED           := 200.0
const ACCEL           := 1400.0
const FRICTION        := 1000.0
const JUMP_VEL        := -400.0
const GRAVITY         := 1000.0
const FAST_FALL_GRAV  := 2400.0
const WALL_SLIDE_GRAV := 90.0

const WALL_JUMP_VEL := Vector2(300.0, -450.0)

# ── Coyote time ───────────────────────────────────────────────────────────────
const COYOTE_TIME := 0.10
var _coyote_timer := 0.0

# ── Wall grace ────────────────────────────────────────────────────────────────
const WALL_GRACE := 0.15
var _wall_timer := 0.0
var _wall_dir   := 0

# ── Dash ──────────────────────────────────────────────────────────────────────
const DASH_SPEED    := 620.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.8
const WALL_DASH_H   := 580.0
const WALL_DASH_V   := -160.0

var _dashing       := false
var _dash_timer    := 0.0
var _dash_cooldown := 0.0
var _dash_dir_x    := 1.0

# ── Grapple ───────────────────────────────────────────────────────────────────
var _grappling      := false
var _grapple_branch : Node2D = null

# ── Attack ────────────────────────────────────────────────────────────────────
const ATTACK_DURATION := 0.20
var _attack_timer := 0.0
var _attacking    := false

# ── Hitstop ───────────────────────────────────────────────────────────────────
var _hitstop := 0

# ── Camera shake ──────────────────────────────────────────────────────────────
var _shake_time := 0.0
var _shake_str  := 0.0

@onready var _sprite : Polygon2D = $Sprite
@onready var _hitbox : Area2D    = $AttackHitbox
@onready var _cam    : Camera2D  = $Camera2D
@onready var _rope   : Line2D    = $RopeLine

func _ready() -> void:
	add_to_group("player")
	_hitbox.monitoring = false
	_hitbox.body_entered.connect(_on_hit_body)
	_rope.add_point(Vector2.ZERO)
	_rope.add_point(Vector2.ZERO)
	_rope.visible = false

func _physics_process(delta: float) -> void:
	_tick_shake(delta)

	if _hitstop > 0:
		_hitstop -= 1
		return

	var floored := is_on_floor()
	var on_wall  := is_on_wall_only()

	# ── Coyote timer ──────────────────────────────────────────────────────────
	if floored:
		_coyote_timer = COYOTE_TIME
	elif _coyote_timer > 0.0:
		_coyote_timer -= delta

	# ── Wall grace timer ──────────────────────────────────────────────────────
	if on_wall:
		_wall_timer = WALL_GRACE
		_wall_dir   = int(sign(get_wall_normal().x))
	elif _wall_timer > 0.0:
		_wall_timer -= delta

	# ── Grapple toggle ────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("grapple"):
		if _grappling:
			_release_grapple(false)
		else:
			_try_grapple()

	# ── Active grapple physics ─────────────────────────────────────────────────
	if _grappling and _grapple_branch != null:
		velocity.y += GRAVITY * delta

		var to_branch := _grapple_branch.global_position - global_position
		if to_branch.length_squared() > 0.0:
			var rope_dir := to_branch.normalized()
			# Cancel velocity pulling away from branch (rope tension)
			var away_vel := velocity.dot(-rope_dir)
			if away_vel > 0.0:
				velocity += rope_dir * away_vel

		# Swing with horizontal input
		var dir := Input.get_axis("ui_left", "ui_right")
		if dir != 0.0:
			velocity.x = move_toward(velocity.x, dir * SPEED * 0.5, ACCEL * 0.4 * delta)
			_sprite.scale.x = dir

		# Jump while grappling: release and leap with upward boost
		if Input.is_action_just_pressed("ui_accept"):
			_release_grapple(true)

		# Update rope visual
		if _grapple_branch != null:
			_rope.set_point_position(1, to_local(_grapple_branch.global_position))

		move_and_slide()
		return

	# ── Dash cooldown ─────────────────────────────────────────────────────────
	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta

	# ── Active dash ───────────────────────────────────────────────────────────
	if _dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir_x * DASH_SPEED
		velocity.y = 0.0
		if _dash_timer <= 0.0:
			_dashing = false
		move_and_slide()
		return

	# ── Wall stick ────────────────────────────────────────────────────────────
	var sticking := on_wall and Input.is_action_pressed("wall_stick")

	# ── Gravity ───────────────────────────────────────────────────────────────
	if floored:
		velocity.y = 0.0
	elif sticking:
		velocity.y = 0.0
	elif on_wall and velocity.y > 0.0:
		velocity.y += WALL_SLIDE_GRAV * delta
	elif Input.is_action_pressed("ui_down"):
		velocity.y += FAST_FALL_GRAV * delta
	else:
		velocity.y += GRAVITY * delta

	# ── Horizontal movement ───────────────────────────────────────────────────
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		_sprite.scale.x = dir
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# ── Jump ──────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept"):
		if _coyote_timer > 0.0:
			velocity.y    = JUMP_VEL
			_coyote_timer = 0.0
		elif _wall_timer > 0.0:
			velocity.y  = WALL_JUMP_VEL.y
			velocity.x  = WALL_JUMP_VEL.x * _wall_dir
			_wall_timer = 0.0

	# ── Dash ──────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		if _wall_timer > 0.0:
			velocity.x     = WALL_DASH_H * _wall_dir
			velocity.y     = WALL_DASH_V
			_dash_cooldown = DASH_COOLDOWN
			_wall_timer    = 0.0
		else:
			_dashing       = true
			_dash_timer    = DASH_DURATION
			_dash_dir_x    = _sprite.scale.x
			_dash_cooldown = DASH_COOLDOWN

	# ── Attack ────────────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("attack") and not _attacking:
		_begin_attack()

	if _attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────

func _try_grapple() -> void:
	var branches := get_tree().get_nodes_in_group("branch_in_range")
	if branches.is_empty():
		return
	var closest : Node2D = branches[0]
	var closest_dist := global_position.distance_to(closest.global_position)
	for b in branches:
		var d := global_position.distance_to(b.global_position)
		if d < closest_dist:
			closest = b
			closest_dist = d
	_grappling = true
	_grapple_branch = closest
	velocity *= 0.3   # brief pause as hook catches
	_rope.set_point_position(1, to_local(closest.global_position))
	_rope.visible = true

func _release_grapple(jump: bool) -> void:
	_grappling = false
	_grapple_branch = null
	_rope.visible = false
	velocity *= 1.3   # carry swing momentum as a boost
	if jump:
		velocity.y = -300.0   # leap off the rope

func _begin_attack() -> void:
	_attacking    = true
	_attack_timer = ATTACK_DURATION
	_hitbox.monitoring = true
	_hitbox.position.x = 42.0 * _sprite.scale.x

func _end_attack() -> void:
	_attacking = false
	_hitbox.monitoring = false

func _on_hit_body(body: Node2D) -> void:
	if not body.has_method("take_hit"):
		return
	var knock_dir := Vector2(_sprite.scale.x, -0.3).normalized()
	body.take_hit(1, knock_dir * 380.0)
	_hitstop    = 4
	_shake_str  = 7.0
	_shake_time = 0.16

func _tick_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		_cam.offset = Vector2(
			randf_range(-_shake_str, _shake_str),
			randf_range(-_shake_str, _shake_str)
		)
	else:
		_cam.offset = Vector2.ZERO
