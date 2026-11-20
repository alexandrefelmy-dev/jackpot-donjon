"""OUTIL : importe les images du pack 0x72 DungeonTileset II (CC0) dans assets/images/ et dessine les trois
icônes qui manquent au pack (bouclier, aimant, trèfle) dans la même taille (16x16) et un style proche.

Lancer :  python outils/importer_assets.py "C:\\chemin\\0x72_DungeonTilesetII_v1.7.zip"
Le pack se télécharge (gratuit, CC0) sur https://0x72.itch.io/dungeontileset-ii ; le .zip n'est PAS dans le dépôt.
Ne copie que les images utilisées par le jeu (listes ci-dessous), met à jour assets/manifeste.json (source, auteur,
licence de chaque fichier) et contrôle chaque PNG : format RGBA (vraie transparence), pas de faux damier.
Pas de dépendance : la bibliothèque standard suffit (les PNG sont lus et écrits à la main).
"""
import json
import math
import os
import struct
import sys
import zipfile
import zlib

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DOSSIER = os.path.join(RACINE, "assets", "images")
MANIFESTE = os.path.join(RACINE, "assets", "manifeste.json")
DANS_LE_ZIP = "0x72_DungeonTilesetII_v1.7/frames/"

# Animations (images _f0, _f1, ...) : l'attente des ennemis, du joueur, du coffre-mimique, de la pièce.
ANIMATIONS = [
    "goblin_idle_anim", "skelet_idle_anim", "tiny_slug_anim", "ice_zombie_anim", "big_zombie_idle_anim",
    "imp_idle_anim", "orc_warrior_idle_anim", "orc_shaman_idle_anim", "ogre_idle_anim", "necromancer_anim",
    "big_demon_idle_anim", "knight_m_idle_anim", "chest_mimic_open_anim", "coin_anim",
]
# Images seules : icônes des symboles et des portes, sol du fond.
SEULES = [
    "weapon_regular_sword", "flask_big_red", "skull", "weapon_arrow", "bomb_f0", "flask_big_green",
    "weapon_knight_sword", "chest_full_open_anim_f0", "floor_1", "floor_2", "floor_3", "floor_4", "ui_heart_full",
]
AUTEUR = "0x72"
SOURCE = "https://0x72.itch.io/dungeontileset-ii"


# --- PNG à la main ---------------------------------------------------------------------------------------------

def ecrire_png(chemin, largeur, hauteur, pixels):
    """pixels : liste de lignes, chaque ligne une liste de (r, g, b, a)."""
    brut = b"".join(b"\x00" + bytes(c for px in ligne for c in px) for ligne in pixels)

    def bloc(type_, donnees):
        corps = type_ + donnees
        return struct.pack(">I", len(donnees)) + corps + struct.pack(">I", zlib.crc32(corps) & 0xFFFFFFFF)

    with open(chemin, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloc(b"IHDR", struct.pack(">IIBBBBB", largeur, hauteur, 8, 6, 0, 0, 0)))
        f.write(bloc(b"IDAT", zlib.compress(brut, 9)))
        f.write(bloc(b"IEND", b""))


def lire_entete_png(donnees):
    """(largeur, hauteur, type de couleur) d'un PNG ; type 6 = RGBA."""
    assert donnees[:8] == b"\x89PNG\r\n\x1a\n", "ce n'est pas un PNG"
    largeur, hauteur = struct.unpack(">II", donnees[16:24])
    return largeur, hauteur, donnees[25]


# --- Les trois icônes dessinées ------------------------------------------------------------------------------------

TRANSPARENT = (0, 0, 0, 0)


def grille_vide():
    return [[TRANSPARENT] * 16 for _ in range(16)]


