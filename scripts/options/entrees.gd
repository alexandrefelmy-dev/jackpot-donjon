class_name Entrees
extends RefCounted
## Les actions du jeu (levier, retour), enregistrées par le code au démarrage : project.godot n'est pas
## modifié à la main (l'éditeur ouvert le réécrirait). Le jeu se joue à la souris ; ces actions sont des
## raccourcis, au clavier comme à la manette.

const LEVIER := &"levier"
const RETOUR := &"retour"


## Ajoute les actions si elles n'existent pas encore (sans effet si on le rappelle).
static func enregistrer() -> void:
	_ajouter(LEVIER, [_touche(KEY_SPACE), _touche(KEY_ENTER), _touche(KEY_KP_ENTER), _bouton(JOY_BUTTON_A)])
	_ajouter(RETOUR, [_touche(KEY_ESCAPE), _bouton(JOY_BUTTON_B)])


static func _ajouter(action: StringName, evenements: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for evenement in evenements:
		InputMap.action_add_event(action, evenement)


## Une touche repérée par sa POSITION sur le clavier (pas par sa lettre : elle suit les claviers AZERTY ou QWERTY).
static func _touche(code: Key) -> InputEventKey:
	var evenement := InputEventKey.new()
	evenement.physical_keycode = code
	return evenement


## Un bouton de manette, quelle que soit la manette (device -1 = toutes).
static func _bouton(index: JoyButton) -> InputEventJoypadButton:
	var evenement := InputEventJoypadButton.new()
	evenement.button_index = index
	evenement.device = -1
	return evenement
