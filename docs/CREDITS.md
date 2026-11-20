# Crédits et licences

Toute ressource externe du jeu a une licence qui autorise son usage ; sa source est notée ici et, fichier par
fichier, dans `assets/manifeste.json`. Toutes les ressources externes actuelles sont **CC0 1.0** (domaine public :
usage libre, crédit non obligatoire, donné ici par courtoisie).

## Sons (effets)

- **Casino Audio** par Kenney — https://kenney.nl/assets/casino-audio (copie sur OpenGameArt :
  https://opengameart.org/content/54-casino-sound-effects-cards-dice-chips) — CC0 1.0.
  Fichiers utilisés : `assets/sons/chip-lay-*.ogg` (arrêt des rouleaux), `chips-collide-*.ogg` (pièces),
  `chips-stack-*.ogg` (achats), `card-place-*.ogg` (clics). Licence : `assets/sons/LICENCE-kenney-casino-audio.txt`.
- **Sons générés pour le jeu** par `outils/generer_sons.py` (rouleaux, ding, fanfare, coups, bouclier, soin, bombe,
  relique, victoire, défaite) : créés pour Jackpot Donjon, sans licence externe.

## Musique (boucles)

| Piste | Titre | Auteur | Source | Licence |
| --- | --- | --- | --- | --- |
| Étage 1 (aussi le Comptoir) | Dungeon Ambience | yd | https://opengameart.org/content/dungeon-ambience | CC0 1.0 |
| Étage 2 | Insistent: background loop | yd | https://opengameart.org/content/insistent-background-loop | CC0 1.0 |
| Étage 3 | Creepy | TokyoGeisha | https://opengameart.org/content/creepy | CC0 1.0 |
| Boss | Fast fight / battle music (looped) | XCVG | https://opengameart.org/content/fast-fight-battle-music-looped | CC0 1.0 |

## Graphismes

- **DungeonTileset II** (v1.7) par 0x72 — https://0x72.itch.io/dungeontileset-ii — CC0 1.0.
  Fichiers utilisés dans `assets/images/` : les animations d'attente des ennemis et du chevalier (`*_idle_anim_f*.png`,
  `tiny_slug_anim`, `ice_zombie_anim`, `necromancer_anim`, `chest_mimic_open_anim`…), la pièce (`coin_anim_f*`),
  des icônes (`weapon_regular_sword`, `weapon_arrow`, `weapon_knight_sword`, `flask_big_red`, `flask_big_green`,
  `skull`, `bomb_f0`, `chest_full_open_anim_f0`, `ui_heart_full`) et les dalles du sol (`floor_1` à `floor_4`).
  Le pack lui-même n'est pas dans le dépôt : `outils/importer_assets.py` en copie ces seuls fichiers.
- **Dessinées pour le jeu** par `outils/importer_assets.py` (16×16, palette réduite, dans le style du pack) :
  `bouclier.png`, `aimant.png`, `trefle.png` — le pack n'a pas ces images ; aucune licence externe.
- **Dessinés par le code du jeu** (aucun fichier, aucune licence externe) : le meuble de la machine à sous, les
  ampoules, le levier, les flèches de la ligne de gain, l'icône du bouton plein écran, le halo derrière l'ennemi,
  les bords sombres, la moquette et les rideaux (shaders `moquette` et `rideau`), le cadre d'ampoules des portes et
  l'ornement des cartes, le thème des boutons (`scripts/ui/meuble_machine.gd`, `ampoules.gd`, `levier_machine.gd`,
  `plein_ecran.gd`, `decor.gd`, `habillage.gd`, `cadre_ampoules.gd`, `ornement_carte.gd`).
- **L'icône du jeu** (`assets/icone/icone.png` et `icone.ico`) : dessinée par `outils/dessiner_icone.gd` (carré
  arrondi, ampoules, rouleaux) avec trois sprites du pack 0x72 ci-dessus (épée, pièce, crâne) ; rien d'autre.
- Correspondance ennemi → image : dans le champ `images` de chaque `data/enemies/*.tres` (choix de ressemblance :
  le pack n'a pas de rat, de pickpocket ni de croupier exacts).

## Polices

Police par défaut de Godot (licence MIT, incluse dans le moteur).
