extends Node2D

const CHARACTERS_JSON := "res://data/characters.json"
#const DEATH_EVENTS_JSON := "res://data/death_events.json"
const INSTANT_LOSE_EVENTS_JSON := "res://data/instant_lose_events.json"
const SAVEABLE_LOSE_EVENTS_JSON := "res://data/saveable_lose_events.json"
const STATE_CHANGE_EVENTS_JSON := "res://data/state_change_events.json"
#const TIMED_EVENTS_JSON := "res://data/timed_events.json"
const DEFAULT_SPRITE := "res://assets/sprites/default.png"
const Events = preload("res://scripts/events.gd")

var events = Events.new()

@onready var CharacterScene := preload("res://scenes/character.tscn")
@onready var info_window := $UI/CharacterInfoWindow
@onready var game_over_window := $UI/GameOverWindow
@onready var game_won_window := $UI/GameWonWindow

@onready var round_label := $UI/RoundLabel
@onready var log_panel := $UI/LogPanel

var characters: Dictionary = {}  
var alive_tags: Array = []
var round: int = 0
var win_round: int = 7
var state: int = 0
#var active_events: Array = []   
#var death_events: Array = []
#var timed_events: Array = []
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

	
#func load_events():
	#var f1 := FileAccess.open(DEATH_EVENTS_JSON, FileAccess.READ)
	#if f1:
		#var parsed: Variant = JSON.parse_string(f1.get_as_text())
		#if typeof(parsed) == TYPE_ARRAY:
			#death_events = parsed
			#
	#var f2 := FileAccess.open(TIMED_EVENTS_JSON, FileAccess.READ)
	#if f2:
		#var parsed: Variant = JSON.parse_string(f2.get_as_text())
		#if typeof(parsed) == TYPE_ARRAY:
			#timed_events = parsed
			#
			
			
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
	
	# Queue death-triggered events
	#for ev in state_change_events:
		#if ev.get("trigger", "") == character_ref.character_tag:
			#queue_event(ev)
			#
	# Queue timed events that start this round
	for ev in instant_lose_events:
		if events.evaluate_instant_lose_event(ev, alive_tags, state, round):
			trigger_game_over("You REALLY shouldn't have done that", ev.get("description", ""))
		
	for ev in saveable_lose_events:
		if events.evaluate_instant_lose_event(ev, alive_tags, state, round):
			if events.evaluate_saveable_event(ev, alive_tags):
				trigger_game_over("Oh no, if it isn't the consequences of your actions...", ev.get("lost_text", ""))
			else:
				add_log(ev.get("saved_text", ""))		
	
	for ev in state_change_events:
		if events.evaluate_state_changes(ev, alive_tags, state, round):
			win_round = win_round + (events.rounds - round)
			state = events.state
			add_log(ev.get("description", ""))
		
		
		#if ev.get("trigger_round", -1) == round:
			#queue_event(ev)
			#
	# After each death, evaluate active timed events
	#tick_events()
	if state > 3:
		trigger_game_over("You know there's such a thing as TOO much tension, right?", "Your travellers lost all faith in your leadership.. they decided its YOU who gets sacrificed next!")
	if round >= win_round:
		print("Round is "  + str(round))
		var alive_characters = []
		for tag in characters.keys():
			var char = characters[tag]
			if char.alive:
				alive_characters.append(char.character_name)

		trigger_game_won(alive_characters)
	
#func queue_event(event: Dictionary):
	#var new_event = event.duplicate(true)
	#new_event["remaining"] = event.get("timer", 0) + 1
	#active_events.append(new_event)
	#add_log("Event triggered: %s" % new_event.get("description", "No description"))
		#
#func tick_events():
	#var still_active: Array = []
	#for ev in active_events:
		#if ev["remaining"] > 0:
			#add_log("Ongoing event: %s (Remaining: %d rounds)" % [ev.get("description", "No description"), ev["remaining"] - 1] )
		#ev["remaining"] = int(ev.get("remaining", 0)) - 1
		#if ev["remaining"] <= 0:
			#evaluate_event(ev)
		#else:
			#still_active.append(ev)
	#active_events = still_active
	#
#func evaluate_event(ev: Dictionary):
	#var ev_type = ev.get("event_type", "")
	#var must_die: Array = ev.get("must_die", [])
	#var required_alive: Array = ev.get("required_alive", [])
	#var title: String = ev.get("title", "Unknown Event")
	#var description: String = ev.get("description", "No description")
	#var success_reason: String = ev.get("success_reason", "")
	#var failure_reason: String = ev.get("failure_reason", "Unknown Failure")
#
	#var event_failed = false
	#
	#match ev_type:
		#"upcoming_death":
			#if intersects(required_alive, alive_tags):
				#trigger_game_over(title, failure_reason)
		#"saveable_death":
			#if all_dead(must_die) and not intersects(required_alive, alive_tags):
				#trigger_game_over(title, failure_reason)
		#"upcoming_slowdown":
			#if intersects(required_alive, alive_tags):
				#add_log("Event succeeded: %s" % success_reason)
			#else:
				#add_log("Event failed: %s" % failure_reason)
				#event_failed = true
		#"saveable_slowdown":
			#if all_dead(must_die) and not intersects(required_alive, alive_tags):
				#add_log("Event succeeded: %s" % success_reason)
			#else:
				#add_log("Event failed: %s" % failure_reason)
				#event_failed = true
				#
	##TODO Add logic for event_failed = true to actually do something.
		#
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
	
func restart_game():
	# Hide windows
	game_over_window.hide()
	info_window.hide()
	
	# Reset game state
	round = 0
	update_round_label()
	
	#active_events.clear()
	#reload events is important !!! 
	alive_tags.clear()
	
	# Reset all characters
	for tag in characters.keys():
		var char_ref = characters[tag]
		char_ref.alive = true
		char_ref.show()
		
	# Repopulate alive_tags
	for tag in characters.keys():
		alive_tags.append(tag)
	
	# Clear log
	log_panel.clear()
	
	add_log("Game restarted.")
