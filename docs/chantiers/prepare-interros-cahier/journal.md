# Journal — « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-30 (Lot B) | `sheets/_sheet.html.erb` ne lit aucune variable d'instance ni requête : tout passe par des locals (`kind:`, `header_left:`, `header_right:`, `title:`, `subtitle:`, `box_label:`, `box_text:`, `exercises:`, `footer:`, `reset_label:`, `sheet_id:`, plus `material:`, `mode:`, `targets:`, `classrooms:`). Les lots E / F la réutilisent telle quelle. | Une seule feuille pour notions, « Toute la leçon » et sujets | Non (UDR) |
| 2026-10-30 (Lot B) | L'exercice se rend sans formulaire pour l'enseignant et l'équipe | Les bascules d'assignation sont déjà des formulaires, qui ne s'imbriquent pas | Non |
| 2026-10-30 (Lot B) | Les questions d'un type absent de la maquette (`:other`) réutilisent les partiels `exercise_sessions/kinds/*` ; leurs réponses ne sont pas gardées en brouillon | Le brouillon ne connaît que les propositions et les champs texte de la maquette | Non |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

Découvertes sur du code existant, pièges, dépendances non documentées.

- **Mesure « après » (PRD §7), Lot B, 2026-10-30** : même méthode, même leçon (4 notions × 3 exercices + 1 « Toute la leçon »,
  élève sans copie) avec `PrepareSheetsQuery` : **36 requêtes SQL**, soit +0 (cible ≤ 39) ; avec un sujet de devoir, 37 ; pas de N+1
  (les questions, propositions, images et dernières copies se lisent par lots, `DISTINCT ON` pour la dernière copie terminée
  de chaque exercice). Les requêtes d'état de l'élève de l'ancienne carte (à rendre, à revoir, note) disparaissent et compensent
  les lectures nouvelles. Test : `test/integration/catalog/prepare_interros_test.rb` (plafond de 39).
- **Contrat pour le Lot C** (vérification sur la feuille) : champs `copy[answers][<question_id>][display_order][]` (indices dans
  l'ordre de la feuille, graine `PrepareSheetsQuery::SHEET_SEED = 0`) ou `copy[answers][<question_id>][response_text]` ; frame
  `sheet-exercise-<public_id>` (cible de remplacement), progression `sheet-progress-<dom_id de la feuille>`, note
  `sheet-grade-<public_id>` (focus après correction) ; `Prepare#exercise(public_id)` et `Prepare#sheet_of(public_id)` redonnent
  l'exercice et sa feuille ; `_exercise` et `_result` se rendent avec `exercise:` (+ `mode:` pour `_exercise`).
- L'ancre `notion-<slug>` existe aussi sur la fiche de révision (comme avant) : les tests visent `.ps-sheet#notion-<slug>`.
- L'enseignant et l'équipe ne voient pas l'indice (pas de champ, pas de « Vérifier »).
- Un test qui ouvre un exercice depuis la leçon par son titre ne peut plus : la feuille n'affiche que « Exercice n » (maquette).
  Adaptés au Lot B : `classroom_courses_controller_test`, `courses_controller_test`, `gaps_link_test`, `assignment_toggle_test`,
  `remediation_test`, `catalog_assignment_test`, `boucle_pedagogique_test` ; `test/system/catalog/prepare_interros_test.rb` reste au Lot D.
- `script/ci/test_timings.yml` : le garde `SystemBudgetTest` exige la durée de tout nouveau test système (`prepare_sheets_test.rb`).
- **Mesure « avant » (PRD §7), Lot 0, 2026-10-30** : `GET /courses/:slug` pour un élève de la classe du niveau de la leçon, sans copie
  ni devoir, leçon de 4 notions × 3 exercices (4 questions de 4 propositions chacun) + 1 exercice « Toute la leçon », avec
  `PrepareInterrosQuery` d'aujourd'hui : **36 requêtes SQL**, 0 en cache. Méthode : test d'intégration jetable (hors dépôt),
  deuxième `GET` après un premier d'échauffement, abonné à `sql.active_record` ; sont écartées les requêtes `SCHEMA`,
  `TRANSACTION` et `BEGIN` / `COMMIT` / `SAVEPOINT` / `RELEASE`. À refaire à l'identique après le Lot B.
- La clé étrangère d'une table de l'application doit être en `on_delete: :restrict` (`test/db/schema_constraints_test.rb`) : `subjects`
  et `exercises.subject_id` l'ont, contrairement à l'extrait de l'ADR §6.
- `RAILS_ENV=test bin/rails db:migrate` re-dump `db/schema.rb` depuis la base de test, périmée : après une migration, recharger la base de
  test par `db:schema:load`, jamais par `db:migrate`.
- `test/design/design_tokens_test.rb` réserve « Source Serif » aux fichiers de la fiche de cours (`SHEET_EXCEPTION`) : `prepare_sheet.css`
  n'y figure pas (voir le point remonté à l'orchestrateur).

### Lot A — import de l'indice et des sujets

- L'import écrit l'indice (`hint`, nettoyé par `strip`, 1 à 400) et les sujets (`subjects[]` : titre 1 à 200, notions 1 à 600, 10 sujets au
  plus, 10 exercices au plus par sujet, un type inattendu refusé au chemin de la clé). Les exercices d'un sujet se placent après ceux de
  la leçon ; `replace_draft` supprime puis réécrit les sujets et rend `subjects:`. `write` garde sa forme (pas de clé `subjects`).
- Un exercice « avec une notion » = un exercice de sujet portant une clé `notion` non vide (le fichier n'a pas d'autre moyen de citer une
  notion) ; l'erreur est notée à `subjects[i].exercises[j].notion` et porte `subject:` (le titre).
- Fichiers ajoutés au lot par accord de l'orchestrateur : schéma `lnclass.course-tree.v3.json` (`hint`, `subjects`, `subject_exercise` avec
  la clé `notion` ; formes seulement, les bornes restent à l'adaptateur pour que l'erreur soit nommée ; pas de v4 nécessaire), motifs
  `subject_exercise_with_notion`, `too_many_subjects`, `too_many_subject_exercises` dans `ImportError::ELEMENT` (leurs phrases citent le
  sujet ou la leçon), libellés de l'aide, `subjects_created` au rapport (noté seulement quand la leçon porte des sujets), fabrique
  `revision_thales_document`. Un test par `RunImport` couvre l'import Thalès (indices, 3 sujets), CA-9, un type inattendu, un texte trop
  long et le volume.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Navigation aux flèches dans un `radiogroup` (QCM, Vrai ou faux) | La maquette n'a que le clic et le Tab ; chaque proposition reste un bouton atteignable | À décider |
| Brouillon local des questions de type `:other` | Hors maquette ; leur interaction d'aujourd'hui reste telle quelle | À décider |
| Clés `assessment.exercises.card.*` de la carte de leçon, plus utilisées | Fichiers de langue au Lot 0 | Nettoyage à la clôture |
| `sheets/_teacher_bar.html.erb` : version minimale (bascules d'aujourd'hui) | Remplie par le Lot D | Lot D |

## Clôture

| | |
|---|---|
| **Livré le** | AAAA-MM-JJ |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
