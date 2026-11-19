"""OUTIL : fabrique les effets sonores que les packs CC0 ne fournissent pas (rouleaux, ding de combo,
fanfare de jackpot, coups, bouclier, soin, bombe, relique, victoire, défaite) avec un petit synthétiseur.

Lancer :  python outils/generer_sons.py
Écrit des .wav (mono, 22 050 Hz, 16 bits) dans assets/sons/. Pas de dépendance : la bibliothèque standard
suffit. Les sons sont originaux (créés par ce script) : aucune licence externe à gérer ; ils sont notés
« généré par outils/generer_sons.py » dans assets/manifeste.json. Remplacer un fichier par un autre du même
nom suffit à changer un son (le jeu ne connaît que les noms de data/sons.tres).

Contrôles faits à chaque génération : durée, niveau crête (au plus -3 dBFS, pour garder de la marge sur le bus),
début et fin à zéro (pas de « clic »).
"""
import math
import os
import random
import struct
import wave

TAUX = 22050
DOSSIER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sons")
CRETE_MAX = 0.708  # -3 dBFS


def temps(duree):
    return [i / TAUX for i in range(int(duree * TAUX))]


def enveloppe(t, duree, attaque=0.004, relache=0.05):
    """Montée rapide, descente exponentielle douce, et coupure à zéro en fin de son."""
    montee = min(1.0, t / attaque) if attaque > 0 else 1.0
    fin = min(1.0, (duree - t) / relache) if relache > 0 else 1.0
    return montee * max(0.0, fin)


def sinus(f, t, phase=0.0):
    return math.sin(2 * math.pi * f * t + phase)


def mixer(*pistes):
    n = max(len(p) for p in pistes)
    return [sum(p[i] if i < len(p) else 0.0 for p in pistes) for i in range(n)]


def normaliser(samples, cible=0.65):
    crete = max(abs(s) for s in samples) or 1.0
    gain = cible / crete
    return [s * gain for s in samples]


def ecrire(nom, samples):
    samples = normaliser(samples)
    os.makedirs(DOSSIER, exist_ok=True)
    chemin = os.path.join(DOSSIER, nom + ".wav")
    with wave.open(chemin, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAUX)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    crete = max(abs(s) for s in samples)
    assert crete <= CRETE_MAX, (nom, crete)
    assert abs(samples[0]) < 0.02 and abs(samples[-1]) < 0.02, (nom, "ne commence ou ne finit pas à zéro")
    print("%-22s %.2f s  crête %.2f" % (nom, len(samples) / TAUX, crete))


def bruit(graine, n):
    hasard = random.Random(graine)
    return [hasard.uniform(-1, 1) for _ in range(n)]


def passe_bas(samples, k):
    """Filtre simple : k proche de 1 = très sourd."""
    sortie, y = [], 0.0
    for s in samples:
        y = k * y + (1 - k) * s
        sortie.append(y)
    return sortie


def cloche(f, duree, harmoniques=(1.0, 2.0, 3.0), poids=(1.0, 0.5, 0.25), descente=5.0):
    return [sum(p * sinus(f * h, t) for h, p in zip(harmoniques, poids)) * math.exp(-descente * t) * enveloppe(t, duree)
            for t in temps(duree)]


def note(f, debut, duree, total, descente=4.0, timbre=(1.0, 0.4, 0.2)):
    n = int(total * TAUX)
    sortie = [0.0] * n
    for i in range(int(debut * TAUX), min(n, int((debut + duree) * TAUX))):
        t = i / TAUX - debut
        sortie[i] = sum(p * sinus(f * (k + 1), t) for k, p in enumerate(timbre)) * math.exp(-descente * t) * enveloppe(t, duree, 0.003, 0.03)
    return sortie


