extends Area2D

# Metadata fields
var character_name: String
var character_tag: String
var age: int
var occupation: String
var description: String
var alive: bool = true

signal clicked(character_ref)

func _ready():
	connect("input_event", Callable(self, "_on_input_event"))

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", self)
