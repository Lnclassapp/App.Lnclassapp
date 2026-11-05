# Memo — Orchestrateurs courts et index des chantiers généré

| | |
|---|---|
| **Type de cycle** | refactoring *(processus, aucun comportement produit)* |
| **Statut** | livré |
| **Ouvert le** | 2026-11-05 |
| **Branche** | `chore/orchestrateur-court-et-index` |
| **Programme** | — |

---

## Le problème

Mesures du rapport sur la méthode de travail (2026-11-05, 123 sessions, propositions 3 et 4) :

| Mesure | Valeur |
|---|---|
| Plus gros orchestrateur Opus | 86,76 $, 1,07 M de tokens produits, tenu sur tout un programme |
| Une vague de contenus | 30 à 44 $ |
| Commits qui ne touchent que `docs/chantiers/README.md` depuis le 9/10 | 51 (règle : un par chantier) |
| Collision de numéros d'ADR après une reprise | ADR-0083 renuméroté en 0085 |

`script/docs/build_index --number` posait déjà les numéros à la fusion (chantier `acceleration-du-flux`), mais en ne comptant que la branche : une branche en retard sur `Develop` pouvait reprendre un numéro déjà donné.

## Pour qui

Le porteur (coût, reprises) et les sessions d'orchestration.

## Ce qui change

- **Point 3** : [`docs/workflows/orchestrateur.md`](../../workflows/orchestrateur.md). Une session d'orchestration par vague ou par jour ; état écrit dans `etat.md` (modèle `_TEMPLATE/etat.md`), lu en début de session, mis à jour en un commit en fin de session ; fusions de routine par l'agent `fusionneur` (Sonnet, amendement d'ADR-0104).
- **Point 4** : `script/docs/build_index` génère aussi le tableau de `docs/chantiers/README.md` à partir de l'en-tête de chaque memo, par ordre alphabétique ; le pre-commit le lance dès qu'un memo ou une décision est stagé ; `--number` compte les numéros d'`origin/Develop` (récupéré d'abord) et `--check` refuse un numéro qu'`origin/Develop` a donné à une autre décision.

## Hors périmètre

- Numéroter par slug daté : le numéro à la fusion suffit, et les liens existants restent.
- Réécrire les 202 memos : le tableau lit leur en-tête tel qu'il est.
