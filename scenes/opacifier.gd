extends Control

@onready var opacifier: Control = $"."
@onready var label: Label = $Label

func _on_button_pressed() -> void:
	#opacifier.mouse_filter =  MOUSE_FILTER_IGNORE
	#opacifier.visible = false
	pop_up("x", 1)


func pop_up(text:String, time:float):
	opacifier.visible = true
	label.text = str(text)
	#il y a un bug ici quand l'adversaire gagne
	var cooldown = await get_tree().create_timer(time).timeout
	opacifier.visible = false
