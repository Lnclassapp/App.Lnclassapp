# Compléments d'inventaire — contexte `assessment` (mission n°4)

> **Explorateur** : mission n°4 de [`prompt-exploration.md`](../prompt-exploration.md) · **Date** : 2026-09-22 · **Branche** : `Teamprocess` (`684ae16`, code applicatif identique au commit inventorié `2449373`).
> **Inventaire vérifié** : [`assessment.md`](assessment.md) · **Décisions confrontées** : ADR-0006, ADR-0008, ADR-0018 (et ADR-0019 pour la simulation) · UDR-0003 · glossaire §4 · `architecture.md` §2.
> **Méthode** : lecture du code, `bin/rails routes`, `git log --all -S`, lecture des sources `actionpack-8.1.3.1`. **Rien n'a été exécuté contre une base** : un état « vérifié » signifie « vérifié en suivant le code appelant jusqu'à la ligne qui échoue ou qui écrit ».
> Ce fichier **constate**. Il ne tranche aucune contradiction : les écarts de la section 4 vont au registre de la feuille de route.

Légende des états : ✅ marche · ⚠️ fragile · ❌ cassé (avec l'erreur) · 💀 jamais exécuté (avec la preuve).
Renvois croisés vers les autres compléments : `CA-xx` ([catalog](complements-catalog.md)), `CL-xx` / `SC-xx` ([school-classroom](complements-school-classroom.md)), `TR-xx` ([transverse](complements-transverse.md)).

---

## 1. Catalogue des features

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| AS-01 | Parcourir la liste de **tous** les exercices de la plateforme | tout connecté | ⚠️ | `exercises`, `essentials`, `teams`, `questions`, `exercise_badges` | `GET /essentials/:essential_id/exercises` | `inventaire/assessment.md#Consulter le catalogue d'exercices` |
| AS-02 | Consulter le détail d'un exercice (questions, meilleur score, Commencer / Reprendre) | tout connecté | ⚠️ | `exercises`, `questions`, `answers`, `exercise_sessions`, `exercise_badges` | `GET /exercises/:id` | `inventaire/assessment.md#Consulter le détail d'un exercice` |
| AS-03 | Créer un exercice par le formulaire | `team` | ❌ | `exercises` | `GET /essentials/:essential_id/exercises/new`, `POST /essentials/:essential_id/exercises` | `inventaire/assessment.md#Créer / modifier un exercice` |
| AS-04 | Modifier un exercice | `team` | ❌ | `exercises` | `GET /exercises/:id/edit`, `PATCH\|PUT /exercises/:id` | `inventaire/assessment.md#Créer / modifier un exercice` |
| AS-05 | Supprimer un exercice (cascade sur toute la production des élèves) | `team` | ✅ | `exercises`, `questions`, `answers`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `classroom_assignments` | `DELETE /exercises/:id` | `inventaire/assessment.md#Supprimer un exercice` |
| AS-06 | Importer des exercices par le « content engine » | `team` | ❌ + 💀 | `exercises`, `questions`, `answers` | `POST /essentials/:essential_id/exercises/import_content_engine` | `inventaire/assessment.md#Importer des exercices (content engine)` |
| AS-07 | Démarrer une session d'exercice | `student` | ✅ | `exercise_sessions` | `POST /exercises/:exercise_id/exercise_sessions` | `inventaire/assessment.md#Démarrer une session d'exercice` |
| AS-08 | Reprendre une session en cours | `student` | ✅ | `exercise_sessions` | `GET /exercise_sessions/:id` | `inventaire/assessment.md#Consulter le détail d'un exercice` (règle « Reprendre ») |
| AS-09 | Répondre aux questions une à une | `student` | ❌ (réponse vide en Turbo) · ⚠️ (re-soumission) | `exercise_sessions`, `question_attempts`, `questions`, `answers` | `GET /exercise_sessions/:id`, `PATCH\|PUT /exercise_sessions/:id` | `inventaire/assessment.md#Répondre aux questions d'un exercice (cœur du moteur)` |
| AS-10 | Voir la correction immédiate d'une réponse (feedback, explication, message d'encouragement) | `student` | ⚠️ | `question_attempts`, `questions`, `answers` | `PATCH /exercise_sessions/:id` | `inventaire/assessment.md#Répondre aux questions d'un exercice (cœur du moteur)` |
| AS-11 | Obtenir un badge à la clôture d'une session | système | ⚠️ (écriture ✅, affichage ❌) | `exercise_badges` | — | `inventaire/assessment.md#Attribution d'un badge` |
| AS-12 | Voir le résultat d'une session | `student` | ⚠️ | `exercise_sessions`, `question_attempts`, `questions`, `answers`, `exercise_badges` | `GET /exercise_sessions/:id/result` | `inventaire/assessment.md#Voir le résultat d'une session` |
| AS-13 | Recommencer un exercice | `student` | ✅ | `exercise_sessions` | `POST /exercises/:exercise_id/exercise_sessions` | `inventaire/assessment.md#Recommencer un exercice` |
| AS-14 | Détecter une lacune après un échec | système | 💀 | `knowledge_gaps` | — | `inventaire/assessment.md#Détecter une lacune après un échec` |
| AS-15 | Résoudre une lacune après une réussite | système | 💀 | `knowledge_gaps` | — | `inventaire/assessment.md#Résoudre une lacune après une réussite` |
| AS-16 | Lancer une session de remédiation | `student` | ❌ | `knowledge_gaps`, `exercises`, `exercise_sessions` | `POST /remediation_sessions` | `inventaire/assessment.md#Lancer une session de remédiation (élève)` |
| AS-17 | Suivre les remédiations de sa classe | `teacher` | ❌ | `knowledge_gaps`, `classroom_students`, `students`, `exercises` | `GET /teachers/classroom_exercises/:slug/remediation` | `inventaire/assessment.md#Suivre les remédiations de sa classe (enseignant)` |
| AS-18 | Assigner un exercice à une classe | `teacher` | ❌ | `classroom_assignments` | `POST /classrooms/:classroom_id/exercises` | `inventaire/assessment.md#Assigner un exercice à une classe` (= CL-20) |
| AS-19 | Retirer un exercice d'une classe | `teacher` | ⚠️ | `classroom_assignments` | `DELETE /classrooms/:classroom_id/exercises/:id` | `inventaire/assessment.md#Retirer un exercice d'une classe` (= CL-20) |
| AS-20 | Voir les exercices d'un chapitre dans une classe (point d'entrée de l'assignation) | `teacher` | ❌ | `essentials`, `exercises`, `classroom_assignments` | `GET /teachers/classrooms/:id/essentials/:essential_id` | `inventaire/assessment.md#Voir la page « chapitre d'une classe »` (= CL-12) |
| AS-21 | Consulter le rapport de synthèse d'un exercice pour une classe | `teacher` | ❌ | `classrooms`, `classroom_students`, `students`, `exercise_sessions`, `exercise_badges` | `GET /teachers/classroom_exercises/:slug` | `inventaire/assessment.md#Rapport de classe — synthèse (enseignant)` |
| AS-22 | Consulter le rapport détaillé (par question, par élève) | `teacher` | ❌ | `classrooms`, `students`, `exercise_sessions`, `question_attempts`, `questions`, `exercise_badges` | `GET /teachers/classroom_exercises/:slug/report` | `inventaire/assessment.md#Rapport de classe — détaillé (enseignant)` |
| AS-23 | Recevoir un message d'encouragement adapté aux résultats de la classe | `teacher` | ❌ | — | `GET /teachers/classroom_exercises/:slug/report` | nouveau |
| AS-24 | Consulter le détail d'un élève (sessions, badges) | `teacher` | ⚠️ (❌ conditionnel, cf. CL-13) | `classrooms`, `classroom_students`, `students`, `users`, `exercise_sessions`, `exercise_badges` | `GET /teachers/classrooms/:classroom_id/students/:public_id` | `inventaire/assessment.md#Consulter le détail d'un élève (enseignant)` (= CL-13) |
| AS-25 | Voir les compteurs de badges de la classe sur la carte d'exercice | `teacher` | ⚠️ | `exercise_badges`, `classroom_students` | — (partiel de carte) | `inventaire/assessment.md#Compteurs de badges de la classe sur la carte d'exercice` |
| AS-26 | Simuler les sessions des élèves de démonstration | système | 💀 | `students`, `users`, `exercise_sessions`, `question_attempts`, `exercise_badges`, `knowledge_gaps` | — | `inventaire/assessment.md#Simulation d'élèves de démonstration (ADR-0019)` (= CL-26) |
| AS-27 | Parcourir le catalogue de sujets d'examen (entraînement / spécial) | `student` | ❌ | `exam_subjects` (**absente**) | `GET /students/examens`, `GET /students/training-examens`, `GET /students/subject-examens` | `inventaire/assessment.md#Sujets d'examen` |
| AS-28 | Consulter un sujet et ses exercices (avec paywall) | `student` | ❌ | `exercise_sessions` (+ `exam_subjects` absente) | `GET /students/examens/:id` | `inventaire/assessment.md#Sujets d'examen` (paywall = TR-19) |
| AS-29 | Refaire un sujet | `student` | ❌ + 💀 | — | `POST /students/examens/:id/retry` | `inventaire/assessment.md#Sujets d'examen` |
| AS-30 | Parcourir la banque de sujets (assignés, favoris, à découvrir) | `teacher` | ❌ (liste toujours vide) | — | `GET /teachers/examens`, `GET /teachers/training-examens`, `GET /teachers/subject-examens` | `inventaire/assessment.md#Sujets d'examen` |
| AS-31 | Consulter un sujet et les classes éligibles | `teacher` | ❌ | `classroom_assignments` | `GET /teachers/examens/:id` | `inventaire/assessment.md#Sujets d'examen` |
| AS-32 | Assigner / retirer un sujet à une classe | `teacher` | ❌ | `classroom_assignments` | `POST /teachers/classroom_exam_assignments`, `DELETE /teachers/classroom_exam_assignments/:id` | `inventaire/assessment.md#Sujets d'examen` (= CL-21) |
| AS-33 | Valider une assignation de sujet | `teacher` | 💀 | `classroom_assignments` | aucune | `inventaire/assessment.md#Sujets d'examen` |
| AS-34 | Gérer la banque de sujets (lister, voir, supprimer) | `team` | ❌ | — | `GET /teams/examens`, `GET /teams/examens/new`, `GET /teams/examens/:id`, `DELETE /teams/examens/:id` | `inventaire/assessment.md#Sujets d'examen` |
| AS-35 | Importer des sujets d'examen en JSON | `team` | ❌ | — | `POST /teams/examens/import_json` | `inventaire/assessment.md#Sujets d'examen` |
| AS-36 | Voir les exercices de ma classe et ma progression sur l'accueil | `student` | ❌ | `classroom_assignments`, `exercises`, `essentials`, `exercise_sessions`, `exercise_badges` | `GET /students` | `inventaire/assessment.md#Accueil élève — exercices de ma classe` (= TR-04, CL-23) |
| AS-37 | Voir ma progression sur la fiche d'un chapitre | `student` | ⚠️ | `exercise_sessions`, `exercise_badges` | `GET /essentials/:id` | `inventaire/assessment.md#Progression de l'élève sur la fiche d'un chapitre` (= CA-11) |
| AS-38 | Créer exercices, questions et réponses par l'import JSON de cours | `team` | ⚠️ | `exercises`, `questions`, `answers` | `POST /courses/import_json` | nouveau (écriture portée par CA-08) |
| AS-39 | Voir l'aperçu des questions sur la carte d'exercice (bonnes réponses réservées à l'enseignant et à l'équipe) | tout connecté | ❌ (fuite des bonnes réponses) | `questions`, `answers` | `GET /essentials/:id`, `GET /essentials/:essential_id/exercises`, `GET /classrooms/:id` | nouveau |
| AS-40 | Voir la durée estimée d'un exercice | — | 💀 | `exercises.questions_count` | — | `inventaire/assessment.md#2` (règle 20) |

