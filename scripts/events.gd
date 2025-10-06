extends Node

const CHARACTERS_JSON := "res://data/characters.json"
const INSTANT_LOSE_EVENTS_JSON := "res://data/instant_lose_events.json"
const SAVEABLE_LOSE_EVENTS_JSON := "res://data/saveable_lose_events.json"
const STATE_CHANGE_EVENTS_JSON := "res://data/state_change_events.json"
const DEFAULT_SPRITE := "res://assets/sprites/Rower1.png"

@export var state_change_events: Array = []
@export var saveable_death_events: Array = []
@export var instant_death_events: Array = []
@export var rounds: int
@export var states: int

func load_events():
	var f1 := FileAccess.open(INSTANT_LOSE_EVENTS_JSON, FileAccess.READ)
	if f1:
		var parsed: Variant = JSON.parse_string(f1.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			instant_death_events = parsed
			
	var f2 := FileAccess.open(SAVEABLE_LOSE_EVENTS_JSON, FileAccess.READ)
	if f2:
		var parsed: Variant = JSON.parse_string(f2.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			saveable_death_events = parsed
	
	var f3 := FileAccess.open(STATE_CHANGE_EVENTS_JSON, FileAccess.READ)
	if f3:
		var parsed: Variant = JSON.parse_string(f3.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			state_change_events = parsed
			
func evaluate_condition(condition_str: String, characters: Array) -> bool:
	# Trim spaces and split into tokens
	var tokens = condition_str.strip_edges().split(" ")
	var unique_vars = []
	var boolean_operators = ["and", "or", "not"]

	# Collect only variable names (exclude boolean operators)
	for t in tokens:
		if t != "" and not boolean_operators.has(t) and not unique_vars.has(t):
			unique_vars.append(t)

	# Map variable names to their values (true if character exists)
	var values = []
	for var_name in unique_vars:
		values.append(characters.has(var_name))

	# Parse the expression
	var expr = Expression.new()
	var err = expr.parse(condition_str, unique_vars)
	if err != OK:
		print(condition_str)
		push_error("Failed to parse condition: %s" % condition_str)
		return false

	# Execute the expression
	var result = expr.execute(values)
	if expr.has_execute_failed():
		push_error("Failed to execute condition: %s" % condition_str)
		return false

	return result
	
func evaluate_instant_lose_event(ev: Dictionary, characters: Array, state: int, round: int):
	rounds = round
	state = state
	var triggered = ev.get("triggered", "")
	var trigger_state = ev.get("trigger_state", -1)
	var trigger_round = int(ev.get("trigger_round", -1))
	var condition = ev.get("condition", "")

	if triggered:
		return false
	
	if trigger_state != -1 and trigger_state != state:
		return false
		
	if trigger_round != -1 and trigger_round != round:
		return false
		
	if not condition == "" and not evaluate_condition(condition, characters):
		return false
	
	# The event is triggered	
	return true
	
	
func evaluate_saveable_event(ev: Dictionary, characters:Array):
	return evaluate_condition(ev.get("lose_condition", ""), characters)


func evaluate_state_changes(ev: Dictionary, characters: Array, state: int, round: int):
	rounds = round
	states = state
	var condition = ev.get("condition", "")
	var triggered = ev.get("triggered", "")
	var trigger_round = int(ev.get("trigger_round", -1))
	
	
	if triggered:
		return false
	if trigger_round != -1 and trigger_round != round:
		return false
	if not condition == "" and not evaluate_condition(condition, characters):
		return false
	
	states = states +  ev.get("state_change", "")	
	rounds = rounds +  ev.get("round_change", "")
	return true	