def fabriquer():
    # Rouleaux qui tournent : une rafale de petits « tic » de plus en plus espacés, sur 0,8 s.
    duree = 0.8
    n = int(duree * TAUX)
    tics = [0.0] * n
    position, ecart = 0.0, 0.018
    graine = random.Random(1)
    while position < duree - 0.05:
        i = int(position * TAUX)
        for k in range(200):
            if i + k < n:
                tics[i + k] += graine.uniform(-1, 1) * math.exp(-k / 25.0) * 0.8
        position += ecart
        ecart *= 1.045
    ecrire("rouleaux", [s * enveloppe(i / TAUX, duree, 0.01, 0.08) for i, s in enumerate(passe_bas(tics, 0.35))])

    # Ding de combo : petite cloche claire.
    ecrire("ding", cloche(1320.0, 0.9, (1.0, 2.01, 3.02, 4.2), (1.0, 0.45, 0.25, 0.12), 4.5))

    # Fanfare de jackpot : arpège ascendant et accord final, avec un léger vibrato.
    total = 2.0
    pistes = []
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        pistes.append(note(f, 0.12 * k, 0.5, total, 3.0))
    for f in (523.25, 659.25, 783.99, 1046.5):
        pistes.append(note(f, 0.7, 1.2, total, 1.6))
    ecrire("jackpot", mixer(*pistes))

    # Coups donnés (3 variantes) : un « thump » grave avec un peu de bruit.
    for v, (f0, f1) in enumerate([(170, 70), (200, 80), (150, 60)], start=1):
        duree = 0.22
        souffle = passe_bas(bruit(10 + v, int(duree * TAUX)), 0.6)
        s = []
        for i, t in enumerate(temps(duree)):
            f = f1 + (f0 - f1) * math.exp(-t * 18)
            s.append((sinus(f, t) * 0.9 + souffle[i] * 0.5) * math.exp(-t * 14) * enveloppe(t, duree, 0.002, 0.03))
        ecrire("coup_donne_%d" % v, s)

    # Coups reçus (2 variantes) : plus lourds et plus longs.
    for v, (f0, f1) in enumerate([(110, 45), (130, 50)], start=1):
        duree = 0.4
        souffle = passe_bas(bruit(20 + v, int(duree * TAUX)), 0.8)
        s = []
        for i, t in enumerate(temps(duree)):
            f = f1 + (f0 - f1) * math.exp(-t * 12)
            s.append((sinus(f, t) * 0.9 + souffle[i] * 0.9) * math.exp(-t * 8) * enveloppe(t, duree, 0.002, 0.05))
        ecrire("coup_recu_%d" % v, s)

    # Bouclier : un choc métallique (partiels non harmoniques).
    duree = 0.35
    ecrire("bouclier", [(sinus(1210, t) + 0.7 * sinus(1830, t) + 0.5 * sinus(2670, t) + 0.3 * sinus(3470, t))
                        * math.exp(-t * 14) * enveloppe(t, duree, 0.001, 0.05) for t in temps(duree)])

    # Soin : deux notes qui montent.
    ecrire("soin", mixer(note(660, 0.0, 0.45, 0.8, 5.0), note(990, 0.13, 0.55, 0.8, 4.0)))

    # Bombe : explosion = rafale de bruit grave qui s'éteint, avec un sinus très bas.
    duree = 0.9
    souffle = passe_bas(bruit(7, int(duree * TAUX)), 0.86)
    ecrire("bombe", [(souffle[i] * 2.5 + sinus(55 * math.exp(-t * 1.2), t) * 0.8) * math.exp(-t * 3.2) * enveloppe(t, duree, 0.002, 0.1)
                     for i, t in enumerate(temps(duree))])

    # Relique : scintillement de notes aiguës.
    total = 1.2
    graine = random.Random(5)
    pistes = [note(graine.choice([1568.0, 1760.0, 2093.0, 2349.0, 2637.0]), 0.07 * k, 0.4, total, 6.0, (1.0, 0.2)) for k in range(11)]
    ecrire("relique", mixer(*pistes))

    # Victoire : petit jingle joyeux. Défaite : quatre notes qui descendent.
    ecrire("victoire", mixer(*[note(f, 0.16 * k, 0.55, 1.9, 2.8) for k, f in enumerate([392.0, 523.25, 659.25, 783.99])],
                              note(1046.5, 0.7, 1.1, 1.9, 1.8)))
    ecrire("defaite", mixer(*[note(f, 0.28 * k, 0.7, 2.2, 2.2, (1.0, 0.3)) for k, f in enumerate([392.0, 311.13, 261.63, 196.0])]))


if __name__ == "__main__":
    fabriquer()
