extends Control

@onready var reason_label := $Panel/ReasonLabel
@onready var restart_button := $Panel/RestartButton

func show_game_over(reason: String):
	reason_label.text = reason
	show()

func _on_RestartButton_pressed():
	get_tree().reload_current_scene()
