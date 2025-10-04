extends Node2D

const CHARACTERS_JSON := "res://data/characters.json"
const DEATH_EVENTS_JSON := "res://data/death_events.json"
const TIMED_EVENTS_JSON := "res://data/timed_events.json"
const DEFAULT_SPRITE := "res://assets/sprites/default.png"

@onready var CharacterScene := preload("res://scenes/character.tscn")
@onready var info_window := $UI/CharacterInfoWindow
@onready var game_over_window := $UI/GameOverWindow
@onready var round_label := $UI/RoundLabel
@onready var log_panel := $UI/LogPanel

var characters: Dictionary = {}  
var alive_tags: Array = []
var round: int = 0
var active_events: Array = []   
var death_events: Array = []
var timed_events: Array = []
var game_over: bool = false

func _ready():
	load_events()
	load_characters()
	update_round_label()

func load_events():
	var f1 := FileAccess.open(DEATH_EVENTS_JSON, FileAccess.READ)
	if f1:
		var parsed: Variant = JSON.parse_string(f1.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			death_events = parsed

	var f2 := FileAccess.open(TIMED_EVENTS_JSON, FileAccess.READ)
	if f2:
		var parsed: Variant = JSON.parse_string(f2.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			timed_events = parsed

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
	
	character.character_name = char_data.get("name", "Unknown")
	character.character_tag = char_data.get("tag", "")
	character.age = char_data.get("age", 0)
	character.occupation = char_data.get("occupation", "")
	character.description = char_data.get("description", "")
	
	var sprite_path = char_data.get("sprite", DEFAULT_SPRITE)
	if not ResourceLoader.exists(sprite_path):
		sprite_path = DEFAULT_SPRITE
	
	var tex := load(sprite_path)
	if tex and character.has_node("Sprite2D"):
		character.get_node("Sprite2D").texture = tex
	
	character.position = Vector2(char_data.get("x", 0), char_data.get("y", 0))
	character.connect("clicked", Callable(self, "_on_character_clicked"))
	
	$CharacterRows.add_child(character)
	characters[character.character_tag] = character
	alive_tags.append(character.character_tag)

func _on_character_clicked(character_ref):
	if not game_over:
		info_window.show_character(character_ref, Callable(self, "_on_character_killed"))

func _on_character_killed(character_ref):
	if game_over or not character_ref.alive:
		return

	character_ref.alive = false
	character_ref.hide()
	alive_tags.erase(character_ref.character_tag)

	round += 1
	update_round_label()
	add_log("Round %d: %s was killed" % [round, character_ref.character_name])
	
	for ev in death_events:
		if ev.get("trigger", "") == character_ref.character_tag:
			queue_event(ev)

	for ev in timed_events:
		if ev.get("trigger_round", -1) == round:
			queue_event(ev)

	tick_events()

func queue_event(event: Dictionary):
	var new_event = event.duplicate(true)
	new_event["remaining"] = event.get("timer", 0)
	active_events.append(new_event)
	add_log("Event queued: %s" % new_event.get("reason", ""))

func tick_events():
	var still_active: Array = []
	for ev in active_events:
		ev["remaining"] = int(ev.get("remaining", 0)) - 1
		if ev["remaining"] <= 0:
			evaluate_event(ev)
		else:
			still_active.append(ev)
	active_events = still_active

func evaluate_event(ev: Dictionary):
	var ev_type = ev.get("event_type", "")
	var must_die: Array = ev.get("must_die", [])
	var required_alive: Array = ev.get("required_alive", [])
	var reason: String = ev.get("reason", "Unknown")

	match ev_type:
		"upcoming_death":
			if intersects(required_alive, alive_tags):
				trigger_game_over(reason)
		"saveable_death":
			if all_dead(must_die) and not intersects(required_alive, alive_tags):
				trigger_game_over(reason)
		"upcoming_slowdown":
			if intersects(required_alive, alive_tags):
				add_log("Slowdown occurred: %s" % reason)
		"saveable_slowdown":
			if all_dead(must_die) and not intersects(required_alive, alive_tags):
				add_log("Slowdown occurred: %s" % reason)

func trigger_game_over(reason: String):
	game_over = true
	game_over_window.show_game_over(reason)


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
	
