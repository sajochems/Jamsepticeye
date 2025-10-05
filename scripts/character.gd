extends Area2D

var character_name: String
var character_tag: String
var age: int
var occupation: String
var description: String
var alive: bool = true

signal clicked(character_ref)

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $Name

func _ready():
	connect("input_event", Callable(self, "_on_input_event"))
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	
	if name_label:
		name_label.text = character_name

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", self)

func _on_mouse_entered():
	if sprite:
		sprite.modulate = Color(1, 1, 0, 1)  # brighten
		
	name_label.visible = true

func _on_mouse_exited():
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)  # reset color
		
	name_label.visible = false
