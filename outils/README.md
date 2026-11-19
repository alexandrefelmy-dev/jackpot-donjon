# Outils de vérification

Des scripts à lancer à la main (ou par Claude) pour vérifier le jeu autrement que par les tests de `tests/`.
Ils ne font pas partie du jeu. Sous Windows, remplacer `godot` par l'exécutable console
(`C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`), et lancer avec `timeout` en redirigeant la sortie
vers un fichier : un script en erreur peut bloquer Godot sans jamais rendre la main.

| Outil | Commande | Ce qu'il fait |
| --- | --- | --- |
| `equilibrage.gd` | `godot --headless --path . -s res://outils/equilibrage.gd` | Joue des centaines de parties avec des « robots » et affiche le taux de victoire, pour régler la difficulté (cible : 50 à 60 % pour un robot sans réflexion). Les valeurs essayées sont en haut du fichier. |
| `simulation_parties.gd` | `godot --headless --path . -s res://outils/simulation_parties.gd` | Joue 50 parties entières à travers les vraies scènes (mises, relances, reliques, boutique). À relancer après tout changement d'écran. Code de sortie 1 en cas d'erreur. |
| `capture_ecrans.gd` | `godot --path . -s res://outils/capture_ecrans.gd` | Prend des captures d'écran réelles de chaque écran (fenêtre réelle, donc sans `--headless`) dans `%APPDATA%\Godot\app_userdata\jackpot donjon\captures\`. Les ouvrir ensuite pour vérifier l'aspect. |
| `clics_reels.gd` | `godot --path . -s res://outils/clics_reels.gd` | Joue un tour avec de vrais clics de souris dans une vraie fenêtre. Code de sortie 1 si un contrôle ne répond pas. |
