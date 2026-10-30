# Plan d'exécution — « Prépare interros » et « Prépare devoirs » à l'identique des maquettes cahier

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Références : [PRD](prd.md) · ADR-XXXX-sujets-de-devoir-et-verification-sur-la-feuille · UDR-XXXX-feuilles-prepare-interros-et-devoirs · [maquettes](maquettes/).

## Graphe

```
Lot 0 — SOCLE (séquentiel)
  ↓
  ├─► Lot A  Importer indice et sujets        ┐ en parallèle
  └─► Lot B  Lire les feuilles (élève)        ┘
                ↓
                ├─► Lot C  Vérifier sur la feuille   ┐ en parallèle
                └─► Lot D  Assigner depuis la feuille ┘
                       ↓ (D)              ↓ (C)
Lot 0b — SOCLE de l'envoi ─► Lot E  Composer un devoir   ┐ en parallèle
                         └─► Lot F  Devoirs reçus en feuilles ┘
```

Vague 1 : Lot 0 → 1 agent · Vague 2 : Lot A ‖ Lot B ‖ Lot 0b → 3 agents · Vague 3 : Lot C ‖ Lot D → 2 agents · Vague 4 : Lot E ‖ Lot F → 2 agents.

> Lot 0b ajouté le 2026-10-30 (devoir composé par l'enseignant, memo Q11 à Q16) : il ne touche aucun fichier des lots A et B.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<ts>_add_hint_to_exercises.rb`
                     `db/migrate/<ts>_create_subjects.rb` · `db/schema.rb`
                     `app/infrastructure/orm/subject.rb` · `app/infrastructure/orm/exercise.rb` · `app/infrastructure/orm/course.rb`
                     `app/domain/entities/catalog/subject.rb`
                     `app/domain/entities/assessment/exercise.rb` *(attribut `hint`)*
                     `app/domain/entities/assessment/sheet_grade.rb`
                     `app/domain/ports/catalog/content_tree_writer_port.rb` *(sujets, indice)*
                     `config/routes/assessment.rb` *(`POST /exercises/:exercise_public_id/sheet_check`)*
                     `config/locales/catalog/courses.fr.yml` · `config/locales/assessment/sheet_checks.fr.yml`
                     `app/assets/stylesheets/prepare_sheet.css` *(les styles des maquettes, classes `.ps-*`)*
                     `test/support/factories/catalog.rb` · `test/support/factories/assessment.rb` *(`create_subject`, `hint:`)*
                     `app/infrastructure/repositories/assessment/exercise_repository.rb` *(`map_to_entity` : `hint`, `subject_id`)* · `test/infrastructure/repositories/assessment/exercise_repository_test.rb`
                     `test/infrastructure/orm/models_test.rb` *(49 modèles)* · `test/infrastructure/repositories/catalog/content_tree_writer_characterization_test.rb` *(`ADDED_LATER`)*
                     `test/design/design_tokens_test.rb` *(`SHEET_EXCEPTION` accepte `prepare_sheet.css`)*
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/sheet_grade_test.rb` · `test/domain/entities/catalog/subject_test.rb`
- **Done quand**   : les migrations passent, `SheetGrade` rend 8 / 10 « Très bien » pour 4 justes sur 5, la contrainte
                     refuse un exercice de sujet rattaché à une notion, et la mesure « avant » du PRD §7 est écrite dans le journal

---

## Lot A — Importer l'indice et les sujets de devoir

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/use_cases/catalog/import_course_tree.rb`
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb`
                     `app/infrastructure/repositories/catalog/import_schema_validator.rb`
                     `app/views/teams/imports/kinds/_course_tree.html.erb` *(l'exemple du fichier)*
                     `config/schemas/lnclass.course-tree.v3.json` · `app/domain/entities/catalog/import_error.rb`
                     `config/locales/teams/imports.fr.yml` · `config/locales/teams/import_course_tree.fr.yml`
                     `test/support/factories/revision_sheet.rb` *(ajoutés en cours de lot, 2026-10-30 : aucun autre lot ne les touche)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/import_course_tree_test.rb` · `test/infrastructure/repositories/catalog/content_tree_writer_test.rb`
- **Done quand**   : l'équipe importe la leçon Thalès avec indices et 3 sujets ; un sujet dont un exercice a une notion est
                     refusé avec une erreur qui nomme le sujet (CA-9)

**Menace écrite d'abord** (le lot lit un fichier envoyé, CLAUDE.md) : le fichier `course_tree` n'est envoyé que par
l'équipe, et seul du texte est ajouté (aucun fichier, aucun chemin, aucune URL).
- **Texte piégé** (`<script>`, HTML) dans `hint`, `title` ou `notions` : stocké brut, rendu échappé par ERB, jamais `html_safe`
  ni `raw` ; un test d'import puis de rendu le prouve.
- **Volume** : `hint` de 1 à 400 caractères après `strip`, `title` de 1 à 200, `notions` de 1 à 600 ; au plus 10 sujets par
  cours et 10 exercices par sujet. Au-delà : erreur d'import nommée, rien n'est écrit (la transaction de l'import d'aujourd'hui).
- **Types** : une clé de type inattendu (nombre, liste, objet à la place d'un texte) est refusée par le validateur de
  schéma, jamais convertie en silence.
- **Rattachement** : un exercice de sujet avec une notion est refusé (CA-9) ; la contrainte de base le garantit aussi.

---

## Lot B — Lire les feuilles « Prépare interros » et « Prépare devoirs »

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/prepare_sheets_query.rb` *(remplace `prepare_interros_query.rb`, supprimé)*
                     `app/controllers/catalog/courses_controller.rb` · `app/controllers/classroom/classroom_courses_controller.rb`
                     `app/views/catalog/courses/show.html.erb` · `app/views/classroom/classroom_courses/show.html.erb`
                     `app/views/catalog/courses/_prepare_sheets.html.erb` *(remplace `_prepare_interros` et `_exercise_row`, supprimés)*
                     `app/views/catalog/courses/sheets/_sheet.html.erb` · `sheets/_exercise.html.erb` · `sheets/_result.html.erb`
                     `app/javascript/controllers/prepare_sheet_controller.js`
                     `app/helpers/assessment/exercise_cards_helper.rb`
                     `test/infrastructure/queries/catalog/prepare_interros_query_test.rb` *(renommé `prepare_sheets_query_test.rb`)*
                     `test/helpers/assessment/exercise_cards_helper_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/catalog/prepare_sheets_query_test.rb` · `test/integration/catalog/prepare_interros_test.rb` · `test/system/catalog/prepare_sheets_test.rb`
- **Done quand**   : un élève voit une feuille par notion et par sujet, à l'identique des maquettes à 390 px et sur ordinateur,
                     avec « À retenir », l'indice, ses réponses gardées au rechargement, un exercice déjà vérifié affiché corrigé,
                     « Refaire l'exercice » et « Recommencer… » qui remettent à blanc (CA-1, 2, 6, 7, 11)

---

## Lot C — Vérifier un exercice sur la feuille

- **Couche**       : domaine + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/check_exercise_on_sheet.rb`
                     `app/controllers/assessment/sheet_checks_controller.rb`
                     `app/views/assessment/sheet_checks/create.turbo_stream.erb`
                     `app/views/assessment/sheet_checks/_error.html.erb`
- **Dépend de**    : Lot B
- **Test associé** : `test/domain/use_cases/assessment/check_exercise_on_sheet_test.rb` · `test/controllers/assessment/sheet_checks_controller_test.rb` · `test/system/assessment/sheet_check_test.rb`
- **Done quand**   : « Vérifier ma réponse » enregistre une copie et remplace l'exercice par sa correction sans changer de page ;
                     la pause, l'exercice archivé et la panne affichent leur message, réponses gardées ; depuis la leçon,
                     un exercice assigné et pas encore rendu est refusé sans copie et affiche « Ce devoir est à rendre… » (CA-3, 4, 5, 10, 17)

---

## Lot D — Assigner depuis la feuille

- **Couche**       : ui
- **Fichiers**     : `app/views/catalog/courses/sheets/_teacher_bar.html.erb`
                     `app/views/classroom/assignments/_toggle.html.erb` *(libellé « Assigner à <classe> » dans la feuille)*
- **Dépend de**    : Lot B
- **Test associé** : `test/system/catalog/prepare_interros_test.rb` *(adapté : « Assigner à <classe> » dans la feuille)*
- **Done quand**   : l'enseignant voit la feuille sans champ ni « Vérifier », clique « Assigner à 3e 1 » et lit
                     « ✓ Assigné à 3e 1 » sans rechargement ; l'équipe voit la feuille sans « Assigner » (CA-8)

> Le Lot B rend `sheets/_teacher_bar` pour un enseignant ; le Lot 0 n'en pose pas de version : le Lot B le crée vide,
> le Lot D le remplit. Le Lot B ne le modifie plus ensuite.

---

## Lot 0b — Socle de l'envoi

- **Couche**       : infrastructure + domaine (contrats) + fichiers partagés
- **Fichiers**     : `db/migrate/<ts>_add_batch_public_id_to_classroom_assignments.rb` · `db/schema.rb`
                     `app/infrastructure/orm/classroom_assignment.rb`
                     `app/domain/entities/classroom/assignment.rb` *(attribut `batch_public_id`)*
                     `app/domain/ports/classroom/assignment_repository_port.rb` *(créer un envoi : `create_batch`)*
                     `app/infrastructure/repositories/classroom/assignment_repository.rb` *(`create_batch`, `batch_public_id` lu et écrit ; passé du Lot E au Lot 0b le 2026-10-30)*
                     `config/routes/classroom.rb` *(`POST /classrooms/:classroom_public_id/assignment_batches`)*
                     `config/locales/classroom/assignments.fr.yml` · `config/locales/classroom/student_classrooms.fr.yml`
                     `test/support/factories/classroom.rb` *(`batch_public_id:`)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/entities/classroom/assignment_test.rb` · `test/db/classroom_assignments_batch_test.rb` · `test/infrastructure/repositories/classroom/assignment_repository_test.rb`
- **Done quand**   : la migration passe, une assignation porte son envoi, le contrat du port est gelé et son adaptateur l'implémente

---

## Lot E — Composer un devoir

- **Couche**       : domaine + infrastructure + delivery + ui
- **Fichiers**     : `app/domain/use_cases/classroom/assign_exercise_batch.rb`
                     `app/controllers/classroom/assignment_batches_controller.rb`
                     `app/views/classroom/assignment_batches/create.turbo_stream.erb`
                     `app/views/catalog/courses/sheets/_batch_bar.html.erb` · `app/views/catalog/courses/sheets/_teacher_bar.html.erb`
                     `app/javascript/controllers/assignment_batch_controller.js`
- **Dépend de**    : Lot 0b, Lot D
- **Test associé** : `test/domain/use_cases/classroom/assign_exercise_batch_test.rb` · `test/controllers/classroom/assignment_batches_controller_test.rb` · `test/system/classroom/assignment_batch_test.rb`
- **Done quand**   : l'enseignant coche 4 exercices dans deux leçons et « Envoyer à 3e 1 » crée 4 assignations d'un même envoi ;
                     un exercice déjà assigné est nommé et écarté ; un autre enseignant est refusé (CA-12, CA-15)

---

## Lot F — Devoirs reçus en feuilles

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/classroom/student_assigned_sheets_query.rb`
                     `app/controllers/classroom/student_classrooms_controller.rb`
                     `app/views/classroom/student_classrooms/show.html.erb` · `_assigned_sheets.html.erb`
                     `app/views/classroom/student_classrooms/_assigned_exercise.html.erb` *(supprimé)*
- **Dépend de**    : Lot 0b, Lot C
- **Test associé** : `test/infrastructure/queries/classroom/student_assigned_sheets_query_test.rb` · `test/system/classroom/assigned_sheets_test.rb`
- **Done quand**   : l'élève voit dans « Ma classe » une feuille par envoi, forme « Prépare devoirs » dès 3 exercices et
                     « Prépare interros » pour 1 ou 2 ; « Rendre à l'enseignant » rattache la copie au devoir, puis seulement la note et la correction ; « Refaire » donne une copie d'entraînement, plus rattachée au devoir (CA-13, 14, 16)

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `db/schema.rb`, `db/migrate/*` | Lot 0 |
| `config/routes/assessment.rb` | Lot 0 |
| `config/locales/catalog/courses.fr.yml`, `config/locales/assessment/sheet_checks.fr.yml` | Lot 0 |
| `app/assets/stylesheets/prepare_sheet.css` | Lot 0 |
| `app/infrastructure/orm/exercise.rb`, `orm/course.rb`, `orm/subject.rb` | Lot 0 |
| `test/support/factories/catalog.rb`, `factories/assessment.rb` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_repository.rb` et son test | Lot 0 |
| `test/infrastructure/orm/models_test.rb`, `content_tree_writer_characterization_test.rb`, `test/design/design_tokens_test.rb` | Lot 0 |
| `app/views/catalog/courses/sheets/_exercise.html.erb`, `_result.html.erb` | Lot B (le Lot C les rend sans les modifier) |
| `app/views/catalog/courses/sheets/_teacher_bar.html.erb` | Lot B le crée vide, Lot D le remplit |
| `test/system/catalog/prepare_interros_test.rb` | Lot D |
| `test/integration/catalog/prepare_interros_test.rb` | Lot B |
| `config/routes/classroom.rb`, `config/locales/classroom/*.fr.yml` | Lot 0b |
| `app/infrastructure/repositories/classroom/assignment_repository.rb` et son test | Lot 0b (le Lot E l'appelle sans le modifier) |
| `app/views/catalog/courses/sheets/_teacher_bar.html.erb` | Lot B le crée, Lot D le remplit, Lot E y ajoute « Choisir » (séquentiel) |
| `app/views/catalog/courses/sheets/_sheet.html.erb` | Lot B (les lots E et F le rendent sans le modifier) |

Critères d'acceptation : CA-1, 2, 6, 7, 11 → Lot B · CA-3, 4, 5, 10 → Lot C · CA-8 → Lot D · CA-9 → Lot A · CA-12, 15 → Lot E · CA-13, 14, 16 → Lot F · CA-17 → Lot C. Aucun orphelin.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests,
> ouvre l'application, refait le parcours nominal *et* un chemin d'erreur (la pause de 3 copies), mesure. **Il ne relit pas
> le code, il le met à l'épreuve.** Il compare chaque feuille aux maquettes, à 390 px et sur ordinateur.
