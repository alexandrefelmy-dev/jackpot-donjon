class_name Secousse
extends Node
## Le tremblement d'un écran : un « trauma » entre 0 et 1 qui monte à chaque impact et redescend tout seul ;
## la secousse visible est le trauma AU CARRÉ (les petits chocs bougent à peine, les gros claquent).
## Elle ne décale que l'AFFICHAGE de l'écran (offset_transform_position d'un Control : les conteneurs ne s'en
## occupent pas) : jamais la logique, jamais la mise en page. Elle décroît en temps réel : un arrêt sur image
## ne la fige donc pas de travers. Posée comme enfant de l'écran qui doit trembler.

const DECROISSANCE := 1.2
const DECALAGE_MAX := Vector2(12, 8)

var cible: Control
var trauma: float = 0.0
var _phase: float = 0.0


## Un impact de force `montant` (0 à 1). Sans effet si le joueur a réduit les tremblements.
func ajouter(montant: float) -> void:
	if Impacts.tremblements_reduits():
		return
	trauma = clampf(trauma + montant, 0.0, 1.0)


func _process(delta: float) -> void:
	if cible == null or not is_instance_valid(cible):
		return
	if trauma <= 0.0:
		return
	var delta_reel := delta / maxf(Engine.time_scale, 0.0001)
	trauma = maxf(trauma - DECROISSANCE * delta_reel, 0.0)
	_phase += delta_reel * 30.0
	var force := trauma * trauma
	# Des sinus de fréquences sans rapport entre elles : un mouvement lisse, jamais un grésillement.
	cible.offset_transform_enabled = true
	cible.offset_transform_position = Vector2(
			DECALAGE_MAX.x * force * sin(_phase * 1.7), DECALAGE_MAX.y * force * sin(_phase * 2.3))
	if trauma <= 0.0:
		cible.offset_transform_position = Vector2.ZERO
