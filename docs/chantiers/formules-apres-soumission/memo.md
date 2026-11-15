# Memo — Formules LaTeX brutes après « Vérifier »

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | livré (PR `fix/formules-apres-soumission`) |
| **Ouvert le** | 2026-11-14 |
| **Branche** | `fix/formules-apres-soumission` |

## Symptôme
Sur la fiche de révision (`/courses/<slug>`), après « Vérifier » dans « Je m'entraîne » (Mathématiques 2nde C, « Vecteurs et points du plan », à 390 px), le texte brut apparaît : `$\overrightarrow{AB}$`, au lieu des formules.

## Reproduction
Élève de 2nde, une notion dont l'entraînement contient des formules : cocher une proposition, « Vérifier », ouvrir « Correction » et « Indice ». Test : `test/system/catalog/practice_in_sheet_test.rb` (« les formules de l'entraînement sont rendues… »), rouge avant le correctif.

## Portée
Tout contenu qui arrive sous un élément `data-controller="math"` déjà connecté : frame de l'entraînement (`catalog/practice_checks/_result`) et Turbo Stream d'indice de la copie (`assessment/hints/create.turbo_stream`).

## Cause
Turbo ne remplace que le contenu d'un `<turbo-frame>` ou d'une cible de stream : l'élément porteur reste, `connect()` de `math_controller` ne rejoue pas, seul `turbo:morph` relançait KaTeX. Le commentaire de `_result` supposait le contraire. Aucun test ne vérifiait le rendu après une mise à jour Turbo.

## Correctif
`app/javascript/controllers/math_controller.js` : un `MutationObserver` rend de nouveau ce qui arrive sous l'élément (silencieux pendant son propre rendu). Aucune vue modifiée.

## Hors périmètre
Contenus des leçons (dépôt des contenus) ; mise en page de `/courses/<slug>` (chantier simplification-ecrans-eleve).
