# Journal — preuve-arbre-documents-seuls

## Ce qu'on a appris sur la codebase

**Chaîne** : `ci.yml` job `plan`, étape `changes` → `code=false` dès que `pulls/files` ne nomme que `docs/` ou `*.md` →
jobs `unit`, `coverage`, `system` sautés → job `ci`, étape `verdict`, branche `if [ "$CODE" != true ]` : `exit 0` sans écrire
`proof=true` → « Publish the proof of the tested tree » sautée → `deploiement.yml`, `script/ci/tested_tree <révision>` ne
trouve pas `ci-tree-<tree>` → « Refus sans preuve ».

**Cause** (une phrase sans les mots du symptôme) : la règle « documents seuls, rien à rejouer » datait d'avant l'exigence de
preuve au déploiement ; elle rendait un verdict vert sans rien affirmer sur l'arbre, et « plan » ne vérifiait jamais que le
code venait d'un arbre déjà prouvé.

**Pourquoi aucun test ne l'a vu** : `test/guards/ci_plan_test.rb` vérifie le texte des conditions (regex sur le verdict), pas
le comportement du script ; et `ci_tested_tree_test.rb` teste la lecture de la preuve, jamais sa publication. Le nouveau test
exécute le script `verdict` lui-même.

**Effets de bord écartés** : une promotion de documents sur une base sans preuve (expirée après 30 jours, CI coupée) joue
désormais la suite entière au lieu d'un vert vide ; c'est voulu, sinon le déploiement la refuse de toute façon. Une PR vers
Develop n'est pas concernée (« plan » ne tourne que vers Staging/main).

## À trancher

- Option prudente appliquée : base sans preuve → suite entière (`code=true`) plutôt qu'un vert sans preuve. Réversible.
- Les `*.md` hors de `docs/` comptent comme documents, comme la règle existante et le filtre de `deploiement.yml`.
