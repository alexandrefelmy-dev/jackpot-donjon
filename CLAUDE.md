# Jackpot Donjon

Roguelike 2D où chaque combat se joue sur une machine à sous (1 ligne de 5 rouleaux, combos de 3/4/5).
Godot 4.7, GDScript. Projet perso d'Alex, fait pour le plaisir avec l'IA : Claude écrit le code, Alex teste avec F5.

## Références

- Règles du jeu, valeurs, jalons : `docs/cahier-des-charges.md` (copie locale).
  La version de référence est en ligne : https://claude.ai/artifact/7T7o7Bod8SKvpvXNtsJpef
  Lire la section concernée avant de toucher à une règle. Si une règle change, mettre à jour la copie locale et prévenir Alex de reporter le changement en ligne.

## État actuel

IMPORTANT : dès qu'une étape est terminée (ou avant qu'Alex quitte la session), mettre à jour cette section : ce qui est fait, ce qui reste à tester, la prochaine étape.

- v0.1 écrite : machine 1×5, sac de départ (15 symboles), combos 3/4/5 n'importe où sur la ligne (×1/×2/×4), écran de test `scenes/machine_test.tscn`.
- v0.1 terminée : 16 tests en ligne de commande passent et Alex a confirmé que ça marche en jeu (F5).
- Dépôt GitHub public : https://github.com/alexandrefelmy-dev/jackpot-donjon (branche `main`, `git push` suffit).
- v0.2 terminée : `Combat` (logique pure), `EnemyData` + 3 ennemis (`data/enemies/`), intentions attaque/protection, écran `scenes/combat.tscn` (main scene, sélecteur d'ennemi, Rejouer). Tests en ligne de commande : 16 (machine) + 46 (combat), tous ok, et Alex a confirmé que ça marche en jeu (F5, aucune erreur).
- Règles précisées en v0.2 (section « Précisions de règles (v0.2) » du cahier des charges) : reportées à la fois dans la copie locale et dans la version en ligne (fait le 2026-11-19, avec la ligne « Réalisé » du jalon v0.2).
- v0.3 terminée (Alex a confirmé en jeu, F5, une partie jusqu'au bout) : `Partie` (PV, or, sac, 5 rencontres d'étage 1 + boss), classe statique `GameState` (ex-autoload), écrans `combat` / `recompense` / `fin_partie`, ennemis Gobelin tricheur et boss Rat-Croupier (bloque un rouleau), rouleaux bloqués dans `MachineASous.tirer`. Tests : 20 (machine) + 66 (combat) + 51 (partie) + 18 (interface) = 155, tous ok ; 25 parties jouées à travers les vraies scènes en headless sans erreur. Règles v0.3 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Bug trouvé par Alex en jeu (v0.3) : le bouton « Continuer » sortait de la fenêtre (y 639 à 683 sur 648) donc impossible de passer au combat suivant ; corrigé en compactant l'écran de combat, avec `tests/test_interface.gd` pour que ça ne revienne pas. Après tout changement d'écran, relancer ce test.
- v0.4 terminée (Alex a confirmé en jeu, F5 : boutique, dorés, vol d'or, boutons de test ; le seul « bug » signalé était un malentendu sur les combos, qui doivent être côte à côte) : boutique après chaque combat normal (`Boutique` : acheter, retirer 10 or +5 par retrait, dorer 20 or, se soigner 10 PV pour 10 or), symboles dorés (copie du `.tres`, effet de base ×2, et ×2 par doré dans un combo : constante `MachineASous.FACTEUR_COMBO_PAR_DORE`), vol d'or du Gobelin tricheur, écran `scenes/boutique.tscn`. Ordre des écrans : combat → récompense → boutique → combat. Tests : 30 (machine) + 78 (combat) + 54 (partie) + 67 (boutique) + 53 (interface) = 282, tous ok ; 30 parties jouées à travers les vraies scènes (achats, retraits, dorures, soins) sans erreur. Règles v0.4 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Équilibrage v0.4 : attaques Rat 8, Squelette 13, Gobelin 9, boss 14 → environ 52 % de victoires pour un robot qui passe par la boutique sans réfléchir (600 parties) ; sans boutique le même robot gagne moins de 5 %. À régler dans `data/enemies/*.tres` après les essais d'Alex.
- Bug trouvé par Alex en jeu (v0.4) : « Identifier not found: GameState » (l'éditeur ouvert ne connaissait pas l'autoload). Corrigé en remplaçant l'autoload par une classe statique, qui ne dépend plus de `project.godot`.
- Bug trouvé par Alex en jeu (v0.4) : les touches de test F8 (+30 or) et F9 (aller au boss) ne marchaient pas : dans l'éditeur Godot, F8 est « Arrêter le jeu » (le jeu se fermait) et F9 gelait le jeu ; chez Claude, F9 marchait (fenêtre réelle + événements clavier réels, hors éditeur). Corrigé en les remplaçant par des boutons « [test] » visibles dans les écrans. **Ne jamais utiliser les touches de fonction F1–F12 (ni raccourcis d'éditeur) pour des fonctions de test : le jeu se joue à la souris, utiliser des boutons.**
- Les journaux du jeu (y compris celui d'un jeu lancé par Alex depuis l'éditeur) sont dans `%APPDATA%\Godot\app_userdata\jackpot donjon\logs\` ; Godot n'en garde que 5 : lancer des tests en ligne de commande les fait tourner et efface celui d'Alex. Quand Alex rapporte un bug, lire ce dossier AVANT de lancer quoi que ce soit.
- v0.5 terminée (Alex a confirmé en jeu, F5, mises, reliques et relances) : mises (`Mise` : or 5/10/20 gagnée = 3× la mise, quitte ou double à 5 PV), 9 reliques (`RelicData`, `data/relics/*.tres`, effets = paramètres du `.tres` ; `Reliques`, `Modificateurs`, `Partie.ajouter_relique`), tour en deux temps dans `Combat` (`tirer` / `relancer_tout` / `relancer_en_gardant` / `valider`, `jouer_tour(resultat, mise)` reste la fonction de règles), machine à 6 rouleaux (Sixième rouleau), relique offerte après le combat 3 (`scenes/relique.tscn`), 2 reliques en boutique. Ordre des écrans : combat → récompense → [relique après le combat 3] → boutique → combat. Tests : 30 (machine) + 78 (combat) + 54 (partie) + 67 (boutique) + 103 (reliques) + 122 (mises) + 131 (interface) = 585, tous ok ; 50 parties jouées à travers les vraies scènes (mises, relances, reliques, boutique) sans erreur ; de vrais clics de souris dans une vraie fenêtre vérifiés (mise, Cinquième as, Dé pipé, Valider). Règles v0.5 reportées dans le cahier des charges local ET en ligne (2026-11-19).
- Équilibrage v0.5 : valeurs des ennemis inchangées (rat 8, squelette 13, gobelin 9, boss 14) ; robot sans réflexion : environ 55 % de victoires sans relique, 56 à 61 % avec reliques offertes/achetées. À régler dans les `.tres` après les essais d'Alex.
- Prochaine étape : v0.6 (le donjon : 3 étages, choix entre 2 portes, coffres et repos, tous les ennemis et boss), Plan à rédiger avec Alex avant de coder.

## Conventions

- GDScript typé statiquement. Noms de variables, fonctions et commentaires en français.
- Tout texte affiché au joueur passe par `tr()` (traduction anglaise prévue en v1.1).
- Le contenu du jeu (symboles, ennemis, reliques) vit dans des ressources `.tres` sous `data/`, jamais en dur dans le code.
- La taille de la machine est un paramètre : `MachineASous.new(colonnes, lignes)`.
- Les valeurs chiffrées sont des valeurs de départ, réglables dans les `.tres`.

## Structure

- `scripts/data/` : classes de données (`SymbolData`…)
- `scripts/machine/` : sac, tirage, détection des combos, résultat
- `scripts/combat/` : `Combat` (tour par tour en deux temps, PV, armure, victoire/défaite, rouleaux bloqués, mises, relances), `Intentions`, `Mise`
- `scripts/machine/modificateurs.gd` : `Modificateurs` (ce que les reliques changent dans le calcul d'un tirage)
- `scripts/partie/` : `Partie` (état et règles d'une partie : PV, or, sac, rencontres, récompenses, reliques), `Boutique` (prix et actions de la boutique, symboles et reliques), `Reliques` (liste des 9 reliques)
- `data/relics/` : un `.tres` par relique (prix, description, paramètres des effets)
- `scripts/ui/` : `Cartes` (styles de boutons partagés par les écrans)
- `scripts/game_state.gd` : classe `GameState` à membres statiques, PAS un autoload (garde la partie, change d'écran ; aucune règle dedans)
- `scenes/` : scènes et leur script (`combat.tscn` = écran principal, puis `recompense.tscn`, `relique.tscn`, `boutique.tscn` et `fin_partie.tscn` ; `machine_test.tscn` = test de la machine)
- `data/symbols/` : un `.tres` par symbole
- `data/enemies/` : un `.tres` par ennemi
- `tests/` : scripts de test en ligne de commande
- `docs/` : cahier des charges, CREDITS.md

## Vérifier son travail

- Tests : `godot --headless --path . -s res://tests/test_machine.gd`, `... test_combat.gd`, `... test_partie.gd`, `... test_boutique.gd`, `... test_reliques.gd`, `... test_mises.gd` et `... test_interface.gd` (vérifie que les boutons tiennent dans la fenêtre 1152×648) (affichent ok / ÉCHEC, code de sortie 1 en cas d'échec). Les tests de règles utilisent des ennemis de test aux valeurs fixes, pas les `.tres` (qui sont réglés en jouant).
- Pour vérifier l'aspect d'un écran : lancer un script jetable SANS `--headless` (`godot --path . -s script.gd`, fenêtre réelle) qui enregistre `root.get_texture().get_image().save_png(...)` après quelques images, puis lire le PNG. Les tests de position ne voient pas un texte coupé ou un cadre mal dimensionné. On peut aussi y envoyer de vrais clics avec `Input.parse_input_event(InputEventMouseButton)`.
- Toujours lancer Godot en ligne de commande avec `timeout` et la sortie redirigée vers un fichier : un script en erreur peut bloquer Godot headless sans jamais rendre la main.
- Script jetable qui instancie une scène : attendre `await process_frame` avant de lire ses nœuds (sinon `_ready` n'a pas tourné). Les ressources chargées par `load()` sont déchargées quand plus rien ne les référence : garder une référence si on les modifie en mémoire.
- Éviter de modifier `project.godot` à la main : si Alex a l'éditeur Godot ouvert, celui-ci le réécrit depuis sa mémoire et efface la modification (c'est arrivé avec un autoload, et le jeu d'Alex plantait avec « Identifier not found: GameState » en v0.4). C'est pourquoi `GameState` est une classe statique et non un autoload. Si une modification de `project.godot` est vraiment nécessaire, demander à Alex de fermer et rouvrir l'éditeur avant de tester.
- Sous Windows, utiliser l'exécutable console de Godot (`Godot_v4.7.2-stable_win64_console.exe`). Il n'est pas dans le PATH ; chemin sur le PC d'Alex : `C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe` (version 4.7.2). S'il a changé, demander le nouveau chemin à Alex.
- Après avoir créé un fichier avec `class_name`, lancer d'abord `godot --headless --path . --import` pour mettre à jour le cache des classes.
- Chaque nouvelle règle de calcul a son test dans `tests/`.

## Travailler avec Alex

- Alex est étudiant en informatique (bases en Python et Ada) : expliquer en quelques lignes ce qui a changé et comment le tester.
- Une version jouable à la fois : ne pas commencer la suivante tant que la précédente ne marche pas en jeu.
- Faire un commit git après chaque étape qui marche.
