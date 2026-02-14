extends Button

@onready var map: Control = $"../../../Map_texture/Map"
@onready var interface: Control = $"../../.."
@onready var shot: Button = $"."



var shooting_target
var fire_place
var is_running

var target = {
	#1st Floor
	"balcony": ["balcony", "corridor", "hall", "kitchen", "dining_room"],
	"library": ["library", "corridor", "balcony"],
	"corridor": [ "corridor", "balcony", "bedroom", "library"],
	"bedroom": [ "bedroom", "corridor", "balcony"],
	#Ground Floor
	"hall": ["hall", "dining_room", "kitchen"],
	"kitchen": ["kitchen", "hall", "dining_room"],
	"dining_room": ["dining_room", "hall", "kitchen"],
	#Basement
	"basement": ["basement", "hall", "dining_room"],
	}


func _on_pressed() -> void:
	if shot.text == "Cancel":
		cancel_shot()
		return
	firing()

func firing():
	if interface.player_actif.action_point_remaining < 2:
		print("No Action Points")
		return

	if not is_running:
		await start_aiming()
		# After aiming, we have a shooting_target
		if shooting_target:
			await start_runing()

func start_firing() -> bool:
	fire_place = interface.player_actif.position_player
	shooting_target = target[fire_place]
	if interface.player_actif.action_point_remaining >= 2:
		return true
	else:
		return false
		
func start_aiming():
	shot.text = "Cancel"
	fire_place = interface.player_actif.position_player
	shooting_target = target[fire_place]
	interface.action_stats_now = interface.action_stats.AIMING

	if interface.player_actif.is_local:
		for location in shooting_target:
			map.room_status[location] = "shot"
		shooting_target = await map.room_shooted
	else:
		# Should not happen on client for remote player
		pass

func start_runing():
	map.remove_icon("shot")
	shot.text = "Running"
	is_running = true
	interface.action_stats_now = interface.action_stats.RUNNING

	# Request server to execute the shot and movement
	request_shot_and_flee.rpc_id(1, shooting_target)

	# Wait for server to process? For now let's assume it's fast.
	# But we need the flee room if it's local.
	var flee_room = ""
	if interface.player_actif.is_local:
		for location in map.adjacent_locations:
			map.room_status[location] = "move"
		flee_room = await map.room_fled
		request_flee_move.rpc_id(1, flee_room)

	map.remove_icon("move")
	shot.text = "Shot"
	is_running = false
	interface.action_stats_now = interface.action_stats.FREE

@rpc("any_peer", "call_local", "reliable")
func request_shot_and_flee(target_room: String):
	if not multiplayer.is_server(): return
	var player = interface.player_actif
	if player.action_point_remaining >= 2:
		interface.online_printer.rpc(player.player_name + " fires at " + target_room)
		interface.hit_verification(target_room)
		# AP will be deducted after flee move

@rpc("any_peer", "call_local", "reliable")
func request_flee_move(room: String):
	if not multiplayer.is_server(): return
	var player = interface.player_actif
	var adjacent = map.house[player.position_player]
	if adjacent.has(room):
		player.position_player = room
		interface.point_paywall(2)

func cancel_shot():
	shot.text = "Shot"
	map.remove_icon("shot")
	interface.action_stats_now = interface.action_stats.FREE
