# Outils de vérification

Des scripts à lancer à la main (ou par Claude) pour vérifier le jeu autrement que par les tests de `tests/`.
Ils ne font pas partie du jeu. Sous Windows, remplacer `godot` par l'exécutable console de Godot (son chemin
est noté dans `CLAUDE.md`, section « Vérifier son travail »), et lancer avec `timeout` en redirigeant la sortie
vers un fichier : un script en erreur peut bloquer Godot sans jamais rendre la main.

| Outil | Commande | Ce qu'il fait |
| --- | --- | --- |
| `equilibrage.gd` | `godot --headless --path . -s res://outils/equilibrage.gd` | Joue des centaines de parties avec des « robots » et affiche le taux de victoire, pour régler la difficulté (cible : robot « prudent » 35 à 45 %). Des essais en mémoire se passent en JSON après `--`. |
| `simulation_parties.gd` | `godot --headless --path . -s res://outils/simulation_parties.gd` | Joue des parties entières à travers les vraies scènes (portes, coffres, repos, mises, relances, reliques, boutique), en 3 passes dont une « increvable » qui va jusqu'à la victoire. À relancer après tout changement d'écran. Code de sortie 1 en cas d'erreur. |
| `capture_ecrans.gd` | `godot --path . -s res://outils/capture_ecrans.gd` | Prend des captures d'écran réelles de chaque écran (fenêtre réelle, donc sans `--headless`) dans `%APPDATA%\Godot\app_userdata\jackpot donjon\captures\`. Les ouvrir ensuite pour vérifier l'aspect. |
| `clics_reels.gd` | `godot --path . -s res://outils/clics_reels.gd` | Joue un tour avec de vrais clics de souris dans une vraie fenêtre. Code de sortie 1 si un contrôle ne répond pas. |
