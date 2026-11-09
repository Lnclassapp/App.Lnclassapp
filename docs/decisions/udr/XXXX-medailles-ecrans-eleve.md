# UDR-XXXX : Médailles — les écrans de l'élève
<!-- index
titre: Médailles dans les écrans de l'élève
statut: Accepté
adr-lie: [0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md)
problematique: L'élève lit encore note, pourcentage, maîtrise et points à côté de sa médaille.
-->

| | |
|---|---|
| **Statut** | Accepté (porteur, 2026-11-08) |
| **Date** | 2026-11-08 |
| **Chantier** | [`docs/chantiers/medailles-eleve`](../../chantiers/medailles-eleve/memo.md) |
| **ADR lié** | [ADR-0106](../adr/0106-les-seuils-pedagogiques-se-lisent-sur-la-note-affichee.md) |
| **Remplacé par** | — |

---

## 1. Contexte

Applique l'UDR « Médailles remplacent notes et moyennes » aux écrans de l'élève.

## 3. Consigne d'exécution

| Écran (élève) | Avant | Après |
|---|---|---|
| Résultat d'une session | médaille, titre, tuiles Note/Maîtrise, points | médaille, titre d'appréciation, « Prochaine médaille : X » (absente au Diamant) |
| Résultat : progrès | « 8/20 … 14/20 » | « Tu passes de Bronze à Argent. Bravo ! » · « Tu confirmes ta médaille Or. » · « Ta meilleure médaille reste Or… » |
| Résultat : remédiation | « vise au moins 15/20 » | « vise l'Or » |
| Accueil : Historique | note, « Refaire » sous 10/20 | médaille ; « Refaire » sous l'Argent |
| Accueil : « À revoir » | « Tu as eu 8/20 » | « Ta médaille est Bronze. » |
| Ma classe, Mon historique | « 16/20 · Acquis », pastille « 14/20 » | pastille médaille (trophée coloré + nom ; « Médaille Or » au lecteur d'écran) |
| Page d'un exercice | « Meilleure note : 16/20 » | « Ta médaille : Or » |
| Copie en cours | barème, « (2 points) » | rien ; le compteur « répondues » reste |
| FAQ | échelle sur 20 | mots (« environ deux questions sur trois ») |

États : une médaille existe dès qu'un exercice est traité (au moins Bronze) ; « Pas encore » (drapeau, texte gris) seulement sans exercice fait. Jamais rouge. La médaille ne porte jamais seule le sens : le nom est écrit. L'enseignant et l'équipe gardent leurs vues jusqu'à leurs chantiers.
