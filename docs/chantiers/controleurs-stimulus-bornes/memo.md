# Memo — Contrôleurs Stimulus bornés

| | |
|---|---|
| **Type de cycle** | bugfix |
| **Statut** | en cours (PR vers `Develop`) |
| **Ouvert le** | 2026-11-15 |
| **Branche** | `fix/controleurs-stimulus-bornes` |

## Le problème

Dans la nuit du 2026-11-14 au 15, deux boucles côté navigateur sont apparues dans deux contrôleurs écrits par des sessions différentes : `math_controller` (`MutationObserver` par instance, éléments imbriqués ; corrigé, PR #628 ; la tâche de CI `lecons` a dépassé 5 minutes deux fois) et `hash_redirect_controller` (`location.replace` sans limite ; un 301 resté en cache de `/courses/<slug>/fiche` rebouclait ; issue #635). C'est un défaut de règle, pas de personne.

## Ce que livre le chantier

1. **#635 corrigée** : `hash_redirect` ne remplace qu'une fois par paire d'adresses (marqueur `sessionStorage`) ; test `test/javascript/hash_redirect_controller.test.js`.
2. **La règle** : [`docs/guide/conventions.md`](../../guide/conventions.md#contrôleur-stimulus-borné) §7 « Contrôleur Stimulus borné ».
3. **L'audit** des 98 fichiers JS (53 contrôleurs) de `app/javascript/` : [journal](journal.md).

## Hors périmètre

Le code des autres contrôleurs : seul ce qui est clairement non borné se corrige ; le reste est au `## À trancher` du journal.
