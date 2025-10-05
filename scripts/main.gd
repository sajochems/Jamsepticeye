extends Node2D

const CHARACTERS_JSON := "res://data/characters.json"
const INSTANT_LOSE_EVENTS_JSON := "res://data/instant_lose_events.json"
const SAVEABLE_LOSE_EVENTS_JSON := "res://data/saveable_lose_events.json"
const STATE_CHANGE_EVENTS_JSON := "res://data/state_change_events.json"
const DEFAULT_SPRITE := "res://assets/sprites/default.png"
const Events = preload("res://scripts/events.gd")

var events = Events.new()

@onready var CharacterScene := preload("res://scenes/character.tscn")
@onready var info_window := $UI/CharacterInfoWindow
@onready var game_over_window := $UI/GameOverWindow
@onready var game_won_window := $UI/GameWonWindow
@onready var event_info_window := $UI/EventInfoWindow
@onready var hands_folder := "res://assets/hands/"
@onready var hand_container := $UI/HandContainer
@onready var round_label := $UI/RoundLabel
@onready var log_panel := $UI/LogPanel

var characters: Dictionary = {}  
var alive_tags: Array = []
var round: int = 0
var win_round: int = 8
var state: int = 0
var state_change_events: Array = []
var instant_lose_events: Array = []
var saveable_lose_events: Array = []
var game_over: bool = false

func _ready():
	events.load_events()
	load_characters()
	update_round_label()
	
	# Connect GameOverWindow restart signal
	print("GameOverWindow script path:", game_over_window.get_script().resource_path)
	game_over_window.connect("restart_pressed", Callable(self, "restart_game"))
	
	instant_lose_events = events.instant_death_events
	state_change_events = events.state_change_events
	saveable_lose_events = events.saveable_death_events

			
func load_characters():
	var file := FileAccess.open(CHARACTERS_JSON, FileAccess.READ)
	if not file:
		push_error("Could not open characters.json")
		return
	
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		push_error("characters.json format invalid")
		return
	
	for char_data in parsed:
		spawn_character(char_data)
		
func spawn_character(char_data: Dictionary):
	var character := CharacterScene.instantiate()
	
	# --- Assign character metadata ---
	character.character_name = char_data.get("name", "Unknown")
	character.character_tag = char_data.get("tag", "")
	character.age = char_data.get("age", 0)
	character.occupation = char_data.get("occupation", "")
	character.description = char_data.get("description", "")
	character.dialogues = char_data.get("dialogues", "")
	
	# --- Load sprite or fallback to default ---
	var sprite_path = char_data.get("sprite", DEFAULT_SPRITE)
	if not ResourceLoader.exists(sprite_path):
		sprite_path = DEFAULT_SPRITE
	var tex := load(sprite_path)
	if tex and character.has_node("Sprite2D"):
		character.get_node("Sprite2D").texture = tex
		
	# --- Handle normalized coordinates ---
	# If values are <= 1, treat them as normalized; otherwise as absolute pixels
	var viewport_size = get_viewport().get_visible_rect().size
	var x = char_data.get("x", 0)
	var y = char_data.get("y", 0)
	
	var pos: Vector2
	if x <= 1.0 and y <= 1.0:
		pos = Vector2(x * viewport_size.x, y * viewport_size.y)
	else:
		pos = Vector2(x, y)
		
	pos -= viewport_size / 2.0
	character.position = pos
	
	character.connect("clicked", Callable(self, "_on_character_clicked"))
	$CharacterRows.add_child(character)
	
	characters[character.character_tag] = character
	alive_tags.append(character.character_tag)
	
func _on_character_clicked(character_ref):
	if not game_over:
		info_window.show_character(character_ref, Callable(self, "_on_character_killed"), state)
		
