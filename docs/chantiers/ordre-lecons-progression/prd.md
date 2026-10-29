# PRD — Les leçons dans l'ordre de la progression

## Comportement attendu

Partout où une liste de leçons est rangée, les leçons d'une même matière et d'un même niveau suivent le numéro de leçon lu dans le sous-titre (« Leçon 2 » avant « Leçon 10 »). Une leçon sans numéro vient après, par nom. L'ordre des matières (rang du programme, puis nom) et des niveaux ne change pas.

## Critères d'acceptation

- **CA-1** — Le Cours de l'élève sur téléphone (`PROGRAM_ORDER`) range Leçon 1, 2, … 10, puis les leçons sans numéro par nom.
- **CA-2** — L'enseignant de plusieurs matières (`group_by_material`) et l'équipe (`CATALOG_ORDER`) suivent la même règle à l'intérieur d'une matière (et d'un niveau pour l'équipe).
- **CA-3** — L'ordre des matières est inchangé, comme les ordres déjà justes (enseignant d'une matière, élève sur ordinateur).
