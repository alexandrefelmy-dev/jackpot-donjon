# Jackpot Donjon

Un roguelike solo en 2D : on descend un donjon, et chaque combat se joue en tirant le levier d'une machine à sous qu'on améliore au fil de la partie.

Une ligne de 5 rouleaux, tirés au hasard dans le « sac » de symboles du joueur. Trois symboles identiques côte à côte forment un combo (×1), quatre ×2, cinq un jackpot ×4. Le plaisir : voir sa machine devenir de plus en plus truquée en sa faveur.

Inspirations : Luck be a Landlord, Slay the Spire, Balatro.

**Statut : en développement, version 0.2 terminée** (la machine à sous, ses combos et un premier combat) ; prochaine étape : v0.3, une partie complète minimale. Projet personnel, développé avec l'aide de l'IA.

## Lancer le jeu

1. Installer [Godot 4.7](https://godotengine.org/download) (version standard, GDScript).
2. Ouvrir le dossier du projet dans Godot (`project.godot`).
3. Appuyer sur F5 : l'écran de combat s'ouvre (l'écran de test de la machine est `scenes/machine_test.tscn`).

## Lancer les tests

```
godot --headless --path . --import
godot --headless --path . -s res://tests/test_machine.gd
godot --headless --path . -s res://tests/test_combat.gd
```

Sous Windows, utiliser l'exécutable `..._console.exe` de Godot. Le script affiche `ok` ou `ÉCHEC` pour chaque test et se termine avec le code 1 en cas d'échec.

## Documentation

Les règles, les valeurs et les jalons (v0.1 à v1.1) sont dans [`docs/cahier-des-charges.md`](docs/cahier-des-charges.md).

## Organisation

| Dossier | Contenu |
| --- | --- |
| `scenes/` | scènes et leur script (écran de combat, écran de test de la machine) |
| `scripts/` | logique : sac, tirage, combos, effets, combat |
| `data/` | symboles et ennemis, un fichier `.tres` chacun |
| `tests/` | tests en ligne de commande |
| `docs/` | cahier des charges |
