extends Control

@onready var title_label := $Panel/Title
@onready var description_label := $Panel/DescriptionLabel
@onready var reason_label := $Panel/ReasonLabel
@onready var restart_button := $Panel/RestartButton

signal restart_pressed

func _ready():
	restart_button.pressed.connect(Callable(self, "_on_RestartButton_pressed"))

func show_game_over(title: String, description: String, reason: String):
	
	print("Title label:", title_label)
	print("Description label:", description_label)
	print("Reason label:", reason_label)

	title_label.text = title
	description_label.text = description
	reason_label.text = reason
	show()

func _on_RestartButton_pressed():
	hide()
	emit_signal("restart_pressed")
