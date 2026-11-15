# Memo — Voir la couverture de branches avant le train

| | |
|---|---|
| **Type de cycle** | optimisation |
| **Statut** | en revue |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `optimize/couverture-branches-visible` |
| **Programme** | — |

---

## Le problème

Le seuil de l'[ADR-0024](../../decisions/adr/0024-couverture-de-tests-a-100-pourcent.md) (100 % des lignes **et des branches**) n'est contrôlé qu'au train, par la tâche `coverage` qui fusionne les trois parts `unit` ([ADR-0107](../../decisions/adr/0107-la-preuve-d-une-pr-suit-ce-qu-elle-touche.md)). Une PR vers `Develop` ne le voit jamais.

La nuit du 2026-11-14 : la PR #627 (96 fichiers) entre dans `Develop` avec sa preuve `bin/ci-quiet` niveau `pr` verte. Le train #631 l'arrête : lignes 22182 / 22182 (100 %) mais branches 6917 / 6919 (99,97 %), deux branches de `app/controllers/catalog/courses_controller.rb` (une mémoïsation morte, un `session[…] = … if requested` jamais joué). Coût : deux arrêts du train, la PR de correction #632, vingt minutes de CI à une heure du matin.

## Pour qui

L'agent qui prépare une PR vers `Develop` et le porteur qui attend le train.

## Pourquoi maintenant

L'écart était trouvable avant la fusion. Chaque fois qu'il se trouve au train, il coûte un arrêt de la promotion.

## Hors périmètre

- La suite complète et le seuil global restent **une fois par train** : rien ne bouge dans la tâche `coverage` ni dans `ci.yml`.
- Aucune CI GitHub n'est ajoutée aux PR vers `Develop`.
- Bloquer une PR sur la couverture des fichiers touchés : voir `## À trancher` du journal.

## La solution

Au niveau `pr`, les tests unitaires du périmètre (ceux que `bin/ci-quiet` jouait déjà, sous `COVERAGE=0`) jouent **avec** la mesure (`COVERAGE_PART=pr`, sans seuil). `script/ci/coverage_touched` lit le résultat et, pour les seuls fichiers `app/` et `lib/` touchés, nomme les lignes et les branches qu'aucun test de la PR ne joue. `bin/ci-quiet` l'affiche (rouge ou vert), et le redit tant que le code est le même, même si l'étape n'est pas rejouée. C'est un **avertissement**, jamais un blocage : voir l'[ADR-XXXX-couverture-des-fichiers-touches-au-niveau-pr](../../decisions/adr/XXXX-couverture-des-fichiers-touches-au-niveau-pr.md).

## Mesure (PR #627 avant correction, `5f6d5bf4`, base `eea49396`)

- 7 fichiers `app/` touchés, 56 fichiers de test dans le périmètre (972 tests), poste de 4 cœurs.
- Étape unitaire sans mesure : 23,2 s et 24,2 s. Avec mesure et rapport : 29,5 s et 29,4 s. **Surcoût : ≈ 5,5 s (+ 24 %)** sur cette étape, dans une preuve `pr` qui reste très en dessous des 5 minutes.
- Le rapport nomme **3 branches** de `courses_controller.rb` : les lignes 163 (`if` de la mémoïsation morte) et 185 (`session[…] = … if requested`) sont **exactement les deux du train #631**. La troisième (ligne 99, `unless essential.nil?`) est jouée par un test hors du périmètre : un faux positif, que le train accepte. Les lignes sont à 100 %, comme au train : seules les branches trahissaient.
