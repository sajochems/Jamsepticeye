extends Control

@onready var name_label := $Panel/NameLabel
@onready var occupation_label := $Panel/OccupationLabel
@onready var age_label := $Panel/AgeLabel
@onready var description_label := $Panel/DescriptionLabel
@onready var kill_button := $Panel/KillButton
@onready var game_over_label := $Panel/GameOverLabel

var current_character = null
var kill_callback: Callable = Callable()

func show_character(character_ref, kill_cb: Callable):
	current_character = character_ref
	kill_callback = kill_cb
	
	name_label.text = character_ref.character_name
	occupation_label.text = character_ref.occupation
	age_label.text = str(character_ref.age)
	description_label.text = character_ref.description
	game_over_label.visible = false
	
	show()

func _on_KillButton_pressed():
	if current_character and current_character.alive and kill_callback.is_valid():
		kill_callback.call(current_character)
		hide()

func show_game_over(reason: String):
	game_over_label.text = reason
	game_over_label.visible = true
	show()
