class_name Impacts
extends RefCounted
## Les petits effets qui rendent un tirage satisfaisant : chiffres qui s'envolent, pluie de pièces, flash,
## arrêt sur image, secousse. Aucune règle de jeu ici : les écrans déclenchent ces effets à partir de ce
## qui s'est passé. Tout ce qui bouge ou clignote respecte les options d'accessibilité du joueur.

const MAX_CHIFFRES := 12
const MAX_FLASHS_PAR_SECONDE := 3
const ARRET_SUR_IMAGE := 0.06
const COULEUR_DEGATS := Color("ff9a5c")
const COULEUR_SUBIS := Color("ff5a5a")
const COULEUR_SOIN := Color("7ddc7d")
const COULEUR_ARMURE := Color("7fb8ff")
const COULEUR_OR := Color("ffd34d")

static var _id_arret: int = 0
static var _flashs_recents: Array[int] = []


## Le joueur a-t-il demandé moins de tremblements ? (sans options chargées : non)
static func tremblements_reduits() -> bool:
	return GameState.options != null and GameState.options.reduire_tremblements


static func flashs_reduits() -> bool:
	return GameState.options != null and GameState.options.reduire_flashs


## Une secousse d'écran de force `montant` (0 à 1) sur l'écran `ecran`. Crée la Secousse au besoin.
static func secouer(ecran: Control, montant: float) -> void:
	if tremblements_reduits() or not is_instance_valid(ecran):
		return
	var secousse := ecran.get_node_or_null("Secousse") as Secousse
	if secousse == null:
		secousse = Secousse.new()
		secousse.name = "Secousse"
		secousse.cible = ecran
		ecran.add_child(secousse)
	secousse.ajouter(montant)


## Un arrêt sur image très court (le temps ralentit presque à zéro) sur un gros impact. Deux appels
## rapprochés : seul le dernier remet le temps à la normale. Coupé par « Réduire les tremblements ».
static func arret_sur_image(duree: float = ARRET_SUR_IMAGE) -> void:
	if tremblements_reduits():
		return
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null:
		return
	_id_arret += 1
	var mon_id := _id_arret
	Engine.time_scale = 0.05
	# Le minuteur ignore le temps ralenti : il se déclenche à l'heure réelle.
	await arbre.create_timer(duree, true, false, true).timeout
	if mon_id == _id_arret:
		Engine.time_scale = 1.0


