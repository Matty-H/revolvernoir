extends Control

@onready var label: Label = $VBoxContainer/Label

func _process(delta: float) -> void:
	#label.text = get_tree().interface.winner_score.gd.winner
	pass

func _on_replay_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/interface.tscn")


func _on_title_screen_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
