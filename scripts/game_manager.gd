extends Node
class_name GameManager

enum GamePhase { INITIALISATION, PLAYER1_TURN, PLAYER2_TURN, GAME_OVER }
var current_phase: GamePhase = GamePhase.INITIALISATION

@onready var interface = get_parent()
@onready var server = get_tree().root.find_child("Server", true, false)

var player1: GamePlayer
var player2: GamePlayer

var player_actif: GamePlayer
var player_non_actif: GamePlayer
var players_ready_to_start: int = 0
var stored_first_player_index: int = 0

signal phase_changed(new_phase)
signal turn_started(player)

func _ready():
	player1 = interface.get_node("Player1")
	player2 = interface.get_node("Player2")

func start_game():
	if multiplayer.is_server():
		setup_game.rpc(randi() % 2)

@rpc("authority", "call_local", "reliable")
func setup_game(first_player_index: int):
	stored_first_player_index = first_player_index
	# Identify local player
	var my_id = server.room_info.id_machine
	player1.is_local = (my_id == 1)
	player2.is_local = (my_id == 2)

	if server.is_opponent_computer:
		player2.is_ai = true
		player2.is_local = false
		if multiplayer.is_server():
			var ai = Node.new()
			ai.name = "AIController"
			ai.set_script(load("res://scripts/ai_controller.gd"))
			player2.add_child(ai)

	choose_initial_positions()

func choose_initial_positions():
	interface.online_printer.rpc("Choosing initial positions...")
	var my_player = player1 if player1.is_local else (player2 if player2.is_local else null)

	if my_player:
		await interface.interactive_choose_position(my_player)
		request_initial_position.rpc_id(1, my_player.position_player)
	elif multiplayer.is_server() and player2.is_ai:
		# Server handles both if VS computer
		player1.set_position_player_auto()
		player2.set_position_player_auto()
		players_ready_to_start = 1 # Consider AI done
		_check_start()

@rpc("any_peer", "call_local", "reliable")
func request_initial_position(room: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()

	# In this game, Host is always Machine 1, Guest is always Machine 2
	# For simplicity, we can use the machine_id from the sender's room_info if we had it,
	# but we know 1/0 is host.
	if sender_id == 1 or sender_id == 0:
		player1.position_player = room
	else:
		player2.position_player = room

	players_ready_to_start += 1
	_check_start()

func _check_start():
	var needed = 1 if server.is_opponent_computer else 2
	if players_ready_to_start >= needed:
		if stored_first_player_index == 0:
			start_turn(player1)
		else:
			start_turn(player2)

func start_turn(player: GamePlayer):
	player_actif = player
	player_non_actif = (player2 if player == player1 else player1)

	if player == player1:
		current_phase = GamePhase.PLAYER1_TURN
	else:
		current_phase = GamePhase.PLAYER2_TURN

	player_actif.action_point_remaining = 2
	phase_changed.emit(current_phase)
	turn_started.emit(player_actif)

	interface.online_printer.rpc("Turn started for " + player_actif.player_name)

func next_turn():
	if not multiplayer.is_server(): return

	basement_flood_check()
	interface.action_buttons.trap_countdown()

	if player_actif == player1:
		start_turn(player2)
	else:
		start_turn(player1)

func basement_flood_check():
	if interface.map.basement_flood > 0:
		interface.map.basement_flood -= 1
		interface.online_printer.rpc("Flood level: " + str(interface.map.basement_flood))
		if interface.hit_verification("basement"):
			interface.online_printer.rpc("Sploosh! Basement flood hit.")

func check_win_condition():
	if player_non_actif.life <= 0:
		interface.online_printer.rpc(player_actif.player_name + " won!")
		current_phase = GamePhase.GAME_OVER
		phase_changed.emit(current_phase)
		return true
	return false
