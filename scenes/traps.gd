extends VBoxContainer

@onready var map: Control = $"../../../../Map_texture/Map"
@onready var trap_1: Button = $Trap_1
@onready var trap_2: Button = $Trap_2
@onready var interface: Control = $"../../../.."



func trap_checker(x):
	if not interface.player_actif.is_local: return

	request_trap_action.rpc_id(1, x)

@rpc("any_peer", "call_local", "reliable")
func request_trap_action(x: int):
	if not multiplayer.is_server(): return

	var player = interface.player_actif
	if player.action_point_remaining < 1: return

	if x == 1:
		if player.trap_1:
			blow_up(x)
		else:
			setup_trap(x)
	elif x == 2:
		if player.trap_2:
			blow_up(x)
		else:
			setup_trap(x)

func setup_trap(x):
	var player = interface.player_actif
	if x == 1:
		player.trap_1 = player.position_player
		update_trap_labels.rpc(1, player.trap_1)
	else:
		player.trap_2 = player.position_player
		update_trap_labels.rpc(2, player.trap_2)

	interface.online_printer.rpc(player.player_name + " placed a trap")
	interface.point_paywall(1)

func blow_up(x):
	var player = interface.player_actif
	var room = ""
	if x == 1:
		room = player.trap_1
		player.trap_1 = null
		update_trap_labels.rpc(1, "")
	else:
		room = player.trap_2
		player.trap_2 = null
		update_trap_labels.rpc(2, "")

	interface.online_printer.rpc(player.player_name + " blew up trap in " + room)
	interface.hit_verification(room)
	interface.point_paywall(1)

@rpc("authority", "call_local", "reliable")
func update_trap_labels(slot: int, room: String):
	# Only update if it's our trap or if we are the server
	var player = interface.player_actif
	if not player.is_local and not multiplayer.is_server(): return

	if slot == 1:
		trap_1.text = (room + " ready!") if room != "" else "Trap 1"
	else:
		trap_2.text = (room + " ready!") if room != "" else "Trap 2"

func _on_trap_1_pressed() -> void:
	trap_checker(1)

func _on_trap_2_pressed() -> void:
	trap_checker(2)
