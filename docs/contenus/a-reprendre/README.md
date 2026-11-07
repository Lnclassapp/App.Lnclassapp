# Leçons à reprendre

Les 393 leçons encore hors de `../lecons-traitees/`, sur les 438 sorties de `../lecons-traitees/` par le chantier [`base-de-lecons`](../../chantiers/base-de-lecons/memo.md) (2026-11-06). Les 45 leçons de Tle C y sont revenues au format complet (chantier [`lecons-tle-c-comme-thales`](../../chantiers/lecons-tle-c-comme-thales/memo.md), #484). Ici, rien n'est chargé par Develop, Staging ni le jeu standard.

Chaque fichier garde son chemin `<catégorie>/<niveau-série>/<matière>/<leçon>.json`. Le classement fichier par fichier est dans [`classement.tsv`](../../chantiers/base-de-lecons/classement.tsv).

| Catégorie | Fichiers | Ce qui manque |
|---|---:|---|
| [`sujets-manquants/`](sujets-manquants/) | 241 | v3 valide, mais pas les 4 sujets de devoir de 4 exercices chacun |
| [`exercices-et-sujets-manquants/`](exercices-et-sujets-manquants/) | 71 | v3 valide, mais un seul exercice par notion (il faut `exercise` et `practice`) et pas de sujets de devoir |
| [`format-v1/`](format-v1/) | 81 | tout : le format 1 est refusé à l'import (`format_retired`), la leçon est à réécrire en v3 |

## Règle de retour

Un fichier revient dans `lecons-traitees/<niveau-série>/<matière>/` (même chemin, sans la catégorie) quand il a le format complet (4 blocs et 2 exercices par notion, 4 problèmes, 4 sujets de devoir de 4 exercices) et que `ruby script/contenus/valider.rb <fichier>` ne rend aucune erreur. Il quitte alors `a-reprendre/` dans le même commit. Pour que le jeu standard le charge, l'ajouter aussi à `db/seeds/standard/jeu.yml`.