**Total : 40 features, dont 3 absentes de l'inventaire (AS-23, AS-38, AS-39).** AS-04, AS-08, AS-10 et AS-40 étaient décrites dans l'inventaire à l'intérieur d'autres fiches ; elles reçoivent leur propre ID pour la traçabilité.

---

## 2. Features absentes de l'inventaire

### AS-23 — Recevoir un message d'encouragement adapté aux résultats de la classe

- **Acteur** : enseignant.
- **Parcours** : lien « Résultats » de la carte d'exercice → Turbo Frame du rapport détaillé → bloc violet « Pour vous » en bas du panneau (`app/views/teachers/classroom_exercises/report.html.erb:162-230`).
- **Règles métier (valeurs exactes)** — le premier cas vrai l'emporte (`report.html.erb:169-219`) :
  1. `completed == 0` (aucun élève n'a terminé) → série « préparation » ;
  2. `mastered_pct >= 80` ;
  3. `mastered_pct >= 60` ;
  4. `mastered_pct >= 40` ;
  5. `needs_support > total / 2.0` ;
  6. sinon → série « chiffres bas ».
  - Chaque série compte **6 messages**. Le message affiché est `teacher_messages[@exercise.id % 6]` (`report.html.erb:225`) : **déterministe par exercice**, pas aléatoire — un enseignant revoit toujours la même phrase pour un exercice donné.
  - `mastered_pct`, `completed`, `total`, `needs_support` sont ceux du rapport détaillé (`app/infrastructure/queries/classroom_report_query.rb:133-138`), donc ils héritent de ses défauts (cf. C-13).
- **Données** : aucune table propre ; lit `report_summary`.
- **État** : ❌ — le rapport qui l'héberge lève `NameError` (`Orm::ClassroomExercise`, `app/controllers/teachers/classroom_exercises_controller.rb:76`).
- **À refaire différemment** : ne pas coder 36 phrases d'interface en dur dans une vue (conventions §1 : `t(".key")`), ni la règle de sélection dans le gabarit.

### AS-38 — Créer exercices, questions et réponses par l'import JSON de cours

- **Acteur** : équipe (`authenticate_team!`, `app/controllers/catalog/courses_controller.rb:13`).
- **Parcours** : `POST /courses/import_json` (un ou plusieurs fichiers) → fichier copié dans `tmp/imports/` → `ImportCoursesJsonJob.perform_later` (`courses_controller.rb:165-186`) → `CourseRepository#bulk_import_courses` (`app/jobs/import_courses_json_job.rb:22`, `app/infrastructure/repositories/catalog/course_repository.rb:109`). Chaque cours porte `essentials[]`, chaque fiche `exercises[]`, chaque exercice `questions[]`, chaque question `answers[]` (`course_repository.rb:162-196`). **C'est aujourd'hui le seul chemin qui crée réellement des questions** (cf. C-01).
- **Règles métier (valeurs exactes)** :
  - exercice : `title` ← `title` ou `name` ; `exercise_type` défaut `"fixation"` (`:172`) ; `published` **forcé à `true`** (`:178`) ; `description` recopiée ; `team_id` **jamais renseigné** (le job ignore son argument `team_id`, `import_courses_json_job.rb:14-22`) ;
  - question : `content`, `question_type` défaut `"single_choice"` (`:193`) ; **`explanation` n'est pas importée** et **`position` n'est jamais renseignée** (`:191-195`) — l'ordre des questions d'une session devient celui, non garanti, de PostgreSQL sur des `NULL` (`get_next_question_query.rb:31`) et la carte affiche « Question » sans numéro (`_question_card.html.erb:12`) ;
  - réponse : `content`, `is_correct` défaut `false` (`:186-187`) ;
  - **aucune validation structurelle** : les règles de `Entities::Assessment::Question` (2 choix / 1 correcte pour `true_false`, etc., `question.rb:49-61`) ne sont jamais traversées ;
  - le titre de l'exercice est mis en `titleize` par `Sluggable` (`app/models/concerns/sluggable.rb:26-27`, via `alias_attribute :name, :title`, `orm/exercise.rb:37`) ;
  - un cours déjà présent (nom titré, niveau, matière) est **sauté entier** (`course_repository.rb:144-146`) : ses exercices ne sont jamais mis à jour ;
  - le résultat de l'import (compteurs, erreurs) est **jeté** par le job : l'acteur ne sait jamais ce qui a été créé.
- **Format constaté dans le dépôt** : `.Business/content_pedagogics/tle_d/*.json` (6 fichiers). Mesure sur ces fichiers : **864 questions**, dont 816 `true_false` (2 réponses, 1 correcte) et 48 `single_choice` (4 réponses, 1 correcte) ; **aucune** `multiple_correct_2` / `multiple_correct_3`, aucune `explanation`.
- **Données** : `exercises`, `questions`, `answers` (+ tables de taxonomie, cf. CA-08).
- **État** : ⚠️ — vérifié par lecture jusqu'au `course.save` (`course_repository.rb:200`), non exécuté. Les causes d'annulation du fichier entier sont listées par CA-08 / C-05 du complément catalog.
- **À refaire différemment** : ne pas perdre l'explication ni l'ordre des questions ; valider la structure de chaque question avant persistance ; rendre compte du résultat à l'acteur ; ne pas publier d'office.

### AS-39 — Voir l'aperçu des questions sur la carte d'exercice

- **Acteur** : tout connecté. Les bonnes réponses sont censées n'apparaître qu'à l'enseignant et à l'équipe.
- **Parcours** : toute carte d'exercice (`app/views/components/_exercise_card.html.erb:72-80`) rend `assessment/exercises/_questions_list` : la première question est visible, les suivantes derrière un bouton « + N autres questions » (Stimulus `read-more`). Pour `team?` ou `teacher?`, chaque réponse est listée avec ✓ pour les correctes (`_questions_list.html.erb:48-61`, `:102-115`). `show_community_validation?` renvoie toujours `false` (`app/helpers/application_helper.rb:80-84`) : l'enseignant voit donc toujours cette liste.
- **Règles métier** :
  - chaque question est enveloppée dans `<% cache question do %>` (`_questions_list.html.erb:24` et `:80`) : la clé ne dépend **que de la question**, pas du rôle de l'utilisateur ;
  - le cache de fragments est actif en production (`config/environments/production.rb:16` `perform_caching = true`, `:50` `solid_cache_store`) ;
  - la modification d'une réponse ne touche pas la question (pas de `touch`, `orm/answer.rb:18`) : le fragment reste périmé ;
  - la page `GET /essentials/:essential_id/exercises` ajoute `cached: true` au rendu de la collection (`assessment/exercises/index.html.erb:14`) : **la carte entière** (menu équipe, badge de l'élève, boutons `button_to` et leurs jetons CSRF) est mise en cache par exercice, sans utilisateur dans la clé.
- **Données** : `questions`, `answers`.
- **État** : ❌ — le premier rendu d'une question fixe son contenu pour tous : si un enseignant ou un membre de l'équipe affiche la fiche `/essentials/:id` (CA-11, ✅) avant un élève, **l'élève reçoit les bonnes réponses cochées** ; dans l'autre ordre, l'enseignant ne les voit pas. Vérifié par lecture, non exécuté.
- **À refaire différemment** : aucun contenu qui dépend du rôle ou de l'utilisateur dans un fragment dont la clé ne les contient pas ; les bonnes réponses ne doivent jamais figurer dans le HTML envoyé à un élève avant sa réponse.

---

## 3. Corrections de l'inventaire

### 3.1 Sondage des règles chiffrées de `assessment.md`

| # | Règle de l'inventaire | Verdict | Preuve |
|---|---|---|---|
| S-1 | Paliers de badge `>= 100` or · `>= 80` argent · `>= 50` bronze | ✅ exacte | `app/domain/entities/assessment/exercise_badge.rb:41-46` |
| S-2 | Remplacement du badge seulement si poids **strictement** supérieur (1/2/3) | ✅ exacte | `exercise_badge.rb:55-56` |
| S-3 | Seuil de réussite `percentage >= 50` | ✅ exacte | `app/domain/entities/assessment/exercise_session.rb:95` |
| S-4 | Maîtrise à 70 % ; étiquettes `>= 70` Maîtrisé · `>= 50` À surveiller · sinon À réviser | ✅ exacte | `app/infrastructure/queries/classroom_report_query.rb:130` ; `app/views/teachers/classroom_exercises/report.html.erb:63-68` |
| S-5 | `score_on_20 = round(best_pct / 5)` | ✅ exacte | `classroom_report_query.rb:122` |
| S-6 | Cache 1 h, clés `classroom_report_stats:` / `classroom_report_detailed:` | ✅ exacte | `classroom_report_query.rb:20`, `:62` |
| S-7 | Simulation : 70 % de bonnes réponses, durée 5 à 20 min, `total_questions + 1` | ✅ exacte | `app/domain/use_cases/assessment/simulate_demo_student_session.rb:79`, `:115`, `:91` |
| S-8 | Confettis si `>= 50`, pendant 3 s | ✅ exacte | `app/javascript/controllers/confetti_controller.js:20`, `:26` |
| S-9 | Validations structurelles des 4 types de question | ✅ exacte | `app/domain/entities/assessment/question.rb:49-61` |
| S-10 | Durée estimée `ceil(n × 1,5)`, minimum 1 | ✅ exacte | `app/domain/entities/assessment/exercise.rb:58-59` |
| S-11 | `success_rate = round(correct / effectif × 100)` | ❌ incomplète — voir C-13 | `classroom_report_query.rb:76-98` |
| S-12 | Distribution des badges « sur 3 paliers » | ❌ fausse — voir C-12 | `app/views/teachers/classroom_exercises/show.html.erb:49-64` |

### 3.2 Affirmations fausses ou incomplètes

| # | L'inventaire dit | Constat | Preuve |
|---|---|---|---|
| C-01 | Le content engine est « **le seul moyen théorique de créer des questions** » (§ Importer ; § Ce que je n'ai pas pu déterminer, n°1). | **Faux.** L'import JSON de cours crée exercices, questions et réponses (AS-38). Quant à `Exercises::ContentEngineImportService`, il n'a **jamais existé dans aucun commit d'aucune branche** : `git log --all -S "class ContentEngineImportService"` est vide, alors que le premier commit (`3123b57`, 2026-08-14) l'appelle déjà. Aucune vue ne pointe vers la route : elle n'est atteignable que par une requête forgée (💀 + ❌). | `course_repository.rb:169-196` ; `3123b57:app/controllers/exercises_controller.rb:120` ; `grep -rn import_content_engine app/views` vide |
| C-02 | Format du JSON d'import introuvable, « aucun exemple n'est présent ». | **Incomplet.** Le format propre au content engine reste inconnu, mais deux formats voisins sont versionnés : **cours** (`.Business/content_pedagogics/tle_d/*.json` : cours → `essentials[]` → `exercises[] {title, description, exercise_type, questions[] {content, question_type, answers[] {content, is_correct}}}`) et **sujet d'examen** (`.Business/content_pedagogics/data/Exams/*.json`, `.Business/content_pedagogics/Examens/SUJETS/PREPA_BAC/**/*.json` : `title, exam_category, exam_type, year, material_name, series_names[], learning_objectives, duration, description, exercises[] {title, questions[] {content, question_type, explanation, answers[]}}`). | fichiers cités ; `app/domain/use_cases/assessment/import_exam_subject_json.rb:40-54` attend les mêmes clés (+ `level_name`) |
| C-03 | Modèle de données des sujets d'examen impossible à reconstituer. | **Précisé.** Aucune migration ni table `exam_subjects` dans **tout** l'historique ; le dépôt de sujets était déjà un stub avant le commit `0991bd3`. Les indices de schéma sont : l'entité, la liste d'attributs de l'import, les JSON de `.Business/` et la vue élève (règles de C-25). | `git log --all -- 'db/migrate/*exam*'` vide ; `0991bd3^:app/infrastructure/repositories/assessment/exam_repository.rb` ; `import_exam_subject_json.rb:40-54` |
| C-04 | Sujets : « **l'import plante** ». | **Faux.** `find_by_title` et `create_with_exercises` n'existent ni dans le port ni dans le stub, mais l'appel est dans un `begin … rescue => e` : chaque sujet produit « Erreur pour '<titre>' : undefined method… », et l'équipe est redirigée avec une alerte. Pas d'erreur 500. | `import_exam_subject_json.rb:36`, `:55`, `:57` ; `app/domain/ports/assessment/exam_repository_port.rb` |
| C-05 | Sujets : « un enseignant ne peut assigner un sujet que si niveau == niveau de la classe **et** série compatible… » | **Faux comme règle serveur.** Ce filtre ne sert qu'à choisir les classes affichées sur la fiche du sujet. Le `POST` appelle `UseCases::Classroom::AssignExamToClassroom` et le `DELETE` `RemoveExamAssignment`, **supprimés par le commit `0991bd3`** (2026-08-29) → `NameError`. Le use case supprimé ne vérifiait que `ClassroomAccessPolicy`, aucun niveau ni série. | `app/controllers/teachers/exam_subjects_controller.rb:56-59` ; `app/controllers/teachers/classroom_exam_assignments_controller.rb:19`, `:43` ; `0991bd3^:app/domain/use_cases/classroom/assign_exam_to_classroom.rb` |
| C-06 | Sujets : « Validation d'assignation : passage du statut à `validated` ». | **Incomplet.** `ValidateExamAssignment` n'a **ni route ni appelant** → 💀 (AS-33). | `grep -rn ValidateExamAssignment app config` : seule sa définition |
| C-07 | « Si la production tourne réellement avec ce code » : indéterminé (§ 3, n°7). | **Daté.** Les `NameError` sur `Orm::ClassroomExercise` / `Orm::ClassroomEssential` et l'absence des use cases d'assignation de sujet viennent toutes du commit `0991bd3` du **2026-08-29**, qui a supprimé `orm/classroom_exercise.rb`, `orm/classroom_essential.rb`, `assign_exam_to_classroom.rb`, `remove_exam_assignment.rb` et les tables `classroom_exercises` / `classroom_essentials` / `classroom_courses`. Un déploiement antérieur au 29/08 avait des chemins fonctionnels. | `git show --stat 0991bd3` |
| C-08 | Assigner / Retirer : ❌ `ActionView::MissingTemplate`. | **Inexact.** Pour une requête Turbo non-GET sans gabarit, Rails 8.1 répond **`204 No Content`**, sans lever d'erreur. L'écriture en base a donc lieu, la réponse est vide, le bouton ne change pas et le flash est perdu. En plus : (a) **réassigner après un retrait lève `ActiveRecord::RecordNotUnique`** — la recherche filtre les `archived`, un nouvel enregistrement est créé et heurte l'index unique ; la « réactivation » décrite par l'inventaire n'est atteignable que si l'entité porte un `id`, ce que `CreateClassroomExercise` ne fait jamais (cohérent avec CL-20) ; (b) si la sauvegarde échoue, `result.classroom_exercise` est `nil` et la ligne 24 lève `NoMethodError` **avant** le test de succès ; (c) aucune vérification que l'exercice existe ou est publié (`exercise_repo` non injecté). | `actionpack-8.1.3.1/lib/action_controller/metal/implicit_render.rb:47-52`, `:63-64` ; `app/infrastructure/repositories/classroom/classroom_assignment_repository.rb:19`, `:41`, `:46` ; `db/schema.rb:72` ; `app/domain/use_cases/assessment/create_classroom_exercise.rb:20-24`, `:36-39`, `:41-49` ; `app/controllers/assessment/classroom_exercises_controller.rb:20-24` |
| C-09 | Règle 15 : `assigned_by_id` reçoit un id de profil enseignant, « incohérence de référence ». | **Plus grave.** C'est une **clé étrangère SQL vers `users`**. Avant `0991bd3`, elle pointait vers `teachers`. Aujourd'hui, un `teachers.id` sans `users.id` égal lève `PG::ForeignKeyViolation`, sinon la ligne désigne un autre utilisateur. | `db/schema.rb:573` ; diff de `db/schema.rb` dans `0991bd3` ; `create_classroom_exercise.rb:48` ; `classroom_exercises_controller.rb:21` |
| C-10 | Répondre : « Réponse vide → refus… la question est re-rendue, statut 422 en HTML ». | **Incomplet.** Le formulaire vit dans un Turbo Frame, donc la réponse est demandée en `turbo_stream`. Ce chemin rend le partiel `exercise_sessions/question_card`, qui **n'existe pas** (le vrai est `assessment/exercise_sessions/_question_card`) → `ActionView::MissingTemplate`, erreur 500. Il suffit de cliquer « Valider » sans cocher (aucun `required`). Même corrigé, `replace` supprimerait le frame et le message d'erreur. | `app/controllers/assessment/exercise_sessions_controller.rb:85-89` ; `ls app/views/exercise_sessions` → absent ; `_question_card.html.erb:33-41` |
| C-11 | « Un `QuestionAttempt` est unique par (session, question) → réponse idempotente. » | **Incomplet, et contraire à ADR-0008.** Re-soumettre une question déjà répondue (requête forgée ou double envoi) est accepté : l'entité **ajoute** une tentative à celles déjà chargées. Le compte d'avancement inclut le doublon, ce qui clôt la session trop tôt, et le score compte deux fois la bonne réponse. En base, la ligne existante est **écrasée** : un élève peut corriger sa réponse après avoir vu le corrigé en vert. Le `question_id` n'est jamais vérifié comme appartenant à l'exercice de la session. Une session `abandoned` reste jouable : seule `completed` est refusée. | `exercise_session.rb:62`, `:66`, `:89` ; `app/infrastructure/repositories/assessment/exercise_execution_repository.rb:37-43` ; `app/domain/use_cases/assessment/submit_question_attempt.rb:34-46` ; `exercise_sessions_controller.rb:44` |
| C-12 | Rapport de synthèse : « Distribution des badges affichée sur 3 paliers : Bronze / Argent / Or ». | **Faux.** 4 tuiles, dont **Diamant** ; bloc masqué si aucun badge. Dans la liste par élève, le niveau s'affiche en anglais (`"silver".capitalize` → « Silver »). | `teachers/classroom_exercises/show.html.erb:45-64`, `:107` |
| C-13 | Rapport détaillé : `success_rate = round(correct / effectif × 100)`. | **Incomplet.** Le numérateur compte les tentatives de **toutes** les sessions complétées de tous les élèves, reprises comprises. Avec des élèves qui recommencent, `success_rate` peut dépasser 100 % et `not_attempted` devenir négatif. Les questions y sont numérotées **par `id`**, alors que l'élève les voit par `position` : « Q3 » du rapport n'est pas forcément la 3ᵉ question vue. | `classroom_report_query.rb:76-98`, `:87` ; `get_next_question_query.rb:31` |
| C-14 | « Diamond » affiché par 4 vues, dont `exam_subjects/show`. | **Faux sur la liste.** `students/exam_subjects/show` ne connaît pas `diamond` (tout niveau inconnu y devient « Bronze »). « Diamant » apparaît dans : `_exercise_card.html.erb:94`, `_exercise_badge.html.erb:13-14`, `teachers/classroom_exercises/show.html.erb:61-64`, `:89`, `teachers/classrooms/student_detail.html.erb:55`, `:94`, `teachers/classrooms/_student_row.html.erb:21`, `students/feed/content/_exercises.html.erb:70-71` — et **la landing le promet aux visiteurs** (`homepage/index.html.erb:164`). | fichiers cités ; `students/exam_subjects/show.html.erb:134-140` |
| C-15 | « Deux copies de `student_detail` existent — une des deux est morte. » | **Incomplet.** Tout le répertoire `app/views/classroom/teachers/classrooms/` (10 fichiers, identiques) est mort : le contrôleur force `controller_path` à `"teachers/classrooms"`. | `app/controllers/classroom/teachers/classrooms_controller.rb:13-15` ; `diff -rq` des deux répertoires : aucune différence |
| C-16 | `close=true` rend le même template sans données, « panneau vide ». | **Vrai pour `report` seulement** (garde `@report_summary.present?`). Pour `remediation`, `@gaps_by_status` vaut `nil` → `NoMethodError` sur `.empty?`. | `report.html.erb:6` ; `remediation.html.erb:25` ; `teachers/classroom_exercises_controller.rb:40-44` |
| C-17 | Remédiation : ❌ « sur deux points indépendants ». | **Trois.** Le bouton de la carte appelle `assessment_remediation_sessions_path`, helper inexistant (la route s'appelle `remediation_sessions`) → `NameError` dès qu'une lacune serait trouvée. | `_exercise_card.html.erb:123` ; `bin/rails routes` : `remediation_sessions POST /remediation_sessions` |
| C-18 | « Les use cases `GenerateDemoStudents` et `PurgeDemoStudents` n'existent pas dans `app/domain/use_cases/`. » | **Faux.** Ils existent dans `app/domain/use_cases/classroom/`. `GenerateDemoStudents` est appelé par un job (cf. CL-24, CL-25, CL-27). | `generate_demo_students.rb:18` ; `purge_demo_students.rb:24` ; `app/jobs/catalog/generate_school_demo_data_job.rb:24` |
| C-19 | Simulation : `CompleteExerciseSession` « réévalue tout ». | **Incomplet.** Pour une question à réponses multiples, les valeurs attendues mêlent **ids et contenus** : un tableau fourni ne peut jamais leur être égal, la réponse est toujours fausse. La simulation envoie un **seul** id, qui passe par `include?` et compte juste. Code mort, mais règle à ne pas reproduire. | `app/domain/use_cases/assessment/complete_exercise_session.rb:75-81` ; `question_attempt.rb:37-41` ; `simulate_demo_student_session.rb:76` |
| C-20 | Rapport détaillé : seuils par question seulement. | **Incomplet.** Chaque élève reçoit aussi un statut : `best_pct >= 70` « Acquis », `>= 50` « Fragile », `< 50` « En difficulté », `nil` « Non fait ». Mêmes seuils pour la couleur du score dans la synthèse. | `report.html.erb:114-131` ; `teachers/classroom_exercises/show.html.erb:91` |
| C-21 | Détail d'un élève : « historique des sessions complétées… avec badge par session ». | **Incomplet.** La page affiche aussi un compteur et un **mur de tous les badges de l'élève**, tous exercices confondus, pas seulement ceux de la classe. `badge.exercise.essential.name` plante si l'exercice n'a pas de chapitre. Les niveaux s'affichent en anglais. | `teachers/classrooms/student_detail.html.erb:45-61` ; `app/infrastructure/queries/teacher_classroom_query.rb:33-38` |
| C-22 | Progression sur la fiche d'un chapitre : ✅. | **⚠️.** La fiche liste aussi les exercices **non publiés** (aucun filtre). Chaque carte recharge questions et réponses (N+1). Elle est le lieu principal de la fuite AS-39. | `app/infrastructure/queries/catalog_query.rb:33-39` ; `_exercise_card.html.erb:12` |
| C-23 | Catalogue d'exercices : ⚠️ « filtrage absent ». | **Incomplet.** La page n'est liée nulle part : `essential_exercises_path` n'apparaît que comme URL du formulaire. Surtout, `cached: true` met en cache la carte entière par exercice, sans utilisateur dans la clé (AS-39). | `grep -rn essential_exercises_path app/views` → `_form.html.erb:4` seul ; `index.html.erb:14` |
| C-24 | Créer un exercice : ❌ par `Entities::Question` / `Entities::Answer`. | **Causes supplémentaires.** (a) Le contrôleur Stimulus `nested-form` n'existe pas : « + Ajouter une question » est inerte. (b) `import_data` est dans la liste blanche mais pas dans `ExerciseDto` → `ActiveModel::UnknownAttributeError` si le champ est envoyé. (c) Le titre est mis en `titleize` à l'enregistrement. (d) Le formulaire d'édition rend le même partiel → AS-04 est cassée pour la même raison. | `_form.html.erb:8`, `:56` ; `ls app/javascript/controllers` ; `exercises_controller.rb:171` ; `app/domain/dtos/exercise_dto.rb:19` ; `sluggable.rb:26-27` ; `edit.html.erb:7` |
| C-25 | Sujets d'examen : index qui « affichent une liste vide », règles lisibles dans les vues. | **Précisé.** `/teachers/examens` ne plante pas : le stub renvoie `[]`. `@assigned_subject_ids` y est **codé à `[]`**, donc « assignés » est toujours vide, et les « favoris » sont un `shuffle` aléatoire. Fiche élève d'un sujet : « Traité » dès une session complétée, « Compris » si le meilleur score est **≥ 75 %** (un 4ᵉ seuil), note **sur 10** = `percentage / 10` arrondi à 1 décimale ; le badge y est lu dans `session.badge_level`, jamais écrit. | `teachers/exam_subjects_controller.rb:74-121`, `:90`, `:116` ; `students/exam_subjects/show.html.erb:90-96`, `:92` |

---

## 4. Écarts avec les décisions

> Rangs (cf. [`docs/README.md`](../../../README.md#hiérarchie-des-sources-de-vérité)) : ADR/UDR = 1 · conventions = 2 · glossaire, `architecture.md` = 5 · inventaire = 6 · code = 7. **Aucun écart n'est tranché ici.**

| # | Sujet | Source A dit | Source B dit | Qui devrait trancher |
|---|---|---|---|---|
| E-01 | Paliers de badge existants | **ADR-0008** §1, §3 : Bronze, Argent, Or | **UDR-0003** §1, §3 : « Badges : Argent, Or, **Diamant** » (aucun Bronze) ; la landing promet « Or, Argent, Diamant » (`homepage/index.html.erb:164`) ; la carte suit l'UDR et omet Bronze (`_exercise_card.html.erb:91-95`) | **Rang 1 contre rang 1** → ADR + UDR de remplacement explicite (registre des contradictions) |
| E-02 | Seuil de l'Or | **ADR-0008** §3 : « ≥ 80 % pour l'Or » | **Glossaire** §4 et **`architecture.md`** §2.7 : Or = 100 %, Argent ≥ 80 %, comme le code (`exercise_badge.rb:41-46`) | ADR remplaçant ADR-0008 ; glossaire et architecture à aligner ensuite (rang 5 < rang 1) |
| E-03 | Règle de remplacement du badge | **ADR-0008** §5 : `>=` | Code : `>` strict (`exercise_badge.rb:56`) | ADR remplaçant ADR-0008 |
| E-04 | Statuts d'une session | **ADR-0008** §3 : `:in_progress / :completed` | **Glossaire** §4 et code : `started / completed / abandoned` (`exercise_session.rb:32-36`) | ADR remplaçant ADR-0008 |
| E-05 | Moteur de correction | **ADR-0008** §3 : `CompleteExerciseSession` est central et compare des **contenus** ; §6 : la logique vit dans `ExerciseSession#evaluate_and_award_badges!` | Code : le vrai parcours passe par `SubmitQuestionAttempt` et compare des **ids** ; `evaluate_and_award_badges!` n'existe pas (`grep`). **`architecture.md` §2.7** présente `SubmitQuestionAttempt` comme « le meilleur exemple du dépôt », alors qu'il contourne ADR-0018 | ADR remplaçant ADR-0008 (un seul use case de clôture ; ids ou contenus) |
| E-06 | Immuabilité des réponses | **ADR-0008** §1-2 : empêcher qu'un élève re-soumette après avoir vu le corrigé | Code : une question déjà répondue est **ré-écrasable** tant que la session est ouverte, et le doublon fausse le score (C-11) | ADR-0008 fait déjà autorité : le PRD de la vague le reprend comme exigence |
| E-07 | Échelle de note montrée à l'élève | **ADR-0008** §4 : l'élève voit « son score sur 100 %, sa note sur 20 et son badge » | Code : l'élève voit le % seul, badge jamais affiché (C-12 de l'inventaire, `result.html.erb:13-17`) ; /20 réservé au rapport enseignant ; /10 sur la fiche d'un sujet (C-25) | UDR de l'écran de résultat + ADR « barème » (voir E-15) |
| E-08 | Déclenchement du cycle des lacunes | **ADR-0018** §3.1 : `DetectKnowledgeGaps` « exécuté lors de l'échec d'une session », « génère **un ou plusieurs** » gaps | Code : seul `CompleteExerciseSession` (simulation morte) le déclenche ; au plus **une** lacune par session (celle du chapitre) | ADR remplaçant ADR-0018 (granularité et point d'appel) |
| E-09 | Nommage des classes des lacunes | **ADR-0018** §3.2 : `Ports::KnowledgeGapRepository`, `Infrastructure::Repositories::KnowledgeGapRepository`, `Entities::KnowledgeGap` à la racine | **Conventions** §2 (l. 57) : « tout est namespacé par contexte borné ; un fichier à la racine est du legacy ». Code : alias racine + version `Assessment::` (`repositories/knowledge_gap_repository.rb`, `ports/knowledge_gap_repository_port.rb`, `use_cases/{detect,resolve}_knowledge_gaps.rb`, `use_cases/generate_remediation_session.rb`) ; `Entities::KnowledgeGap` et `Entities::ExamSubject` restent à la racine | **ADR contre conventions** → registre des contradictions ; ADR remplaçant §3.2 |
| E-10 | Libellé de la colonne `self_corrected` | **ADR-0018** §3.3 : « Auto-améliorés » | Vue : « Auto-corrigés » (`remediation.html.erb:52`) | UDR du panneau de remédiation (aucune UDR ne le couvre) |
| E-11 | Traçabilité d'une session de remédiation | **ADR-0018** §3.1 : `remediated` si la réussite vient de la remédiation | Aucune colonne ne marque la session ; le flag `is_remediation` n'existe que le temps d'un appel (inventaire) : la distinction est impossible pour une session réelle | ADR remplaçant ADR-0018 (modèle de données) |
| E-12 | Simulation des élèves démo | **ADR-0019** §2.3 : lancée « lorsqu'un exercice est assigné » ; boost « +60 % pour les plus faibles » | Code : job jamais mis en file ; boost = **100 %** dès qu'une lacune `pending` existe (`simulate_demo_student_session.rb:79`) | ADR remplaçant ADR-0019 |
| E-13 | Lecture sans use case | **ADR-0006** §3.2 : les pages de listing, de feed et de tableau de bord « n'appellent **jamais** de Use Case » | Code : `GetExerciseReport` (`teachers/classroom_exercises_controller.rb:17`, `:31`), `GetStudentFeed` (`students/feed_controller.rb`), `GetExamSubjects` / `GetExamSubjectDetails` ; des vues appellent des **repositories** et des queries par carte (`_exercise_card.html.erb:90`, `:119`, `:145`) → N requêtes par page | ADR-0006 fait autorité ; à reprendre comme exigence du PRD cadre |
| E-14 | Injection des dépendances | **`architecture.md`** §2.2 : le choix de l'adaptateur se fait dans le contrôleur « et nulle part ailleurs » | 20 fichiers de `app/domain/` instancient `Repositories::…` en valeur par défaut (ex. `complete_exercise_session.rb:38`, `generate_remediation_session.rb:44-46`, `create_classroom_exercise.rb:21`) ; `RemediationSessionsController:20` n'injecte rien ; le garde-fou ne cherche que `ActiveRecord`, `ApplicationRecord`, `Orm::` (`test/domain/domain_purity_test.rb:19-22`) | ADR (dépendances autorisées du domaine) + garde-fou de la phase 0 |
| E-15 | Seuils pédagogiques | **ADR-0008** : 80 (Or) ; **ADR-0018** : 50 (échec / réussite) | Code : cinq seuils non nommés — 50 (réussite, bronze, confettis, « Félicitations »), 70 (maîtrise, « Acquis »), **75** (« Compris », sujets d'examen), 80 et 100 (badges) | ADR « barème pédagogique » (décision de fondation) |
| E-16 | Contrat visuel du moteur | **UDR-0003** §3 : Or `bg-yellow-50 text-yellow-600 border-yellow-200`, Argent `bg-slate-100 text-slate-500 border-slate-200`, Diamant `bg-cyan-50…` ; `_question_card` en `rounded-2xl` ; erreur « affichée au-dessus de la question » | `_exercise_badge.html.erb:13-20` utilise d'autres classes ; `_question_card.html.erb:7` `rounded-[var(--radius-ln)]` ; l'erreur en Turbo produit une 500 (C-10) | UDR-0003 fait autorité ; le code n'est pas conforme (à inscrire, pas à arbitrer) — sauf si E-01 la remplace |
| E-17 | Stockage de la réponse de l'élève | **Glossaire** §4 : `QuestionAttempt` « stocke la donnée brute dans `answer_data` (jsonb) » | Code : `answer_data` et `attempted_answer_ids` jamais écrits ; la réponse va dans `provided_answer` (texte) ; un tableau y est stocké sous sa forme `inspect` Ruby (`exercise_execution_repository.rb:41-42`, `:83-84`) | ADR (modèle d'une tentative), puis correction du glossaire |
| E-18 | Vocabulaire « tentative » | **Glossaire** §4 : « tentative » = `QuestionAttempt` ; « session d'exercice » = `ExerciseSession` | UI enseignant : KPI « Tentatives » et « N tentatives » comptent des **sessions** (`teachers/classroom_exercises/show.html.erb:37`, `:113`) | UDR de vocabulaire (ou correction de la vue) |
| E-19 | Mot « Quiz » | **Glossaire** §8 : ne jamais écrire `Quiz` | **UDR-0003** §2 : « Quiz interactif » ; `_empty_state.html.erb:11` : « Créez des quiz interactifs » | Glossaire (rang 5) contre UDR (rang 1) : l'UDR l'emporte ou est remplacée — à arbitrer |
| E-20 | Rattachement d'un exercice | **Glossaire** §3 : `Exercise` = série de questions « rattachée à un `Essential` » ; `ExamSubject` porte des exercices | Schéma : `exercises.essential_id` nullable ; aucune table de liaison sujet ↔ exercice ; les vues appellent `exercise.exam_subjects` (association inexistante) | ADR (modèle `ExamSubject` ↔ `Exercise`) — bloque AS-27 à AS-35 |
| E-21 | Conservation de l'historique d'assignation | **ADR-0016** : le retrait archive, la ligne reste | Réassigner après retrait lève `RecordNotUnique` (C-08) ; `assigned_by_id` pointe vers `users` mais reçoit un id enseignant (C-09) | ADR-0016 fait autorité ; ADR (référence de `assigned_by`) — cf. CL-20 |
| E-22 | Interface en français via `t(".key")` | **Conventions** §1 | Toutes les chaînes du contexte sont en dur (contrôleurs, 36 phrases de `report.html.erb:169-223`), sauf `gamification.fr.yml` ; niveaux affichés en anglais (C-12, C-21) | Conventions font autorité (constat) |
| E-23 | En-tête HITL | **Conventions** §5 : 3 lignes maximum | Contexte entier : en-têtes de 10 à 31 lignes (`complete_exercise_session.rb:1-31`) ; `orm/classroom_assignment.rb` sans en-tête | Conventions font autorité (constat) |
| E-24 | Sécurité — bonnes réponses | Inventaire et `exercises/show` : bonnes réponses « jamais à l'élève » | Fuite par cache de fragments (AS-39) | À inscrire dans [`securite.md`](../securite.md) (🔴 proposé) + exigence du PRD cadre |
| E-25 | Sécurité — toasts de l'import de sujets | Conventions §7 / pratique Rails : pas de `html_safe` sur une donnée externe | `e.message` et les titres du JSON importé sont interpolés dans un attribut HTML puis `html_safe` (`app/controllers/teams/exam_subjects_controller.rb:64`, `:83`, `:124`) → injection HTML par un fichier importé | À inscrire dans [`securite.md`](../securite.md) (🟡 proposé) |

---

## 5. Couverture

### 5.1 Tables

| Table | IDs | Remarques |
|---|---|---|
| `exercises` | AS-01 à AS-07, AS-20, AS-36 à AS-40 | Colonnes mortes : `import_data` (jamais écrite ; permise par le contrôleur, absente du DTO), `recurrence_rate` (jamais lue ni écrite), `source_exam` (lue par un fil d'Ariane, `teachers/classroom_exercises/show.html.erb:16`, jamais écrite). `exercise_type` n'a aucun effet métier (affichée seulement par `students/exam_subjects/show.html.erb:108`) |
| `questions` | AS-02, AS-03, AS-06, AS-09, AS-10, AS-22, AS-38, AS-39 | `position` jamais écrite par aucun chemin (C-01, AS-38) |
| `answers` | AS-02, AS-09, AS-10, AS-12, AS-38, AS-39 | — |
| `exercise_sessions` | AS-07 à AS-13, AS-21, AS-22, AS-24, AS-26, AS-28, AS-36, AS-37 | `badge_level` lue par 4 vues, jamais écrite |
| `question_attempts` | AS-09, AS-10, AS-12, AS-22, AS-26 | `attempted_answer_ids`, `answer_data` : jamais écrites |
| `exercise_badges` | AS-01, AS-02, AS-11, AS-12, AS-21, AS-22, AS-24, AS-25, AS-36, AS-37 | — |
| `knowledge_gaps` | AS-14 à AS-17, AS-26 | Vide en pratique : aucun chemin vivant n'y écrit |
| `classroom_assignments` | AS-18, AS-19, AS-20, AS-31, AS-32, AS-33, AS-36 | Table partagée ; propriétaire CL |
| `exam_subjects` | AS-27 à AS-35 | **N'existe pas**, ni dans le schéma ni dans l'historique (C-03) |
| `classroom_students`, `students`, `users` | lues par AS-17, AS-21, AS-22, AS-24, AS-25, AS-26 | Propriétaire CL / ID |

### 5.2 Routes

| Route | IDs |
|---|---|
| `GET /essentials/:essential_id/exercises` | AS-01, AS-39 |
| `GET /essentials/:essential_id/exercises/new` · `POST /essentials/:essential_id/exercises` | AS-03 |
| `POST /essentials/:essential_id/exercises/import_content_engine` | AS-06 (💀 : aucun lien ; ❌ : service jamais écrit) |
| `GET /exercises/:id` | AS-02 |
| `GET /exercises/:id/edit` · `PATCH\|PUT /exercises/:id` | AS-04 |
| `DELETE /exercises/:id` | AS-05 |
| `POST /exercises/:exercise_id/exercise_sessions` | AS-07, AS-13 |
| `GET /exercise_sessions/:id` | AS-08, AS-09 |
| `PATCH\|PUT /exercise_sessions/:id` | AS-09, AS-10, AS-11 |
| `GET /exercise_sessions/:id/result` | AS-12 |
| `POST /remediation_sessions` | AS-16 |
| `POST /classrooms/:classroom_id/exercises` | AS-18 |
| `DELETE /classrooms/:classroom_id/exercises/:id` | AS-19 |
| `GET /teachers/classroom_exercises/:slug` | AS-21 |
| `GET /teachers/classroom_exercises/:slug/report` | AS-22, AS-23 |
| `GET /teachers/classroom_exercises/:slug/remediation` | AS-17 |
| `GET /students/examens` · `GET /students/training-examens` · `GET /students/subject-examens` | AS-27 |
| `GET /students/examens/:id` | AS-28 |
| `POST /students/examens/:id/retry` | AS-29 (💀 : `retry_students_exam_subject_path` n'est utilisé par aucune vue) |
| `GET /teachers/examens` · `GET /teachers/training-examens` · `GET /teachers/subject-examens` | AS-30 |
| `GET /teachers/examens/:id` | AS-31 |
| `POST /teachers/classroom_exam_assignments` · `DELETE /teachers/classroom_exam_assignments/:id` | AS-32 |
| `GET /teams/examens` · `GET /teams/examens/:id` · `DELETE /teams/examens/:id` | AS-34 |
| `GET /teams/examens/new` | AS-34 (💀 : `new_teams_exam_subject_path` n'est utilisé par aucune vue ; l'import est intégré à l'index) |
| `POST /teams/examens/import_json` | AS-35 |
| Routes partagées, possédées ailleurs | `GET /teachers/classrooms/:id/essentials/:essential_id` → AS-20 (CL-12) · `GET /teachers/classrooms/:classroom_id/students/:public_id` → AS-24 (CL-13) · `GET /students` → AS-36 (TR-04) · `GET /essentials/:id` → AS-37, AS-39 (CA-11) · `GET /classrooms/:id` → AS-39 et points d'entrée de AS-16 / AS-18 (CL-14) · `POST /courses/import_json` → AS-38 (CA-08) |

### 5.3 Code mort du périmètre (preuves)

| Élément | Preuve |
|---|---|
| `SimulateClassroomExerciseJob`, `SimulateDemoStudentSession`, `CompleteExerciseSession` (hors tests) | aucun `perform_later` ni appel hors du job lui-même (`grep -rn` sur `app config lib`) |
| `ValidateExamAssignment` | aucune route, aucun appelant |
| `finish.turbo_stream.erb` | aucune action `finish` |
| `KnowledgeGap#reopen!`, `Exercise#estimated_duration` | aucun appelant |
| Alias racine `UseCases::{Detect,Resolve}KnowledgeGaps`, `UseCases::GenerateRemediationSession`, `Ports::ExamRepositoryPort`, `Ports::KnowledgeGapRepositoryPort` | appelés seulement par les tests ; `Repositories::KnowledgeGapRepository` (racine) appelé par `_exercise_card` et `teachers/classroom_exercises_controller.rb:46` |
| `app/views/classroom/teachers/classrooms/` (10 fichiers) | `controller_path` forcé (C-15) |
| `ExerciseSessionsController#result` : `@badges` | calculé (`exercise_sessions_controller.rb:96`), jamais lu par la vue |

---

## 6. Ce que je n'ai pas pu déterminer

1. **Le comportement réel de Turbo sur la réponse `204`** de l'assignation et du retrait (C-08) : le frame reste-t-il inchangé, ou Turbo signale-t-il une erreur ? Non exécuté.
2. **Si les `teachers.id` de production coïncident avec des `users.id`** : c'est ce qui décide entre `PG::ForeignKeyViolation` et une référence silencieusement fausse (C-09).
3. **Le format propre au « content engine »** : le service n'a jamais été versionné. Seuls les deux formats voisins de C-02 sont connus. Le mot « Content Engine » des documents `.Business/Lnclass-Launch/` désigne la capture d'insights marketing, pas un import.
4. **La cardinalité `ExamSubject ↔ Exercise`** : l'import suggère des exercices créés par sujet (`create_with_exercises`), les vues supposent `exercise.exam_subjects` (plusieurs sujets par exercice). Rien ne tranche.
5. **Si la fuite AS-39 s'est produite en production** : cela dépend du contenu de Solid Cache et de l'ordre des visites.
6. **Le type des clés de `group(:level).count`** dans `ExerciseBadgeQuery` : je suppose des libellés d'enum (`"silver"`), comme le fait Rails 8. Non exécuté. S'il s'agissait d'entiers, aucun compteur ne s'afficherait (AS-25).
7. **L'intention de `exercise_type` (`fixation` / `evaluation`)** : aucun comportement ne s'y rattache.
8. **Si `ImportCoursesJsonJob` tourne en production** (workers Solid Queue) : c'est le périmètre de la mission 5. AS-38 reste ⚠️ tant que ce n'est pas prouvé.
9. **`Student#unpaid?`** : non vérifié, la fiche du sujet n'est jamais atteinte (TR-19 la déclare 💀).
