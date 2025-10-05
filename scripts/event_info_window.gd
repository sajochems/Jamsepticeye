extends Control

@onready var event_list := $Panel/ScrollContainer/EventList
@onready var close_button := $Panel/CloseButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_CloseButton_pressed)
	
func show_event_info(description: String):
	var label = Label.new()
	label.text = description
	label.autowrap = true
	event_list.add_child(label)
	show()
	
func _on_CloseButton_pressed():
	hide()
