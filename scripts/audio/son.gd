class_name Son
extends RefCounted
## Les effets sonores du jeu. Deux bus créés par le code (Musique, Effets), des curseurs de volume qui
## règlent leur gain, et jouer(événement) qui tire une variante dans data/sons.tres avec un petit
## décalage de hauteur. Aucun son ne joue sur Master : tout passe par un bus nommé.
## Un événement sans fichier ne fait rien (et ne plante jamais) : on peut brancher les sons avant d'avoir les fichiers.

const BUS_MUSIQUE := &"Musique"
const BUS_EFFETS := &"Effets"
const TABLE := "res://data/sons.tres"
## Tous les événements sonores du jeu : chacun doit avoir au moins un fichier dans la table (testé).
const EVENEMENTS: Array[StringName] = [
	&"rouleaux", &"arret_rouleau", &"ding", &"jackpot", &"coup_donne", &"coup_recu", &"bouclier",
	&"soin", &"pieces", &"bombe", &"achat", &"relique", &"clic", &"victoire", &"defaite",
]
## Nombre de lecteurs partagés : au plus autant de sons en même temps (les plus anciens sont coupés).
const NB_LECTEURS := 10
## Décalage aléatoire de hauteur (± 6 %) pour que les sons répétés ne sonnent pas en machine à écrire.
const VARIATION_HAUTEUR := 0.06

static var _table: TableSons
static var _flux: Dictionary = {}
static var _lecteurs: Array[AudioStreamPlayer] = []
static var _suivant: int = 0
static var _hasard := RandomNumberGenerator.new()


## Crée les bus Musique et Effets s'ils n'existent pas (renvoyés à Master). Sans effet si on le rappelle.
static func preparer_bus() -> void:
	for nom in [BUS_MUSIQUE, BUS_EFFETS]:
		if AudioServer.get_bus_index(nom) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, nom)
			AudioServer.set_bus_send(index, &"Master")


## Le gain (linéaire, 0 à 1) d'un curseur de volume : le curseur est élevé au carré, ce qui répartit le
## changement entendu sur toute la course (un curseur linéaire ne change presque rien avant le dernier quart).
static func gain_du_curseur(curseur: float) -> float:
	var valeur := clampf(curseur, 0.0, 1.0)
	return valeur * valeur


## Règle le volume d'un bus d'après un curseur de 0 à 1 (0 = coupé, vraiment).
static func regler_volume(bus: StringName, curseur: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_error("Aucun bus audio nommé %s" % bus)
		return
	AudioServer.set_bus_mute(index, curseur <= 0.0)
	if curseur > 0.0:
		AudioServer.set_bus_volume_linear(index, gain_du_curseur(curseur))


## Applique les volumes des options aux deux bus.
static func appliquer_options(options: Options) -> void:
	preparer_bus()
	regler_volume(BUS_MUSIQUE, options.volume_musique)
	regler_volume(BUS_EFFETS, options.volume_effets)


## Joue un événement (une variante au hasard). Renvoie faux s'il n'a aucun fichier utilisable.
static func jouer(evenement: StringName, hauteur: float = 1.0) -> bool:
	if _table == null:
		_table = load(TABLE) as TableSons
	if _table == null:
		return false
	var chemins := _table.chemins(evenement)
	if chemins.is_empty():
		return false
	var chemin := chemins[_hasard.randi_range(0, chemins.size() - 1)]
	return jouer_flux(_charger(chemin), hauteur)


## Joue un son déjà chargé sur le bus Effets, avec une variation de hauteur. Renvoie faux si impossible.
static func jouer_flux(flux: AudioStream, hauteur: float = 1.0) -> bool:
	if flux == null:
		return false
	var lecteur := _lecteur_suivant()
	if lecteur == null:
		return false
	lecteur.stream = flux
	lecteur.pitch_scale = maxf(0.1, hauteur * _hasard.randf_range(1.0 - VARIATION_HAUTEUR, 1.0 + VARIATION_HAUTEUR))
	lecteur.play()
	return true


## Les lecteurs partagés (pour les tests : aucun ne doit jouer sur Master).
static func lecteurs() -> Array[AudioStreamPlayer]:
	return _lecteurs


static func _charger(chemin: String) -> AudioStream:
	if not _flux.has(chemin):
		_flux[chemin] = load(chemin) as AudioStream if ResourceLoader.exists(chemin) else null
	return _flux[chemin]


## Le prochain lecteur du tour de rôle (créé au besoin, posé sur la racine : il survit aux changements d'écran).
static func _lecteur_suivant() -> AudioStreamPlayer:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null or arbre.root == null:
		return null
	preparer_bus()
	if _lecteurs.is_empty():
		for i in NB_LECTEURS:
			var lecteur := AudioStreamPlayer.new()
			lecteur.bus = BUS_EFFETS
			arbre.root.add_child.call_deferred(lecteur)
			_lecteurs.append(lecteur)
	var choisi := _lecteurs[_suivant % NB_LECTEURS]
	_suivant += 1
	return choisi
