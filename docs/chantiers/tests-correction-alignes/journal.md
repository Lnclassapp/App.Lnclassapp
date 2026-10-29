# Journal — Dix tests d'intégration de l'évaluation, rouges sur Develop

- **2026-10-29 · Cadrage** : relevés par deux exécutants (lots badge et inscription), confirmés sur Develop (30 tests, 10 échecs). Cause : D1 de correction-comme-en-classe et Lot R de refonte-contenus-maths, fusionnés sans mise à jour de ces tests.
- **2026-10-29 · Lot A** : état de départ `test/integration/assessment` : 30 tests, 10 échecs (rouge confirmé). Aucun écart code / ADR-0115 constaté ; aucun fichier de `app/` touché. Résultat : 30 tests verts, `test/integration` entier 300 tests verts, rubocop net.
  - `question_numeric` « mauvaise réponse » : ne vérifiait plus que l'absence de la valeur/marge au résultat -> « rien avant » gardé (422 et résultat d'une copie ouverte sans `42,75`, `0,25`, `[data-correct]`), puis après vérification `[data-correct]` montre `42,75` et « (à 0,25 près) ».
  - `question_fill_blank` « ABIDJAN » : « le verdict ne dit rien d'autre » -> copie ouverte sans réponses acceptées, puis verdict avec `[data-correct]` « Abidjan ; Babi ».
  - `question_fill_blank` « faute de frappe » : `Abidjan|Babi` absent du verdict -> « Abidjn » redit et réponses acceptées marquées.
  - `question_fill_blank` « correction de l'élève / enseignant » : l'élève voit désormais les réponses acceptées comme l'enseignant ; ajout : un autre élève n'a pas accès à la copie (refus, rien de la solution).
  - `question_matching` « trois paires justes » : 3 `li` -> 3 paires de l'élève, plus 3 bonnes paires marquées.
  - `question_matching` « paire fausse / 422 » : `[data-correct]` absent -> le 422 n'écrit ni ne montre rien (gardé), la copie vérifiée montre les 3 bonnes paires marquées.
  - `question_matching` « correction ne marque aucune solution » : renommé ; copie ouverte sans solution (gardé), copie vérifiée avec bonnes paires marquées.
  - `question_matching` « aide de l'import » : visait `essentials` + 4 exemples -> `course_tree` : 7 exemples (dont `"tolerance": 0.1` et `"match": "3x + 3"`) ; `essentials` n'est plus un import connu (404, sans aide).
  - `question_ordering` « étape mal placée » : `[data-correct]` absent -> l'ordre de l'élève reste rendu tel quel et le bon ordre est montré à part, marqué.
  - `question_ordering` « correction ne marque aucune solution » : renommé ; copie ouverte sans solution (gardé), copie vérifiée avec bon ordre marqué.
- **2026-10-29 · Clôture** : PR #368 fusionnée dans `Develop` (0dee9d3), preuve `bin/ci-quiet` dans la PR. Sur `Develop` fusionné, `test/integration/assessment` : 30 tests, 206 assertions, 0 échec.
