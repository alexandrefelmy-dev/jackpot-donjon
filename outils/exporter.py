r"""OUTIL : exporte le jeu pour Windows (un seul .exe, données intégrées) et fabrique le .zip à envoyer.

Lancer :  python outils/exporter.py [chemin/vers/Godot_..._console.exe]
Sans argument : la variable d'environnement GODOT, sinon `godot_console` ou `godot` dans le PATH, sinon
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe (le chemin du PC d'Alex).
Prérequis : les modèles d'export de Godot (même version que l'éditeur) installés, voir « Exporter le jeu » dans
CLAUDE.md. Le préréglage « Windows Desktop » vient de export_presets.cfg.
Résultat dans build/ (ignoré par git) : windows/jackpot-donjon.exe et jackpot-donjon-<version>-windows.zip
(l'exe, docs/LISEZMOI.txt et les crédits). Affiche aussi l'empreinte SHA-256 du .zip.
Les champs « application/... » (icône, version, description) de export_presets.cfg sont écrits dans le .exe par
l'outil rcedit : il doit être indiqué dans les paramètres de l'éditeur Godot (export/windows/rcedit), et
`application/modify_resources` doit être à true.
Pas de dépendance : la bibliothèque standard de Python suffit.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GODOT_PAR_DEFAUT = r"C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
PRESET = "Windows Desktop"


def version_du_jeu():
    with open(os.path.join(RACINE, "scripts", "version.gd"), encoding="utf-8") as f:
        trouve = re.search(r'NUMERO := "([^"]+)"', f.read())
    return trouve.group(1) if trouve else "inconnue"


def trouver_godot():
    """L'exécutable console de Godot : l'argument, GODOT, le PATH, puis le chemin par défaut."""
    if len(sys.argv) > 1:
        return sys.argv[1]
    return os.environ.get("GODOT") or shutil.which("godot_console") or shutil.which("godot") or GODOT_PAR_DEFAUT


def main():
    godot = trouver_godot()
    version = version_du_jeu()
    sortie = os.path.join(RACINE, "build", "windows")
    os.makedirs(sortie, exist_ok=True)
    exe = os.path.join(sortie, "jackpot-donjon.exe")
    print("Export de la version", version, "...")
    # Importer d'abord : un projet fraîchement cloné n'a pas encore son cache d'images.
    subprocess.run([godot, "--headless", "--path", RACINE, "--import"], check=True, capture_output=True)
    resultat = subprocess.run([godot, "--headless", "--path", RACINE, "--export-release", PRESET, exe],
                              capture_output=True, text=True)
    if resultat.returncode != 0 or not os.path.exists(exe):
        print(resultat.stdout[-2000:], resultat.stderr[-2000:])
        sys.exit("ÉCHEC de l'export (les modèles d'export sont-ils installés ?)")
    archive = os.path.join(RACINE, "build", "jackpot-donjon-%s-windows.zip" % version)
    dossier = "jackpot-donjon"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(exe, dossier + "/jackpot-donjon.exe")
        z.write(os.path.join(RACINE, "docs", "LISEZMOI.txt"), dossier + "/LISEZMOI.txt")
        z.write(os.path.join(RACINE, "docs", "CREDITS.md"), dossier + "/CREDITS.txt")
    with zipfile.ZipFile(archive) as z:  # relue une fois fermée : une archive abîmée ne part pas
        assert z.testzip() is None, "archive abîmée"
    with open(archive, "rb") as f:
        empreinte = hashlib.sha256(f.read()).hexdigest()
    print("exe :", exe, os.path.getsize(exe), "octets")
    print("zip :", archive, os.path.getsize(archive), "octets")
    print("sha256 :", empreinte)


if __name__ == "__main__":
    main()
