# Plan d'exécution — Dix tests d'intégration de l'évaluation, rouges sur Develop

## Lot A — Aligner les tests sur ADR-0115 (D1) et sur le retrait de l'import `essentials`

- **Couche**       : tests seulement
- **Fichiers**     : `test/integration/assessment/question_{fill_blank,matching,numeric,ordering}_test.rb`
- **Lire d'abord** : `docs/chantiers/correction-comme-en-classe/memo.md` (D1), `docs/decisions/adr/0115-correction-complete-note-en-points-et-types-de-questions.md`, les partials `app/views/assessment/session_results/kinds/_{fill_blank,matching,numeric,ordering}_review.html.erb`, `app/views/teams/imports/_question_examples.html.erb`.
- **Done quand**   : `bin/rails test test/integration/assessment` : 0 échec ; aucun fichier de `app/` touché.

### Contrat d'exécution

1. Lancer `test/integration/assessment` : noter les 10 échecs (état de départ, rouge).
2. Pour chaque test : renommer si son titre dit le contraire de D1, et remplacer l'assertion par la preuve de D1 (la bonne réponse visible et marquée après vérification). Garder une assertion « rien avant la vérification » là où le test couvrait un état avant vérification (422, verdict).
3. Test de l'aide d'import : viser `course_tree` (7 exemples, dont `"tolerance": 0.1` et `"match": "3x + 3"` s'ils y sont) ; constater ce que rend `essentials` (absent ou sans aide).
4. Relancer : vert. Puis `test/integration` entier. Rubocop des fichiers touchés.
5. Journal (une ligne par test réécrit) ; un commit `test(assessment): align integration tests with full correction (ADR-0115 D1)`, pied `Chantier: docs/chantiers/tests-correction-alignes`.
