class_name SynapseDemoMultiplayerCharacter
extends CharacterBody2D

@export var color: Color

@onready var sprite_2d: Sprite2D = %Sprite2D

func _ready() -> void:
	sprite_2d.modulate = color
