extends Control

@onready var start_button := $Panel/Start
@onready var quit_button := $Panel/Quit

func _ready():
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	hide()

func _on_quit_button_pressed():
	get_tree().quit()  
