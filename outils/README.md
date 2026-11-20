# Outils de vérification

Des scripts à lancer à la main (ou par Claude) pour vérifier le jeu autrement que par les tests de `tests/`.
Ils ne font pas partie du jeu. Sous Windows, remplacer `godot` par l'exécutable console de Godot (son chemin
est noté dans `CLAUDE.md`, section « Vérifier son travail »), et lancer avec `timeout` en redirigeant la sortie
vers un fichier : un script en erreur peut bloquer Godot sans jamais rendre la main.

| Outil | Commande | Ce qu'il fait |
| --- | --- | --- |
| `equilibrage.gd` | `godot --headless --path . -s res://outils/equilibrage.gd` | Joue des centaines de parties avec des « robots » et affiche le taux de victoire, pour régler la difficulté (cible : robot « prudent » 35 à 45 %). Des essais en mémoire se passent en JSON après `--`. Mesure aussi le robot « prudent » avec un profil neuf, 3 malédictions et tous les avantages. |
| `simulation_parties.gd` | `godot --headless --path . -s res://outils/simulation_parties.gd` (aussi sans `--headless`, dans une vraie fenêtre : l'animation des rouleaux est alors active et le script la termine) | Joue des parties entières à travers les vraies scènes (Comptoir, portes, coffres, repos, mises, relances, reliques, boutique), en 3 passes dont une « increvable » qui va jusqu'à la victoire. À relancer après tout changement d'écran. Code de sortie 1 en cas d'erreur. |
| `capture_ecrans.gd` | `godot --path . -s res://outils/capture_ecrans.gd` | Prend des captures d'écran réelles de chaque écran (fenêtre réelle, donc sans `--headless`) dans `%APPDATA%\Godot\app_userdata\jackpot donjon\captures\`. Les ouvrir ensuite pour vérifier l'aspect. |
| `clics_reels.gd` | `godot --path . -s res://outils/clics_reels.gd` | Joue un tour avec de vrais clics de souris dans une vraie fenêtre. Code de sortie 1 si un contrôle ne répond pas. |
| `generer_sons.py` | `python outils/generer_sons.py` | Génère les sons qui manquent aux packs CC0 (rouleaux, ding, fanfare, coups, bouclier, soin, bombe, relique, victoire, défaite) dans `assets/sons/`, avec la seule bibliothèque standard de Python. |
| `importer_assets.py` | `python outils/importer_assets.py chemin/vers/0x72_DungeonTilesetII_v1.7.zip` | Copie dans `assets/images/` les seules images du pack 0x72 utilisées par le jeu (le .zip se télécharge sur https://0x72.itch.io/dungeontileset-ii et n'est pas dans le dépôt), dessine le bouclier, l'aimant et le trèfle, contrôle chaque PNG et met à jour `assets/manifeste.json`. |
