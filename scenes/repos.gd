extends Control
## Écran de repos : une seule action, au choix : se soigner de 30 % des PV max, ou rendre un
## symbole doré gratuitement (on le choisit dans le sac). Ensuite : retour aux portes.

const COULEUR_FOND := Color("1b1a24")
const COULEUR_SOIN := Color("3f7d4f")
const COULEUR_DORER := Color("9c7424")
const TAILLE_CHOIX := Vector2(340, 190)

enum Mode { CHOIX, DORER }

var partie: Partie
var mode: Mode = Mode.CHOIX

var texte_infos: Label
var texte_message: Label
var zone_choix: Control
var bouton_soin: Button
var bouton_dorer: Button
var zone_sac: Control
var liste_sac: VBoxContainer
var bouton_annuler: Button


func _ready() -> void:
	partie = GameState.partie
	if partie.ecran != Partie.Ecran.REPOS:
		GameState.rediriger()
		return
	_construire_interface()
	_rafraichir()


# --- Actions -----------------------------------------------------------------

func _se_reposer() -> void:
	if partie.soin_du_repos() <= 0:
		return
	partie.repos_soigner()
	GameState.aller_a_suivant()


## « Rendre un symbole doré » : on montre le sac pour choisir lequel.
func _choisir_symbole() -> void:
	mode = Mode.DORER
	_rafraichir()


func _annuler() -> void:
	mode = Mode.CHOIX
	_rafraichir()


func _dorer(index_sac: int) -> void:
	if partie.repos_dorer(index_sac):
		GameState.aller_a_suivant()


# --- Affichage ---------------------------------------------------------------

func _rafraichir() -> void:
	texte_infos.text = tr("PV : %d / %d     Or : %d     Sac : %d symboles") % [
		partie.pv, partie.pv_max, partie.or_total, partie.sac.taille()]
	zone_choix.visible = mode == Mode.CHOIX
	zone_sac.visible = mode == Mode.DORER
	bouton_annuler.visible = mode == Mode.DORER

	var soin := partie.soin_du_repos()
	if soin > 0:
		bouton_soin.text = tr("Se reposer\n\n+%d PV (%d %% des PV max)") % [soin, Partie.SOIN_REPOS_POURCENT]
	else:
		bouton_soin.text = tr("Se reposer\n\nTes PV sont déjà au maximum.")
	bouton_soin.disabled = soin <= 0
	bouton_dorer.disabled = not partie.peut_dorer()

	if mode == Mode.DORER:
		texte_message.text = tr("Choisis dans ton sac le symbole à rendre doré (gratuit).")
		_rafraichir_sac()
	else:
		texte_message.text = tr("Une seule action : choisis bien.")


## Le sac, un symbole par ligne ; seuls ceux qui ne sont pas déjà dorés se choisissent.
func _rafraichir_sac() -> void:
	for ancien in liste_sac.get_children():
		liste_sac.remove_child(ancien)
		ancien.queue_free()
	for groupe in partie.sac.groupes():
		var symbole: SymbolData = groupe["symbole"]
		var index: int = groupe["index"]
		var ligne := Button.new()
		ligne.text = "%s ×%d  —  %s" % [symbole.nom_affiche(), groupe["quantite"], Effets.decrire(symbole.effet_base)]
		ligne.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ligne.custom_minimum_size = Vector2(0, 36)
		ligne.focus_mode = Control.FOCUS_NONE
		ligne.add_theme_font_size_override("font_size", 17)
		ligne.tooltip_text = "%s\n%s" % [
			symbole.nom_affiche(), tr("Combo de 3 : %s") % Effets.decrire(symbole.effet_combo)]
		Cartes.habiller_bouton(ligne, symbole.couleur)
		ligne.disabled = symbole.doree
		ligne.pressed.connect(_dorer.bind(index))
		liste_sac.add_child(ligne)


# --- Construction de l'interface (en code) -----------------------------------

func _construire_interface() -> void:
	var fond := ColorRect.new()
	fond.color = COULEUR_FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for cote in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(cote, 24)
	add_child(marge)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	marge.add_child(page)

	var titre := Label.new()
	titre.text = tr("Un feu de camp : repos")
	titre.add_theme_font_size_override("font_size", 34)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(titre)

	texte_infos = Label.new()
	texte_infos.add_theme_font_size_override("font_size", 20)
	texte_infos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(texte_infos)

	texte_message = Label.new()
	texte_message.add_theme_font_size_override("font_size", 20)
	texte_message.add_theme_color_override("font_color", Color("ffd34d"))
	texte_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(texte_message)

	# Mode « choix » : les deux grosses cartes, centrées.
	var centre := CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(centre)
	zone_choix = HBoxContainer.new()
	zone_choix.add_theme_constant_override("separation", 40)
	centre.add_child(zone_choix)
	bouton_soin = _creer_carte(COULEUR_SOIN, _se_reposer)
	zone_choix.add_child(bouton_soin)
	bouton_dorer = _creer_carte(COULEUR_DORER, _choisir_symbole)
	bouton_dorer.text = tr("Rendre un symbole doré\n\nGratuit : tu choisis le symbole dans ton sac.")
	zone_choix.add_child(bouton_dorer)

	# Mode « dorer » : le sac, qui défile.
	var defilement := ScrollContainer.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(defilement)
	zone_sac = defilement
	liste_sac = VBoxContainer.new()
	liste_sac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste_sac.add_theme_constant_override("separation", 6)
	defilement.add_child(liste_sac)

	bouton_annuler = Button.new()
	bouton_annuler.text = tr("Annuler")
	bouton_annuler.custom_minimum_size = Vector2(0, 46)
	bouton_annuler.focus_mode = Control.FOCUS_NONE
	bouton_annuler.pressed.connect(_annuler)
	page.add_child(bouton_annuler)


func _creer_carte(couleur: Color, action: Callable) -> Button:
	var carte := Button.new()
	carte.custom_minimum_size = TAILLE_CHOIX
	carte.focus_mode = Control.FOCUS_NONE
	carte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carte.add_theme_font_size_override("font_size", 22)
	Cartes.habiller_bouton(carte, couleur)
	carte.pressed.connect(action)
	return carte
