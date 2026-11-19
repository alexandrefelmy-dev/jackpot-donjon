class_name Musique
extends RefCounted
## La musique : une boucle par étage, une musique de boss, avec un fondu enchaîné entre deux pistes.
## Deux lecteurs posés sur la racine de l'arbre (ils survivent aux changements d'écran) : la musique
## continue d'un écran à l'autre, et ne redémarre que si la piste change. Pistes dans data/musiques.tres.

const TABLE := "res://data/musiques.tres"
const FONDU := 1.5

## La piste en cours (&"" = silence).
static var piste_courante: StringName = &""
static var _table: TableSons
static var _lecteur_actuel: AudioStreamPlayer
static var _lecteur_ancien: AudioStreamPlayer
static var _fondu: Tween


## La piste qui accompagne un étage (1 à 3) ou son boss. Le menu et le Comptoir jouent celle de l'étage 1.
static func piste_pour(etage: int, boss: bool) -> StringName:
	if boss:
		return &"boss"
	return StringName("etage_%d" % clampi(etage, 1, 3))


## La musique de la partie en cours : la piste de son étage, ou celle du boss pendant un combat de boss.
static func jouer_pour(partie: Partie) -> void:
	jouer(piste_pour(partie.etage, partie.est_combat_de_boss()))


## Joue la piste (si ce n'est pas déjà elle), avec un fondu enchaîné. Une piste sans fichier : silence.
static func jouer(piste: StringName, duree_fondu: float = FONDU) -> void:
	if piste == piste_courante:
		return
	if _table == null:
		_table = load(TABLE) as TableSons
	var chemins := _table.chemins(piste) if _table != null else ([] as Array[String])
	var flux: AudioStream = null
	if not chemins.is_empty() and ResourceLoader.exists(chemins[0]):
		flux = load(chemins[0]) as AudioStream
	jouer_flux(piste, flux, duree_fondu)


## Comme jouer(), avec le son déjà chargé (pour les tests). `flux` null = silence.
static func jouer_flux(piste: StringName, flux: AudioStream, duree_fondu: float = FONDU) -> void:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null or arbre.root == null:
		return
	Son.preparer_bus()
	piste_courante = piste
	_preparer_lecteurs(arbre)
	if _fondu != null:
		_fondu.kill()
	# L'ancienne piste finit de s'éteindre ; la nouvelle (s'il y en a une) monte.
	var sortant := _lecteur_actuel
	var entrant := _lecteur_ancien
	_lecteur_actuel = entrant
	_lecteur_ancien = sortant
	_fondu = arbre.create_tween().set_parallel(true)
	_fondu.tween_property(sortant, "volume_linear", 0.0, maxf(duree_fondu, 0.01))
	if flux != null:
		if "loop" in flux:
			flux.loop = true
		entrant.stream = flux
		entrant.volume_linear = 0.0
		entrant.play()
		_fondu.tween_property(entrant, "volume_linear", 1.0, maxf(duree_fondu, 0.01))
	_fondu.chain().tween_callback(sortant.stop)


## Lâche toutes les références (à la fermeture du jeu).
static func liberer() -> void:
	if _fondu != null:
		_fondu.kill()
	_fondu = null
	_table = null
	# Un lecteur qui joue garde sa piste en mémoire : on l'arrête et on lui retire son flux.
	for lecteur in [_lecteur_actuel, _lecteur_ancien]:
		if lecteur != null and is_instance_valid(lecteur):
			lecteur.stop()
			lecteur.stream = null
	_lecteur_actuel = null
	_lecteur_ancien = null
	piste_courante = &""


static func lecteurs() -> Array[AudioStreamPlayer]:
	var liste: Array[AudioStreamPlayer] = []
	if _lecteur_actuel != null:
		liste.append(_lecteur_actuel)
		liste.append(_lecteur_ancien)
	return liste


static func _preparer_lecteurs(arbre: SceneTree) -> void:
	if _lecteur_actuel != null and is_instance_valid(_lecteur_actuel):
		return
	_lecteur_actuel = AudioStreamPlayer.new()
	_lecteur_ancien = AudioStreamPlayer.new()
	for lecteur in [_lecteur_actuel, _lecteur_ancien]:
		lecteur.bus = Son.BUS_MUSIQUE
		arbre.root.add_child(lecteur)
