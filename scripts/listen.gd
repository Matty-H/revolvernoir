extends Button

@onready var interface: Control = $"../../../.."
@onready var map: Control = $"../../../../Map_texture/Map"


func _on_pressed() -> void:
	if interface.player_actif.is_local:
		request_listening.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func request_listening():
	if not multiplayer.is_server(): return

	if interface.player_actif.action_point_remaining >= 1:
		var info = "Listening: " + str(map.house[interface.player_non_actif.position_player].pick_random())
		interface.online_printer.rpc(info)
		interface.point_paywall(1)
	else:
		interface.online_printer.rpc_id(multiplayer.get_remote_sender_id(), "No Action Points")
