extends Control

@onready var label: Label = $Label

# On stocke le timer actuel pour pouvoir l'annuler si un nouveau pop-up arrive
var popup_tween: Tween 

func _ready() -> void:
	visible = false

func _on_button_pressed() -> void:
	pop_up("Test de pop-up", 1.0)

func pop_up(text: String, time: float) -> void:
	# 1. On affiche et on met le texte
	visible = true
	label.text = text
	
	# 2. Si un ancien pop-up était encore en train de s'afficher, on l'annule
	if popup_tween and popup_tween.is_valid():
		popup_tween.kill()
		
	# 3. On crée un nouveau Tween lié à ce nœud
	popup_tween = create_tween()
	
	# 4. On lui dit d'attendre X secondes...
	popup_tween.tween_interval(time)
	
	# 5. ...puis de se cacher automatiquement !
	# (Si le nœud est détruit entre-temps, cette ligne ne s'exécutera simplement pas. Zéro crash !)
	popup_tween.tween_callback(func(): visible = false)
	
