extends Control

@onready var name_label := $Panel/NameLabel
@onready var occupation_label := $Panel/OccupationLabel
@onready var age_label := $Panel/AgeLabel
@onready var description_label := $Panel/DescriptionLabel
@onready var kill_button := $Panel/KillButton
@onready var close_button := $Panel/CloseButton
@onready var dialogue := $Panel/Dialogue


var current_character = null
var kill_callback: Callable = Callable()

func _ready():
	if kill_button:
		kill_button.pressed.connect(_on_KillButton_pressed)
	if close_button:
		close_button.pressed.connect(_on_CloseButton_pressed)

func show_character(character_ref, kill_cb: Callable, state):
	current_character = character_ref
	kill_callback = kill_cb
	
	if name_label:
		name_label.text = character_ref.character_name
	if occupation_label:
		occupation_label.text = character_ref.occupation
	if age_label:
		age_label.text = str(character_ref.age)
	if description_label:
		description_label.text = character_ref.description
	
	dialogue.text = character_ref.dialogues[state]
	
	
	show()
	grab_focus()

func _on_KillButton_pressed():
	if current_character and current_character.alive and kill_callback.is_valid():
		kill_callback.call(current_character)
		hide()
		
func _on_CloseButton_pressed():
	hide()
