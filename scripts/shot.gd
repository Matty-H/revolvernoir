extends Button

@onready var map: Control = $"../../../Map_texture/Map"
@onready var interface: Control = $"../../.."
@onready var shot: Button = $"."

@onready var player: Control = $"../../../Player"
@onready var opponent: Control = $"../../../Opponent"


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
	if start_firing():
		if not is_running:
			await start_aiming()
			await start_runing()
	else:
		print("No Action Points")
		return

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
	interface.action_stats_now = interface.action_stats.AIMING
	match interface.player_actif:
		player:
			for location in shooting_target:
				map.room_status[location] = "shot"
			shooting_target = await map.room_shooted
			interface.action_stats_now = interface.action_stats.RUNNING
		opponent:
			var fire = shooting_target[randi() % shooting_target.size()]
			shooting_target = fire


func start_runing():
	map.remove_icon("shot")
	shot.text = "Running"
	is_running = true
	interface.action_stats_now = interface.action_stats.RUNNING
	print("Fire: "+str(fire_place)+" >> "+str(shooting_target))
	interface.hit_verification(shooting_target)

	match interface.player_actif:
		player:
			for location in map.adjacent_locations:
				map.room_status[location] = "move"
			await map.room_fled
		opponent:
			var room_available = map.house[fire_place]
			interface.player_actif.position_player = room_available[randi() % room_available.size()]

	map.remove_icon("move")
	shot.text = "Shot"
	print("Mob fled")
	is_running = false
	interface.action_stats_now = interface.action_stats.FREE
	interface.point_paywall(2)

func cancel_shot():
	shot.text = "Shot"
	map.remove_icon("shot")
	interface.action_stats_now = interface.action_stats.FREE
