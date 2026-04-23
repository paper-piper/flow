extends CharacterBody2D

const SPEED       := 75.0
const GRAVITY     := 1000.0
const KNOCK_DECAY := 900.0   # px/s² knockback friction

var _hp        := 3
var _facing    := 1           # 1 = right, -1 = left
var _knockback := Vector2.ZERO
var _hitstop   := 0

const FLASH_DUR  := 0.12
var _flash_timer := 0.0

@onready var _sprite  : Polygon2D = $Sprite
@onready var _edge_l  : RayCast2D = $EdgeLeft
@onready var _edge_r  : RayCast2D = $EdgeRight

func _physics_process(delta: float) -> void:
	if _hitstop > 0:
		_hitstop -= 1
		return

	_tick_flash(delta)

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	# Knockback decays; resume patrol when nearly stopped
	if _knockback.length() > 4.0:
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
		velocity.x = _knockback.x
		if _knockback.y < 0.0:
			velocity.y = _knockback.y   # preserve upward arc
	else:
		_knockback = Vector2.ZERO
		_patrol()

	move_and_slide()

func _patrol() -> void:
	if not is_on_floor():
		velocity.x = 0.0
		return

	var at_wall  := is_on_wall()
	var at_edge  := (_facing ==  1 and not _edge_r.is_colliding()) or \
	                (_facing == -1 and not _edge_l.is_colliding())

	if at_wall or at_edge:
		_facing = -_facing

	velocity.x      = _facing * SPEED
	_sprite.scale.x = _facing

# Called by Player when the attack hitbox overlaps this body
func take_hit(damage: int, knockback: Vector2) -> void:
	_hp          -= damage
	_knockback    = knockback
	_hitstop      = 4
	_flash_timer  = FLASH_DUR
	if _hp <= 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	var tween := get_tree().create_tween()
	tween.tween_property(self, "scale",      Vector2(2.0, 2.0), 0.07)
	tween.tween_property(self, "modulate:a", 0.0,               0.12)
	tween.tween_callback(queue_free)

func _tick_flash(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		modulate = Color(1.0, 0.15, 0.15, 1.0)
	else:
		modulate = Color(1.0, 1.0,  1.0,  1.0)
