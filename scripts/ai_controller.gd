extends Node
class_name AIController

var player: GamePlayer
var interface
var map

func _ready():
	player = get_parent()
	interface = get_tree().root.find_child("Interface", true, false)
	map = interface.map
	interface.game_manager.turn_started.connect(_on_turn_started)

func _on_turn_started(active_player):
	if active_player == player and player.is_ai and multiplayer.is_server():
		execute_ai_turn()

func execute_ai_turn():
	print("AI Turn starting...")
	while player.action_point_remaining > 0:
		await get_tree().create_timer(1.0).timeout
		var random_play = randi_range(0, 3)
		match random_play:
			0: # MOVE
				var adjacent = map.house[player.position_player]
				var room = adjacent.pick_random()
				map.request_move(room)
			1: # LISTEN
				interface.find_child("Listen", true, false).request_listening()
			2: # TRAP (simplification for now)
				player.action_point_remaining -= 1
			3: # SHOOT
				if player.action_point_remaining >= 2:
					var targets = interface.find_child("Shot", true, false).target[player.position_player]
					var target_room = targets.pick_random()
					var flee_rooms = map.house[player.position_player]
					var flee_room = flee_rooms.pick_random()

					var shot_node = interface.find_child("Shot", true, false)
					shot_node.request_shot_and_flee(target_room)
					shot_node.request_flee_move(flee_room)

		if player.action_point_remaining <= 0:
			break
