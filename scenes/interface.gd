extends Control

@onready var player1: GamePlayer = $Player1
@onready var player2: GamePlayer = $Player2
@onready var game_manager: GameManager = $GameManager
@onready var map: Control = $Map_texture/Map
@onready var action_buttons: VBoxContainer = $UI/Action_Buttons
@onready var overlay: Control = $Overlay
@onready var console_log: RichTextLabel = $UI/Labels/consoleLog
@onready var server: Node = get_tree().root.find_child("Server", true, false)

signal winner(winner_player)

var ok : bool = false # Backwards compatibility for map.gd

enum action_stats {FREE,AIMING,TRAP,RUNNING}
var action_stats_now = action_stats.FREE

var player_actif: GamePlayer:
	get: return game_manager.player_actif
var current_phase: int:
	get: return game_manager.current_phase

func _ready() -> void:
	game_manager.phase_changed.connect(_on_phase_changed)
	if multiplayer.is_server():
		game_manager.start_game()
 
func _on_phase_changed(new_phase):
	match new_phase:
		GameManager.GamePhase.PLAYER1_TURN, GameManager.GamePhase.PLAYER2_TURN:
			action_buttons.visible = game_manager.player_actif.is_local
			if game_manager.player_actif.is_local:
				pop_up("C'est votre tour !", 1)
			else:
				pop_up("Tour de l'adversaire", 1)
		GameManager.GamePhase.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func interactive_choose_position(game_player: GamePlayer):
	map.set_icon("move")
	var room = await map.button_selected
	game_player.move_to(room)
	map.set_icon("null")

func point_paywall(pts):
	if not multiplayer.is_server():
		# Request server to spend AP
		return
		
	action_buttons.start_kitchen = false
	game_manager.player_actif.action_point_remaining -= pts
	if game_manager.player_actif.action_point_remaining <= 0:
		game_manager.next_turn()

func hit_verification(x):
	if dealing_hit(x):
		game_manager.check_win_condition()
		return true
	return false

func dealing_hit(x):
	if x == game_manager.player_non_actif.position_player:
		game_manager.player_non_actif.life -= 1
		online_printer.rpc("HIT")
		return true
	else:
		return false

var print_line : int = 0
@rpc("any_peer", "call_local", "reliable")
func online_printer(printing_paper):
	print(str("(" + str(server.room_info.id_machine)) + ") " + printing_paper)
	print_line += 1
	console_log.text += str(print_line) + "/ " + printing_paper + "\n"

func pop_up(message : String, timer : int):
	overlay.get_node("opacifier").pop_up(message, timer)
