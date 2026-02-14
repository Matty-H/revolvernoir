extends Button

@onready var interface: Control = $"../../../.."
@onready var map: Control = $"../../../../Map_texture/Map"

func _on_pressed() -> void:
		# SÉCURITÉ ABSOLUE (Le Videur) :
	if interface.current_phase != interface.game_phase.TURN_RUNNING:
		print("Action refusée : La partie n'a pas encore commencé.")
		return
	if interface.active_player != interface.local_player:
		print("Action refusée : Ce n'est pas ton tour.")
		return
	listening.rpc()

@rpc("any_peer", "call_local", "reliable")
func listening():
	if interface.active_player.action_point_remaining >= 1:
		# La victime est l'autre joueur
		var victim = interface.opponent_player if interface.active_player == interface.local_player else interface.local_player
		
		if victim.position_player != "":
			var possible_noises = map.house[victim.position_player]
			interface.online_printer.rpc("Écoute : Bruit entendu vers " + str(possible_noises.pick_random()))
			
		interface.point_paywall(1)
	else:
		print("Pas assez de points d'action")
