extends CharacterBody2D

# ── Movement ──────────────────────────────────────────────────────────────────
const SPEED          := 200.0
const ACCEL          := 1400.0   # px/s² on input
const FRICTION       := 1000.0   # px/s² with no input
const JUMP_VEL       := -400.0
const GRAVITY        := 1000.0
const FAST_FALL_GRAV := 2400.0   # hold-down while airborne
const WALL_SLIDE_GRAV := 90.0    # slow descent while touching wall

# Wall jump launches player away from the wall
const WALL_JUMP_VEL := Vector2(230.0, -360.0)

# ── Coyote time: still allow jump briefly after walking off a ledge ───────────
const COYOTE_TIME := 0.10
var _coyote_timer := 0.0

# ── Wall grace: still allow wall-jump briefly after leaving wall ──────────────
const WALL_GRACE := 0.15
var _wall_timer := 0.0
var _wall_dir   := 0   # direction AWAY from last wall (+1 right, -1 left)

# ── Attack ────────────────────────────────────────────────────────────────────
const ATTACK_DURATION := 0.20
var _attack_timer := 0.0
var _attacking    := false

# ── Hitstop: skip N physics frames on landing a hit ──────────────────────────
var _hitstop := 0

# ── Camera shake ──────────────────────────────────────────────────────────────
var _shake_time := 0.0
var _shake_str  := 0.0

@onready var _sprite : Polygon2D = $Sprite
@onready var _hitbox : Area2D    = $AttackHitbox
@onready var _cam    : Camera2D  = $Camera2D

func _ready() -> void:
	_hitbox.monitoring = false
	_hitbox.body_entered.connect(_on_hit_body)

func _physics_process(delta: float) -> void:
	# Shake runs even during freeze so the snap is immediate
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
		_wall_dir   = int(sign(get_wall_normal().x))   # points away from wall
	elif _wall_timer > 0.0:
		_wall_timer -= delta

	# ── Gravity ───────────────────────────────────────────────────────────────
	if floored:
		velocity.y = 0.0
	elif on_wall and velocity.y > 0.0:
		velocity.y += WALL_SLIDE_GRAV * delta
	elif Input.is_action_pressed("ui_down"):
		velocity.y += FAST_FALL_GRAV * delta
	else:
		velocity.y += GRAVITY * delta

	# ── Horizontal movement with acceleration / friction ──────────────────────
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		_sprite.scale.x = dir   # flip sprite to face movement direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# ── Jump (coyote or wall-jump) ────────────────────────────────────────────
	if Input.is_action_just_pressed("ui_accept"):
		if _coyote_timer > 0.0:
			velocity.y    = JUMP_VEL
			_coyote_timer = 0.0
		elif _wall_timer > 0.0:
			velocity.y  = WALL_JUMP_VEL.y
			velocity.x  = WALL_JUMP_VEL.x * _wall_dir
			_wall_timer = 0.0

	# ── Attack (X key) ────────────────────────────────────────────────────────
	if Input.is_action_just_pressed("attack") and not _attacking:
		_begin_attack()

	if _attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	move_and_slide()

# ─────────────────────────────────────────────────────────────────────────────

func _begin_attack() -> void:
	_attacking    = true
	_attack_timer = ATTACK_DURATION
	_hitbox.monitoring = true
	_hitbox.position.x = 42.0 * _sprite.scale.x   # place hitbox in front

func _end_attack() -> void:
	_attacking = false
	_hitbox.monitoring = false

func _on_hit_body(body: Node2D) -> void:
	if not body.has_method("take_hit"):
		return
	var knock_dir := Vector2(_sprite.scale.x, -0.3).normalized()
	body.take_hit(1, knock_dir * 380.0)
	# Freeze frames + screen shake
	_hitstop   = 4
	_shake_str = 7.0
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
