# Jackpot Donjon

Roguelike 2D où chaque combat se joue sur une machine à sous (1 ligne de 5 rouleaux, combos de 3/4/5).
Godot 4.7, GDScript. Projet perso d'Alex, fait pour le plaisir avec l'IA : Claude écrit le code, Alex teste avec F5.

## Références

- Règles du jeu, valeurs, jalons : `docs/cahier-des-charges.md` (copie locale).
  La version de référence est en ligne : https://claude.ai/artifact/7T7o7Bod8SKvpvXNtsJpef
  Lire la section concernée avant de toucher à une règle. Si une règle change, mettre à jour la copie locale et prévenir Alex de reporter le changement en ligne.

## État actuel (à mettre à jour à la fin de chaque session)

- v0.1 écrite : machine 1×5, sac de départ (15 symboles), combos 3/4/5 n'importe où sur la ligne (×1/×2/×4), écran de test `scenes/machine_test.tscn`.
- v0.1 : 16 tests en ligne de commande passent ; pas encore confirmée en jeu par Alex (premier test F5 à faire).
- Git initialisé (branche `main`), premier commit fait.
- Prochaine étape : v0.2, premier combat (voir « Périmètre et jalons » dans le cahier des charges).

## Conventions

- GDScript typé statiquement. Noms de variables, fonctions et commentaires en français.
- Tout texte affiché au joueur passe par `tr()` (traduction anglaise prévue en v1.1).
- Le contenu du jeu (symboles, ennemis, reliques) vit dans des ressources `.tres` sous `data/`, jamais en dur dans le code.
- La taille de la machine est un paramètre : `MachineASous.new(colonnes, lignes)`.
- Les valeurs chiffrées sont des valeurs de départ, réglables dans les `.tres`.

## Structure

- `scripts/data/` : classes de données (`SymbolData`…)
- `scripts/machine/` : sac, tirage, détection des combos, résultat
- `scenes/` : scènes et leur script
- `data/symbols/` : un `.tres` par symbole
- `tests/` : scripts de test en ligne de commande
- `docs/` : cahier des charges, CREDITS.md

## Vérifier son travail

- Tests : `godot --headless --path . -s res://tests/test_machine.gd` (affiche ok / ÉCHEC, code de sortie 1 en cas d'échec).
- Sous Windows, utiliser l'exécutable console de Godot (`Godot_v4.7-stable_win64_console.exe`). Il n'est pas dans le PATH ; chemin sur le PC d'Alex : `C:\Users\felmy\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (version 4.7.2). S'il a changé, demander le nouveau chemin à Alex.
- Après avoir créé un fichier avec `class_name`, lancer d'abord `godot --headless --path . --import` pour mettre à jour le cache des classes.
- Chaque nouvelle règle de calcul a son test dans `tests/`.

## Travailler avec Alex

- Alex est étudiant en informatique (bases en Python et Ada) : expliquer en quelques lignes ce qui a changé et comment le tester.
- Une version jouable à la fois : ne pas commencer la suivante tant que la précédente ne marche pas en jeu.
- Faire un commit git après chaque étape qui marche.
- Mettre à jour ce fichier sans qu'Alex le demande dès qu'il devient faux ou incomplet (état actuel, chemins, conventions, structure, commandes).
