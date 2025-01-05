extends Control

@onready var player: Control = $Player
@onready var opponent: Control = $Opponent
@onready var map: Control = $Map_texture/Map
@onready var action_buttons: VBoxContainer = $UI/Action_Buttons
@onready var overlay: Control = $Overlay
@onready var console_log: RichTextLabel = $UI/Labels/consoleLog

signal player_turn
signal opponent_turn
signal winner(winner)

enum game_phase {INITIALISATION, player_TURN, opponent_TURN, GAME_OVER}
var current_phase: game_phase = game_phase.INITIALISATION

var player_actif
var player_non_actif

enum action_stats {FREE,AIMING,TRAP,RUNNING}
var action_stats_now = action_stats.FREE

func _ready() -> void:
	choosing_first_player()
	await begin_turn()
 
func _process(delta: float) -> void:
	match current_phase:
		game_phase.INITIALISATION:
			pass
		game_phase.player_TURN:
			UI_visbible()
		game_phase.opponent_TURN:
			UI_visbible()
		game_phase.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/game_over.tscn")
			pass


func choosing_first_player():
	current_phase = game_phase.INITIALISATION
	action_buttons.visible = false
	var random_first_player = randi_range(0,1)
	#var random_first_player = 0

	match random_first_player:
		0:
			online_printer.rpc("Human start")
			player_actif = player
			player_non_actif = opponent
		1:
			online_printer.rpc("Computer start")
			player_actif = opponent
			player_non_actif = player

func UI_visbible():
	action_buttons.visible = true


func begin_turn():
	online_printer.rpc("=== P1 PICK A ROOM ===")
	player.set_position_player()
	await pop_up("Choisissez une salle", 1)
	await player.room_selected
	
	online_printer.rpc("=== P2 PICK A ROOM ===")
	opponent.set_position_player()
	await pop_up("L'adversaire choisi une salle", 1)
	#await opponent.room_selected
	
	if player_actif == player:
		current_phase = game_phase.player_TURN
	else:
		current_phase = game_phase.opponent_TURN
		opponent_turn.emit()
	action_buttons.start_kitchen = true
	online_printer.rpc("=== PLAYER 1 TURN ===")

func point_paywall(pts):
	action_buttons.start_kitchen = false
	player_actif.action_point_remaining -= pts
	if player_actif.action_point_remaining <= 0:
		player_non_actif.action_point_remaining = 2
		switch_turn()

func basement_flood_check():
	online_printer.rpc("Flood: "+str(map.basement_flood))
	if map.basement_flood > 0:
		map.basement_flood -= 1
		if hit_verification("basement"):
			online_printer.rpc("blop blop")
			basement_relocalisation()
			return
		else:
			online_printer.rpc("pas procédure relocalisation")
		

func switch_turn() -> void:
	basement_flood_check()
	if current_phase == game_phase.player_TURN:
		online_printer.rpc("=== PLAYER 2 TURN ===")
		await pop_up("Changement de tour", 0.5)

		current_phase = game_phase.opponent_TURN
		player_actif = opponent
		player_non_actif = player
		opponent_turn.emit()
		
	elif current_phase == game_phase.opponent_TURN:
		online_printer.rpc("=== PLAYER 1 TURN ===")
		await pop_up("Changement de tour", 0.5)
		
		current_phase = game_phase.player_TURN
		player_actif = player
		player_non_actif = opponent
		player_turn.emit()
		
	action_buttons.trap_countdown()
	if player_actif.position_player == "kitchen":
		action_buttons.start_kitchen = true
	else:
		action_buttons.start_kitchen = false


func basement_relocalisation():
	var rooms_list = map.house["basement"]
	match player_actif:
		player:
			pass
		opponent:
			player_actif.position_player = rooms_list[randi() % rooms_list.size()]
			online_printer.rpc("P2 fled into "+str(player_actif.position_player))
			player_actif.room_selected.emit()

func hit_verification(x):
	if dealing_hit(x):
		win_condition()
		return true

func dealing_hit(x):
	if x == player_non_actif.position_player:
		player_non_actif.life -= 1
		online_printer.rpc("HIT")
		return true
	else:
		return false

func win_condition():
	if player_non_actif.life <= 0:
		online_printer.rpc(str(player_actif.get_name())+" won!")
		current_phase == game_phase.GAME_OVER
		#get_tree().root.winner_score.winner = player_actif
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")

var print_line : int = 0
@rpc("any_peer", "call_local", "reliable")
func online_printer(printing_paper):
	print(printing_paper)
	print_line += 1
	console_log.text += str(print_line) + "/ " + printing_paper + "\n"

func pop_up(message : String, timer : int):
	overlay.get_node("opacifier").pop_up(message, timer)
