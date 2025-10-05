extends Control

@onready var event_list := $Panel/ScrollContainer/EventList
@onready var close_button := $Panel/CloseButton

func _ready():
	if close_button:
		close_button.pressed.connect(_on_CloseButton_pressed)
	
func show_event_info(description: String):
	
	# --- Create and configure the label ---
	var label = Label.new()
	label.text = description
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.clip_text = false
	label.custom_minimum_size = Vector2(event_list.size.x, 0) 

	var label_settings := load("res://assets/brown_normal_text.tres")
	if label_settings:
		label.label_settings = label_settings
	else:
		push_warning("Could not load brown_normal_rect.tres")
		
	# --- Add the label to the event list ---
	event_list.add_child(label)

	# --- Divider line between events ---
	var divider = ColorRect.new()
	divider.color = label_settings.font_color
	divider.custom_minimum_size = Vector2(event_list.size.x - 20, 2)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_list.add_child(divider)
	
	show()
	
func clear_events():
	for child in event_list.get_children():
		child.queue_free()
	
func _on_CloseButton_pressed():
	clear_events()
	hide()