func _on_character_killed(character_ref):
	if game_over or not character_ref.alive:
		return
		
	character_ref.alive = false
	character_ref.hide()
	alive_tags.erase(character_ref.character_tag)
	
	animate_character_death(character_ref)
	await get_tree().create_timer(3.5).timeout  # <-- waits fixed time before continuing

	
	round += 1
	update_round_label()
	add_log("Round %d: %s was killed" % [round, character_ref.character_name])
	

	for ev in instant_lose_events:
		if events.evaluate_instant_lose_event(ev, alive_tags, state, round):
			trigger_game_over("You REALLY shouldn't have done that", ev.get("description", ""))
			return
		
	for ev in saveable_lose_events:
		if events.evaluate_instant_lose_event(ev, alive_tags, state, round):
			if events.evaluate_saveable_event(ev, alive_tags):
				trigger_game_over("Oh no, if it isn't the consequences of your actions...", ev.get("lost_text", ""))
				return
			else:
				#add_log(ev.get("saved_text", ""))
				event_info_window.show_event_info(ev.get("description", ""))
				event_info_window.show_event_info(ev.get("saved_text", ""))
				ev["triggered"] = true

	
	for ev in state_change_events:
		if events.evaluate_state_changes(ev, alive_tags, state, round):
			win_round = win_round + (events.rounds - round)
			state = events.states
			add_log(ev.get("description", ""))
			add_log("Win round is now " + str(round) + " / " + str(win_round))
			add_log("State is now " + str(state))
			event_info_window.show_event_info(ev.get("description", ""))
			ev["triggered"] = true
			
	if state > 3:
		trigger_game_over("You know there's such a thing as TOO much tension, right?", "Your travellers lost all faith in your leadership.. they decided its YOU who gets sacrificed next!")
		return
	if round >= win_round:
		print("Round is "  + str(round))
		var alive_characters = []
		for tag in characters.keys():
			var char = characters[tag]
			if char.alive:
				alive_characters.append(char.character_name)

		trigger_game_won(alive_characters)
func trigger_game_over(title: String, reason: String):
	game_over = true
	game_over_window.show_game_over(title, reason)
	
func trigger_game_won(characters: PackedStringArray):
	game_over = true
	game_won_window.show_game_won(characters)
	
func update_round_label():
	round_label.text = "Round: %d" % round
	
func add_log(msg: String):
	log_panel.append_text(msg + "\n")
	
func intersects(list1: Array, list2: Array) -> bool:
	for item in list1:
		if list2.has(item):
			return true
	return false
	
func all_dead(tags: Array) -> bool:
	for t in tags:
		if alive_tags.has(t):
			return false
	return true
	
func animate_character_death(character_ref):
	character_ref.z_index = 100  # Ensure it's above other nodes
	character_ref.show()

	var screen_size = get_viewport_rect().size
	var end_pos = Vector2(randf() * screen_size.x, -screen_size.y)  # thrown off-screen upward
	var tween = create_tween()
	var rotation_dir = 1 if randf() > 0.5 else -1
	var target_rotation = 720 * rotation_dir
	tween.tween_property(character_ref, "position", end_pos, 2.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(character_ref, "rotation_degrees", target_rotation, 2.5).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(Callable(character_ref, "hide"))
	
	# Show random hand image
	show_random_hand_wave()


	
func show_random_hand_wave():
	var dir = DirAccess.open(hands_folder)
	if not dir:
		return
	
	var all_files: PackedStringArray = dir.get_files()
	var files := []  # normal Array to hold only real images
	for f in all_files:
		if not f.ends_with(".import"):
			files.append(f)
		if files.size() == 0:
			return

	
	var random_file = files[randi() % files.size()]
	var tex = load(hands_folder + random_file)
	if not tex:
		return
	
	# Create a temporary sprite
	var sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture = tex
	sprite.scale = Vector2(0.3, 0.3)  # 50% of original size
	sprite.modulate.a = 0.0
	sprite.position =  get_viewport_rect().size / 2
	hand_container.add_child(sprite)
	
	# Optional text
	var label = Label.new()
	label.text = random_file.split(".")[0]
	label.position = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/4)
	label.add_theme_color_override("font_color", Color.WHITE)
	hand_container.add_child(label)
	
	# Fade out and remove after animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 1.5)
	tween.tween_property(label, "modulate:a", 1.0, 1.5)
	
	tween.tween_interval(0.5)

	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(Callable(sprite, "queue_free"))
	tween.tween_callback(Callable(label, "queue_free"))	
	return tween
	
func restart_game():
	# Hide windows
	game_over_window.hide()
	info_window.hide()

	# Reset game state
	round = 0
	update_round_label()
	game_over = false
	state = 0
	win_round = 7
	alive_tags.clear()

	# Reset all characters
	for tag in characters.keys():
		var char_ref = characters[tag]
		char_ref.alive = true
		char_ref.show()

		# Disconnect old signals (if they exist)
		if char_ref.is_connected("clicked", Callable(self, "_on_character_clicked")):
			char_ref.disconnect("clicked", Callable(self, "_on_character_clicked"))

		# Reconnect signal
		char_ref.connect("clicked", Callable(self, "_on_character_clicked"))
		alive_tags.append(tag)

	# Reset all event "triggered" flags
	for ev in instant_lose_events:
		if ev.has("triggered"):
			ev["triggered"] = false

	for ev in saveable_lose_events:
		if ev.has("triggered"):
			ev["triggered"] = false

	for ev in state_change_events:
		if ev.has("triggered"):
			ev["triggered"] = false

	# Clear log
	log_panel.clear()
	add_log("Game restarted.")
