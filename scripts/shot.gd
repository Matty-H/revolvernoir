extends Button

@onready var map: Control = $"../../../Map_texture/Map"
@onready var interface: Control = $"../../.."
@onready var shot: Button = $"."

var shooting_target
var fire_place
var is_running

var target = {
	"balcony": ["balcony", "corridor", "hall", "kitchen", "dining_room"],
	"library": ["library", "corridor", "balcony"],
	"corridor": [ "corridor", "balcony", "bedroom", "library"],
	"bedroom": [ "bedroom", "corridor", "balcony"],
	"hall": ["hall", "dining_room", "kitchen"],
	"kitchen": ["kitchen", "hall", "dining_room"],
	"dining_room": ["dining_room", "hall", "kitchen"],
	"basement": ["basement", "hall", "dining_room"],
}

func _on_pressed() -> void:
	# SÉCURITÉ ABSOLUE (Le Videur) :
	if interface.current_phase != interface.game_phase.TURN_RUNNING:
		print("Action refusée : La partie n'a pas encore commencé.")
		return
	if interface.active_player != interface.local_player:
		print("Action refusée : Ce n'est pas ton tour.")
		return
	
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
		print("Pas assez de points d'action")

func start_firing() -> bool:
	fire_place = interface.local_player.position_player
	shooting_target = target[fire_place]
	return interface.local_player.action_point_remaining >= 2
		
func start_aiming():
	shot.text = "Cancel"
	fire_place = interface.local_player.position_player
	interface.action_stats_now = interface.action_stats.AIMING
	
	for location in shooting_target:
		map.room_status[location] = "shot"
		
	# On attend que le joueur clique sur une salle (géré par map.gd)
	shooting_target = await map.room_shooted
	interface.action_stats_now = interface.action_stats.RUNNING

func start_runing():
	map.remove_icon("shot")
	shot.text = "Running"
	is_running = true
	interface.action_stats_now = interface.action_stats.RUNNING
	
	interface.online_printer.rpc("Tir : de " + str(fire_place) + " vers " + str(shooting_target))
	interface.hit_verification(shooting_target)

	# Fausse piste : Le tireur doit s'enfuir
	for location in map.adjacent_locations:
		map.room_status[location] = "move"
	
	await map.room_fled

	map.remove_icon("move")
	shot.text = "Shot"
	interface.online_printer.rpc("Le tireur a fui")
	is_running = false
	interface.action_stats_now = interface.action_stats.FREE
	interface.point_paywall(2)

func cancel_shot():
	shot.text = "Shot"
	map.remove_icon("shot")
	interface.action_stats_now = interface.action_stats.FREE
