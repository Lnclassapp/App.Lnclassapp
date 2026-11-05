# Journal — [Titre du chantier]

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| | | | |

## À trancher

> Décisions laissées ouvertes ou tranchées par défaut par un agent, en attente du porteur. Relevées chaque jour à 12 h par la boîte de décisions (`docs/workflows/contrat-de-session.md`). Le porteur coche `[x]` et écrit sa réponse à la suite.
> Format d'une entrée : `- [ ] AAAA-MM-JJ · <slug ou PR> · <question> — appliqué : <option> ; autres : <options> ; recommandé : <option>`.

- [ ] 2026-11-05 · suivi-classe-lecon Lot 0 · clé du Hash de réussite : `public_id` de l'exercice (la feuille n'expose pas l'id interne), `exercise_ids:` = les public_id — appliqué : public_id ; autres : id interne ; recommandé : public_id
- [ ] 2026-11-05 · suivi-classe-lecon Lot 0 · l'UDR §3 ne donne que des textes, pas les clés : clés posées dans les locales des partiels A (`classroom.classroom_courses.notion_gaps.*`), B (`catalog.courses.sheets.success.*`), C (`catalog.revision_sheets.todo.*`, `classroom.student_classrooms.pending_gaps.redo_label`, `assessment.session_results.gap_outcome.redo_proposal`) ; les lots peuvent y ajouter des clés dans leurs propres partiels seulement si le fichier de locale reste celui du Lot 0 — appliqué : clés ci-dessus ; recommandé : idem
- [ ] 2026-11-05 · suivi-classe-lecon Lot A · repli de l'encadré : l'UDR §3.1 dit 5 noms puis « Voir plus », mais `ui_reveal_item`/`ui_reveal_more` fixent `REVEAL_LIMIT = 3` (UDR-0057 R3) — appliqué : le helper tel quel (3 noms) ; autres : paramétrer la limite du helper (hors lot) ; recommandé : amender l'UDR à 3, ou ajouter `limit:` au helper
- [ ] 2026-11-05 · suivi-classe-lecon Lot B · `_teacher_bar` (gelé) ne passe que `success:` à `_success` : l'ancre `sheet-success-<public_id>` lit donc `ClassSuccess#exercise_id` (champ ajouté à l'entité) ; « réussi » = `Grading.reaches?(meilleure copie, PASS_THRESHOLD)` (note affichée, ADR-0106) et non `score_percent >= 50` brut — appliqué : ces deux choix ; autres : passer `exercise:` au partiel (touche `_teacher_bar`, hors lot) ; recommandé : idem
- [ ] 2026-11-05 · suivi-classe-lecon Lot C · les partiels `_pending_gaps` et `_gap_outcome` sont rendus par des vues hors du champ du lot (`student_classrooms/show`, `session_results/show`) avec des locaux fixes : la proposition leur arrive par variable d'instance du contrôleur (`@remediation_proposals`, `@remediation_proposal`) — appliqué : variables d'instance ; autres : passer un local depuis les vues parentes ; recommandé : local, à la clôture
- [ ] 2026-11-05 · suivi-classe-lecon Lot C · hors champ, minimal et nécessaire : `catalog/courses/show.html.erb` passe `proposals: @proposals` (sans quoi la leçon n'affiche rien) ; `student_classrooms_controller_test.rb` et `gaps_link_test.rb` attendaient l'ancien lien (notion de la leçon) alors que le seul exercice publié est désormais proposé (CA-9) — appliqué : ces trois fichiers touchés ; recommandé : idem
- [ ] 2026-11-05 · suivi-classe-lecon Lot C · vérifié : le dom_id de la feuille de notion est `notion-<slug de la notion>` (PrepareSheetsQuery) et l'ancre d'un exercice `sheet-exercise-<public_id>` : liens de l'UDR §3.3 inchangés

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- …

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| | | |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
