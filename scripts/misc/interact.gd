extends Node2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interact_area: Area2D = $InteractArea

func _ready():
	anim_sprite.play("Idle")
	interact_area.input_event.connect(_on_interact_area_input)

func _on_interact_area_input(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interact()

func interact():
	"""Called when player clicks"""
	anim_sprite.play("Interact")
	await anim_sprite.animation_finished
	anim_sprite.play("Idle")
