# Plan d'exécution — Les trois premières leçons de 1ère et de 2nde, comme Thalès

> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

## Graphe

```
1ère (PR 1) : un rédacteur par niveau-série × matière, 4 en parallèle au plus, chacun dans son worktree
  Français (5 fiches distinctes, 12 fichiers) · Mathématiques A, C, D · Physique-Chimie A, C, D · SVT A, C, D · Philosophie · Histoire-Géographie
  → Lot Z1 : assemblage (jeu.yml, README, classement.tsv), CI
2nde (PR 2) : Français · Mathématiques A, C · Physique-Chimie · SVT A, C · Histoire-Géographie
  → Lot Z2 : assemblage, CI
```

Pas de Lot 0 : aucune migration, aucune entité, aucun port, aucune route.

## Lots rédacteurs

- **Couche**       : contenu
- **Fichiers**     : `docs/contenus/lecons-traitees/<niveau-série>/<matière>/<leçon>.json` (+ suppression du même fichier dans `a-reprendre/`)
- **Test associé** : script de vérification hors dépôt (format Thalès, `valider.rb` sur la leçon et sur chaque sujet, contenu d'origine inchangé en 1ère) ; sympy sur chaque calcul en Mathématiques et Physique-Chimie
- **Done quand**   : 0 erreur sur chaque fichier ; relecture de l'orchestrateur

## Lots Z1, Z2 — assemblage

- **Fichiers**     : `db/seeds/standard/jeu.yml`, `docs/contenus/README.md`, `docs/contenus/a-reprendre/README.md`, `docs/chantiers/base-de-lecons/classement.tsv`, tests du manifeste
- **Test associé** : `standard_manifest_test.rb`, `standard_activity_test.rb`, rendu des leçons (`LECONS=…`), `bin/ci-quiet`
- **Done quand**   : tests verts, ligne de preuve dans la PR

## Vérification de collision

| Fichier | Propriétaire |
|---|---|
| une leçon et ses copies dans les autres séries | un seul rédacteur |
| `db/`, `test/`, READMEs, `classement.tsv` | l'orchestrateur (Z1, Z2) |

## Portes de sortie

- Chaque fichier : script de vérification à 0 erreur.
- PR : ligne de preuve `bin/ci-quiet` sur le SHA de tête ; la CI GitHub rend les leçons touchées.