def contour(grille, couleur):
    """Entoure d'un trait sombre tous les pixels pleins (comme les sprites du pack)."""
    copie = [ligne[:] for ligne in grille]
    for y in range(16):
        for x in range(16):
            if grille[y][x][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 16 and 0 <= ny < 16 and grille[ny][nx][3] != 0:
                        copie[y][x] = couleur
                        break
    return copie


def icone_bouclier():
    bleu, clair, or_, sombre = (74, 127, 212, 255), (143, 181, 240, 255), (232, 184, 48, 255), (28, 43, 74, 255)
    g = grille_vide()
    for y in range(2, 15):
        # Un écu : large en haut, qui se resserre vers la pointe.
        reste = max(0, y - 8) * 1.1
        gauche, droite = 2 + int(reste), 13 - int(reste)
        for x in range(gauche, droite + 1):
            g[y][x] = bleu
        if y >= 2:
            g[y][gauche] = or_
            g[y][droite] = or_
    for x in range(2, 14):
        g[2][x] = or_
    for y in range(4, 8):
        g[y][4] = clair
        g[y][5] = clair if y < 6 else bleu
    g[14][7] = or_
    g[14][8] = or_
    return contour(g, sombre)


def icone_aimant():
    rouge, argent, sombre = (214, 70, 70, 255), (225, 228, 235, 255), (60, 22, 22, 255)
    g = grille_vide()
    for y in range(2, 14):
        for x in range(2, 14):
            dans_u = False
            centre = (7.5, 7.5)
            dist = math.hypot(x - centre[0], y - centre[1])
            if 3.6 <= dist <= 6.4 and y <= 8:
                dans_u = True
            if y > 7 and ((2 <= x <= 5) or (10 <= x <= 13)):
                dans_u = True
            if dans_u:
                g[y][x] = argent if y >= 11 else rouge
    return contour(g, sombre)


def icone_trefle():
    vert, clair, sombre = (63, 163, 77, 255), (127, 214, 138, 255), (20, 64, 31, 255)
    g = grille_vide()
    for cx, cy in ((5.2, 5.2), (10.8, 5.2), (5.2, 10.0), (10.8, 10.0)):
        for y in range(16):
            for x in range(16):
                if math.hypot(x - cx, y - cy) <= 3.3:
                    g[y][x] = vert
    for y in range(11, 15):
        g[y][7 + (y - 11) // 2] = vert
        g[y][8 + (y - 11) // 2] = vert
    for cx, cy in ((4.3, 4.3), (9.9, 4.3), (4.3, 9.1), (9.9, 9.1)):
        g[int(cy)][int(cx)] = clair
    return contour(g, sombre)


ICONES_DESSINEES = {"bouclier": icone_bouclier, "aimant": icone_aimant, "trefle": icone_trefle}


# --- Import ---------------------------------------------------------------------------------------------------------

def noms_a_copier(noms_du_zip):
    voulus = []
    for nom in sorted(noms_du_zip):
        base = nom[:-4]
        if base in SEULES:
            voulus.append(nom)
        else:
            for prefixe in ANIMATIONS:
                reste = base[len(prefixe):]
                if base.startswith(prefixe + "_f") and reste[2:].isdigit():
                    voulus.append(nom)
    return voulus


def main():
    if len(sys.argv) != 2 or not os.path.isfile(sys.argv[1]):
        sys.exit("Usage : python outils/importer_assets.py chemin/vers/0x72_DungeonTilesetII_v1.7.zip")
    os.makedirs(DOSSIER, exist_ok=True)
    pack = zipfile.ZipFile(sys.argv[1])
    dans_zip = {n[len(DANS_LE_ZIP):]: n for n in pack.namelist() if n.startswith(DANS_LE_ZIP) and n.endswith(".png")}
    a_copier = noms_a_copier(dans_zip)
    attendus = len(SEULES) + sum(1 for p in ANIMATIONS for n in dans_zip if n.startswith(p + "_f"))
    assert len(a_copier) == attendus, (len(a_copier), attendus)
    manifeste = []
    erreurs = 0
    for nom in a_copier:
        donnees = pack.read(dans_zip[nom])
        largeur, hauteur, couleur = lire_entete_png(donnees)
        if couleur != 6 or largeur < 4 or hauteur < 4:
            print("ERREUR : %s : %dx%d, type de couleur %d (RGBA attendu)" % (nom, largeur, hauteur, couleur))
            erreurs += 1
        with open(os.path.join(DOSSIER, nom), "wb") as f:
            f.write(donnees)
        manifeste.append({"fichier": "assets/images/" + nom, "auteur": AUTEUR, "source": SOURCE,
                          "licence": "CC0 1.0", "origine": "pack externe (DungeonTileset II v1.7)"})
    for nom, dessiner in ICONES_DESSINEES.items():
        ecrire_png(os.path.join(DOSSIER, nom + ".png"), 16, 16, dessiner())
        manifeste.append({"fichier": "assets/images/%s.png" % nom, "auteur": "Jackpot Donjon",
                          "source": "dessiné par outils/importer_assets.py (16x16, palette réduite)",
                          "licence": "créé pour le jeu (aucune licence externe)", "origine": "dessiné par script"})
    existant = []
    if os.path.isfile(MANIFESTE):
        with open(MANIFESTE, encoding="utf-8") as f:
            existant = [e for e in json.load(f) if not e["fichier"].startswith("assets/images/")]
    with open(MANIFESTE, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(existant + manifeste, ensure_ascii=False, indent=1) + "\n")
    print("%d images copiées, %d icônes dessinées, %d erreur(s)" % (len(a_copier), len(ICONES_DESSINEES), erreurs))
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
