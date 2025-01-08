extends Button

@onready var interface: Control = $"../../../.."
@onready var map: Control = $"../../../../Map_texture/Map"


func _on_pressed() -> void:
	listening.rpc()

@rpc("any_peer", "call_local", "reliable")
func listening():
	if interface.player_actif.action_point_remaining >= 1:
		print("Listening: "+ str(map.house[interface.player_non_actif.position_player].pick_random()))
		interface.point_paywall(1)
	else:
		print("No Action Points")
