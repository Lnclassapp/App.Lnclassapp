# Leçons à reprendre

Les 143 leçons encore hors de `../lecons-traitees/`, sur les 438 sorties de `../lecons-traitees/` par le chantier [`base-de-lecons`](../../chantiers/base-de-lecons/memo.md) (2026-11-06). Les 45 leçons de Tle C, les 45 de Tle D, les 32 de Tle A1, les 31 de Tle A2 et les 10 d'Histoire-Géographie de Tle y sont revenues au format complet, ainsi que les 105 fichiers des leçons 1 à 5 de chaque série et matière de 1ère et les 27 de 2nde (chantiers [`lecons-tle-c-comme-thales`](../../chantiers/lecons-tle-c-comme-thales/memo.md), [`lecons-tle-d-comme-thales`](../../chantiers/lecons-tle-d-comme-thales/memo.md), [`lecons-tle-a1-comme-thales`](../../chantiers/lecons-tle-a1-comme-thales/memo.md), [`lecons-tle-a2-comme-thales`](../../chantiers/lecons-tle-a2-comme-thales/memo.md) et [`lecons-tle-comme-thales`](../../chantiers/lecons-tle-comme-thales/memo.md), #484 ; [`lecons-1ere-2nde-debut`](../../chantiers/lecons-1ere-2nde-debut/memo.md)). Ici, rien n'est chargé par Develop, Staging ni le jeu standard.

Chaque fichier garde son chemin `<catégorie>/<niveau-série>/<matière>/<leçon>.json`. Le classement fichier par fichier est dans [`classement.tsv`](../../chantiers/base-de-lecons/classement.tsv) (catégorie `traitee` pour un fichier revenu par `lecons-1ere-2nde-debut`).

| Catégorie | Fichiers | Ce qui manque |
|---|---:|---|
| [`sujets-manquants/`](sujets-manquants/) | 72 | v3 valide, mais pas les 4 sujets de devoir de 4 exercices chacun |
| [`exercices-et-sujets-manquants/`](exercices-et-sujets-manquants/) | 17 | v3 valide, mais un seul exercice par notion (il faut `exercise` et `practice`) et pas de sujets de devoir |
| [`format-v1/`](format-v1/) | 54 | tout : le format 1 est refusé à l'import (`format_retired`), la leçon est à réécrire en v3 |

## Règle de retour

Un fichier revient dans `lecons-traitees/<niveau-série>/<matière>/` (même chemin, sans la catégorie) quand il a le format complet (4 blocs et 2 exercices par notion, 4 problèmes, 4 sujets de devoir de 4 exercices) et que `ruby script/contenus/valider.rb <fichier>` ne rend aucune erreur. Il quitte alors `a-reprendre/` dans le même commit. Pour que le jeu standard le charge, l'ajouter aussi à `db/seeds/standard/jeu.yml`.
