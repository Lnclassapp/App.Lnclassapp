# Memo — Dix tests d'intégration de l'évaluation, rouges sur Develop

| | |
|---|---|
| **Type de cycle** | bugfix (tests) |
| **Statut** | en cours |
| **Ouvert le** | 2026-10-29 |
| **Branche** | `fix/tests-correction-alignes` |
| **Programme** | — |

---

## Symptôme

`bin/rails test test/integration/assessment` sur `Develop` : 30 tests, **10 échecs**, dans `question_{fill_blank,matching,numeric,ordering}_test.rb`. `bin/ci-quiet` niveau pr ne les joue pas ; la suite complète de la PR vers `Staging` les jouera et sera rouge.

## Cause

Les tests datent d'avant deux décisions fusionnées depuis :
1. **D1 de `correction-comme-en-classe`** (ADR-0115) : une fois la copie vérifiée, l'élève voit sa réponse, **la bonne réponse** et l'explication. Les tests affirment encore l'inverse (« ne révèle ni la valeur ni la marge », « ne marque aucune solution », `[data-correct]` absent, « Abidjan » absent du verdict). 9 échecs.
2. **Lot R de `refonte-contenus-maths`** (da631f6) : l'import `essentials` et son aide ont disparu ; l'aide des exemples (`teams/imports/_question_examples`) n'est plus rendue que par l'import `course_tree`, en version étendue (7 types). Le test « l'aide de l'import montre les quatre nouveaux types » vise encore `essentials` et 4 exemples. 1 échec.

Le code est conforme aux décisions ; ce sont les tests qui sont périmés.

## Correctif retenu

Réécrire chaque assertion périmée pour qu'elle prouve **la décision en vigueur**, sans en perdre la force :
- après vérification, la bonne réponse est montrée (valeur, paires, ordre, réponses acceptées), et marquée (`[data-correct]`) ;
- **avant** vérification (verdict d'une copie non vérifiée, copie refusée en 422, copie abandonnée), rien de la solution n'est montré : garder ou ajouter cette preuve là où le test la portait ;
- l'aide de l'import `course_tree` montre les 7 exemples ; l'import `essentials` n'a plus d'aide d'exemples (ou n'existe plus : le constater).

Aucun code applicatif ne change. Si un test révèle un vrai écart au code par rapport à ADR-0115 / UDR, s'arrêter et le noter au journal sans corriger.

## Portes de sortie

- [x] Les 10 tests verts, chacun prouvant la décision en vigueur
- [x] Preuve « rien avant la vérification » gardée
- [x] `test/integration/assessment` entier vert
- [ ] `bin/ci-quiet` vert, ligne de preuve dans la PR
