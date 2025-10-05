extends Control

@onready var character_list := $Panel/Characters
@onready var restart_button := $Panel/RestartButton
@onready var exit_button := $Panel/ExitButton


signal restart_pressed

func _ready():
	restart_button.pressed.connect(Callable(self, "_on_RestartButton_pressed"))
	exit_button.pressed.connect(Callable(self, "_on_ExitButton_pressed"))


func show_game_won(characters: Array):
	print("Characters: ", characters)
	var text_output = ""
	for char in characters: 
		text_output += str(char) + "\n"
	
	character_list.text = text_output  # or use bbcode_text if you want formatting
	character_list.show()
	print(character_list)
	await get_tree().create_timer(0.1).timeout

	show()


func _on_RestartButton_pressed():
	hide()
	emit_signal("restart_pressed")
	
func _on_ExitButton_pressed():
	
	print("Exit button pressed")

	get_tree().quit()
