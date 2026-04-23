extends Node2D

@onready var _blob : Polygon2D = $Blob

func _ready() -> void:
	add_to_group("branch")
	$DetectionArea.body_entered.connect(_on_body_entered)
	$DetectionArea.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if not _blob.visible:
		return
	var s := 1.0 + 0.18 * sin(Time.get_ticks_msec() * 0.0045)
	_blob.scale = Vector2(s, s)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_blob.visible = true
		add_to_group("branch_in_range")

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_blob.visible = false
		remove_from_group("branch_in_range")
