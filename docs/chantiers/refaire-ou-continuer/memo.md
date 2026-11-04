# Memo — Refaire ou continuer depuis la correction

| | |
|---|---|
| **Type de cycle** | feature |
| **Statut** | planifié |
| **Ouvert le** | 2026-11-04 |
| **Branche** | `feature/refaire-ou-continuer` |
| **Programme** | — |

---

## Le problème

Après « Vérifier ma réponse » sur une feuille, l'élève arrive sur la page de correction. « Refaire l'exercice » l'emmène dans l'ancien lecteur d'exercice, une question à la fois, loin de sa feuille. « Retour à la leçon » le ramène sur sa feuille, mais à l'exercice qu'il vient de faire : il doit chercher lui-même celui qui reste, et le nom du bouton ne dit pas qu'on continue.

## Pour qui

L'élève, sur une feuille « Prépare interros » ou « Prépare devoirs » de la leçon, et sur un devoir reçu dans « Ma classe ».

## Pourquoi maintenant

Les feuilles se lisent puis se remplissent depuis la livraison des cases (UDR-0151) : la correction est le dernier écran qui sort l'élève de sa feuille.

## Hors périmètre

- La correction ouverte hors d'une feuille (historique, accueil, ancien lecteur) : boutons inchangés.
- L'enseignant, l'équipe, le parent, le personnel de l'école : ils ne voient pas ces boutons, rien ne change pour eux.
- Le contenu de la correction (note, points, « À revoir », correction détaillée) : inchangé.
- La règle de pause entre deux copies et le sans-faute (bouton caché) : inchangés.
- Garder seulement les réponses justes au « Refaire » : refusé, tout s'efface.

## Ce que le grill a révélé

| Question posée | Réponse | Conséquence sur le chantier |
|---|---|---|
| Nom du bouton qui remplace « Retour à la leçon » ? | « Continuer les exercices » | Nouveau libellé pour la feuille de la leçon. |
| Où mène « Continuer » ? | Sur la feuille à remplir ; l'exercice déjà fait garde les réponses que l'élève a choisies, la page va à l'exercice qu'il n'a pas encore fait | Ancre calculée : l'exercice suivant non fait, sinon le premier non fait de la feuille (choix de l'orchestrateur, l'ordre n'a pas été tranché par le pilote). |
| Et pour un devoir de « Ma classe » ? | Même comportement, le bouton garde son nom « Reprendre le devoir » | Les deux sortes de feuille passent par la même règle. |
| « Refaire » : tout effacer ou garder les justes ? | Tout effacer | « Refaire » ramène à la feuille et fait ce que fait déjà le « Refaire » de la feuille. |
| Tous les exercices sont faits ? | « Retour à la leçon » à la place de « Continuer » | Leçon : retour aux cases de la leçon, sur la case de la feuille. Devoir : « Retour à Ma classe » (choix de l'orchestrateur, même logique). |

## Cas limites identifiés

- La feuille a disparu ou l'ancre est inconnue : « Retour à la leçon » / « Retour à Ma classe », comme sans feuille.
- Un exercice de la feuille réussi ou raté compte comme fait : seule compte l'existence d'une copie vérifiée (comme la progression de la case).
- Un exercice demandé à refaire qui n'est pas sur la feuille (adresse trafiquée) : ignoré, la feuille s'ouvre normalement.
- Sans JavaScript, « Refaire » ouvre la feuille à l'exercice, qui montre encore la copie et son propre bouton « Refaire ».
- Élève dans plusieurs classes : la feuille du devoir est celle que « Ma classe » montre déjà (inchangé).

## Questions encore ouvertes

- Aucune.