## Un chiffre qui monte et s'efface (dégâts, soin, or...) à `position`, dans `parent`. Au plus MAX_CHIFFRES à la fois.
static func chiffre(parent: Control, texte: String, position: Vector2, couleur: Color) -> Label:
	if not is_instance_valid(parent) or parent.get_tree() == null:
		return null
	if parent.get_tree().get_nodes_in_group("chiffres_flottants").size() >= MAX_CHIFFRES:
		return null
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_size_override("font_size", 32)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	etiquette.add_theme_constant_override("outline_size", 6)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.z_index = 50
	etiquette.position = position
	etiquette.add_to_group("chiffres_flottants")
	parent.add_child(etiquette)
	var mouvement := etiquette.create_tween().set_parallel(true)
	mouvement.tween_property(etiquette, "position:y", position.y - 70.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mouvement.tween_property(etiquette, "modulate:a", 0.0, 0.9).set_delay(0.3)
	mouvement.chain().tween_callback(etiquette.queue_free)
	return etiquette


## Une pluie de pièces qui tombe de haut en bas de `parent` (jackpot). Renvoie le nombre de pièces créées.
static func pluie_de_pieces(parent: Control, nombre: int = 28) -> int:
	if not is_instance_valid(parent) or parent.get_tree() == null:
		return 0
	var hasard := RandomNumberGenerator.new()
	hasard.randomize()
	var largeur := maxf(parent.size.x, 200.0)
	var hauteur := maxf(parent.size.y, 200.0)
	for i in nombre:
		var piece := Label.new()
		piece.text = "●"
		piece.add_theme_font_size_override("font_size", hasard.randi_range(22, 36))
		piece.add_theme_color_override("font_color", COULEUR_OR)
		piece.add_theme_color_override("font_outline_color", Color("8a6a1e"))
		piece.add_theme_constant_override("outline_size", 4)
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 40
		piece.position = Vector2(hasard.randf_range(0.0, largeur - 30.0), -40.0)
		parent.add_child(piece)
		var chute := piece.create_tween()
		chute.tween_interval(hasard.randf_range(0.0, 0.5))
		chute.tween_property(piece, "position:y", hauteur + 20.0, hasard.randf_range(0.9, 1.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		chute.tween_callback(piece.queue_free)
	return nombre


## Une grande bannière néon (« JACKPOT ! ») qui apparaît au milieu de `parent` puis s'efface.
static func banniere(parent: Control, texte: String) -> Label:
	if not is_instance_valid(parent):
		return null
	var etiquette := Label.new()
	etiquette.text = texte
	etiquette.add_theme_font_size_override("font_size", 72)
	etiquette.add_theme_color_override("font_color", COULEUR_OR)
	etiquette.add_theme_color_override("font_outline_color", Color("7a1f1f"))
	etiquette.add_theme_constant_override("outline_size", 10)
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.z_index = 60
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Cartes.neon(etiquette, Color("ff5a5a"))
	parent.add_child(etiquette)
	# Centrée quelle que soit la longueur du texte : toute la largeur, texte au milieu.
	etiquette.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	etiquette.offset_top = 140.0
	var vie := etiquette.create_tween()
	vie.tween_interval(0.9)
	vie.tween_property(etiquette, "modulate:a", 0.0, 0.6)
	vie.tween_callback(etiquette.queue_free)
	return etiquette


## Un éclair blanc sur `controle` (l'ennemi touché). Au plus 3 par seconde ; coupé par « Réduire les flashs ».
## Renvoie vrai si l'éclair a eu lieu.
static func flash(controle: CanvasItem) -> bool:
	if flashs_reduits() or not is_instance_valid(controle):
		return false
	var maintenant := Time.get_ticks_msec()
	while not _flashs_recents.is_empty() and maintenant - _flashs_recents[0] > 1000:
		_flashs_recents.pop_front()
	if _flashs_recents.size() >= MAX_FLASHS_PAR_SECONDE:
		return false
	_flashs_recents.append(maintenant)
	controle.modulate = Color(2.2, 2.2, 2.2)
	var retour := controle.create_tween()
	retour.tween_property(controle, "modulate", Color.WHITE, 0.15)
	return true


## Le texte, la couleur et le lieu des chiffres à faire s'envoler après un tour (pour les tests et l'écran).
## Chaque entrée : { "texte": String, "couleur": Color, "lieu": "ennemi" | "joueur" | "or" }.
static func chiffres_du_tour(resultat: ResultatTirage, pv_joueur_avant: int, pv_joueur_apres: int) -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	if resultat.total("degats") > 0:
		liste.append({"texte": "-%d" % resultat.total("degats"), "couleur": COULEUR_DEGATS, "lieu": "ennemi"})
	if pv_joueur_apres < pv_joueur_avant:
		liste.append({"texte": "-%d" % (pv_joueur_avant - pv_joueur_apres), "couleur": COULEUR_SUBIS, "lieu": "joueur"})
	if resultat.total("soin") > 0:
		liste.append({"texte": "+%d PV" % resultat.total("soin"), "couleur": COULEUR_SOIN, "lieu": "joueur"})
	if resultat.total("armure") > 0:
		liste.append({"texte": "+%d" % resultat.total("armure"), "couleur": COULEUR_ARMURE, "lieu": "joueur"})
	if resultat.total("or") > 0:
		liste.append({"texte": "+%d or" % resultat.total("or"), "couleur": COULEUR_OR, "lieu": "or"})
	return liste


## La force de la secousse d'un tour (0 = aucune) : un jackpot claque, un gros combo ou un gros coup reçu secouent.
static func force_de_secousse(resultat: ResultatTirage, pv_joueur_avant: int, pv_joueur_apres: int) -> float:
	var force := 0.0
	if resultat.a_un_jackpot():
		return 0.9
	if resultat.total("degats") >= 15:
		force = maxf(force, 0.5)
	elif resultat.total("degats") >= 8:
		force = maxf(force, 0.25)
	var subis := pv_joueur_avant - pv_joueur_apres
	if subis >= 10:
		force = maxf(force, 0.5)
	elif subis >= 4:
		force = maxf(force, 0.25)
	return force
