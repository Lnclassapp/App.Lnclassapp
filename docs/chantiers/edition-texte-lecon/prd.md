# PRD — Corriger le texte d'une leçon à l'écran

## 1. Contexte

Une leçon déjà travaillée ne se réimporte plus sans dommage ; le porteur a décidé le 2026-11-14 que l'équipe en corrige le texte à l'écran (ADR-0113 §4.6 amendé). La structure reste à l'import, la bonne réponse peut changer sans toucher aux résultats passés.

## 2. Acteurs et permissions

| Acteur | Peut | Ne peut pas |
|---|---|---|
| Team | Ouvrir et enregistrer le texte d'une notion ou d'un exercice, quel que soit son statut | Changer la structure (ajout, retrait, ordre) |
| Teacher, Student | — | Ouvrir ni enregistrer (403) |

Règle : `Policies::Catalog::ManageContentPolicy`, appelée par le use case avant toute lecture.

## 3. Parcours utilisateur

### Chemin nominal

1. Sur la page de la leçon, l'équipe ouvre le menu ⋮ d'une notion (fiche de révision) ou d'un exercice (feuille) et choisit « Modifier le texte ».
2. La modale montre le texte enregistré (et la bonne réponse cochée pour un exercice).
3. « Enregistrer » : toast, modale fermée, page à jour ; le journal inscrit `content.corrected`.

### Chemins alternatifs et erreurs

| Situation | Comportement attendu |
|---|---|
| Champ obligatoire vide, texte trop long, nom déjà pris | 422, message sous le champ, saisie gardée, rien d'écrit |
| Étape, question ou proposition ajoutée ou retirée (ou réimport entre-temps) | 422, bandeau « a changé depuis l'ouverture », rien d'écrit |
| Bonne réponse changée après des tentatives | Enregistré ; tentatives passées inchangées ; les suivantes jugées avec la nouvelle |
| Enseignant ou élève | 403 |

## 4. Critères d'acceptation

- CA-1 : l'équipe ouvre la modale d'une notion publiée, chaque bloc rempli (`teams/essentials_controller_test`).
- CA-2 : l'équipe change le texte et la bonne réponse d'un exercice tenté ; la tentative garde son résultat (`teams/exercises_controller_test`, `exercise_repository_test`).
- CA-3 : refus de structure et de texte vide en 422 (use cases et contrôleurs).
- CA-4 : 403 pour enseignant et élève.
- CA-5 : « Modifier le texte » au menu ⋮ de la notion et de l'exercice, pour l'équipe seulement.
