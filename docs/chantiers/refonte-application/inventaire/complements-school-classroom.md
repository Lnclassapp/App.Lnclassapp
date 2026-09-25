# Compléments d'inventaire — contextes **school** et **classroom**

> Mission n°2 de [`prompt-exploration.md`](../prompt-exploration.md) (partie 3). Exploration en **lecture seule**, le 2026-09-22, branche `Teamprocess`, commit `684ae16`. `git diff --stat 2449373 HEAD -- app db config/routes.rb` est vide : le code est celui qu'a inventorié [`classroom-school.md`](classroom-school.md).
> Ce fichier **vérifie, complète et rend traçable** [`classroom-school.md`](classroom-school.md) et la section C de [`catalog.md`](catalog.md#c-organisation-scolaire-vit-dans-catalog-relève-dadr-0023) (DRENA, écoles), sans les recopier. Il **constate** ; il ne décide rien.
>
> Légende : ✅ marche · ⚠️ fragile · ❌ cassé (avec l'erreur) · 💀 jamais exécuté (avec la preuve). « Conditionnel » = l'erreur ne survient que dans l'état de données décrit.
> Références d'inventaire : `CS#A1` = [`classroom-school.md`](classroom-school.md) §A1 ; `CAT#C` = [`catalog.md`](catalog.md) §C ; `IC` = [`identity-communication.md`](identity-communication.md).

---

## 1. Catalogue des features avec identifiant

### 1.1 Contexte `school` — préfixe `SC`

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| SC-01 | Lister, consulter, créer, modifier et supprimer une DRENA | lecture : connecté · écriture : `team` | ⚠️ suppression ❌ dès qu'une école de la DRENA a un membre du personnel (voir §3, C-03) | `drenas`, `schools` | `GET /drenas`, `GET /drenas/:id`, `GET /drenas/new`, `POST /drenas`, `GET /drenas/:id/edit`, `PATCH /drenas/:id`, `DELETE /drenas/:id` | `CAT#C` « Gérer les DRENA » |
| SC-02 | Importer des DRENA depuis un JSON | `team` | ⚠️ aucun point d'entrée UI | `drenas` | `POST /drenas/import_json` | `CAT#C` « Importer des DRENA » |
| SC-03 | Créer un établissement dans une DRENA | de fait `team` (500 pour les autres, §3 C-01) | ⚠️ | `schools` | `GET /drenas/:drena_id/schools/new`, `POST /drenas/:drena_id/schools` | `CS#A1`, `CAT#C` |
| SC-04 | Parcourir la liste nationale des établissements | tout connecté | ⚠️ filtres factices, bouton « Nouvelle École » mort | `schools`, `drenas` | `GET /schools` | `CS#A2`, `CAT#C` |
| SC-05 | Consulter un établissement et filtrer ses classes | tout connecté | ✅ (non protégé) | `schools`, `classrooms` | `GET /schools/:id` | `CS#A2` |
| SC-06 | Modifier un établissement | **tout connecté** | ⚠️ | `schools` | `GET /schools/:id/edit`, `PATCH /schools/:id` | `CS#A2` |
| SC-07 | Supprimer un établissement | **tout connecté** | ❌ conditionnel : `ActiveRecord::RecordNotDestroyed` dès qu'un membre du personnel existe | `schools` + cascade | `DELETE /schools/:id` | `CS#A2` |
| SC-08 | Importer des établissements dans une DRENA depuis un JSON | **tout connecté** (pas de garde `team`) | ⚠️ aucun rapport | `schools`, `classrooms`, `users`, `students`, `classroom_students` | `POST /drenas/:drena_id/schools/import_json` | `CS#A3`, `CAT#C` |
| SC-09 | Générer les classes par défaut d'un nouvel établissement | système | ⚠️ collision de slug croissante avec le volume (§2 fiche SC-09) | `classrooms`, `levels`, `series`, `level_series` | — (déclenché par SC-03, SC-08) | `CS#A5`, `CAT#C` |
| SC-10 | S'inscrire comme administrateur d'établissement | anonyme | ⚠️ | `users`, `school_staffs`, `school_roles` | `GET /staff-signup`, `POST /staff-signup` | `CS#A4`, `IC` |
| SC-11 | Lister et créer les rôles internes d'un établissement | **tout connecté** | ⚠️ échec de création silencieux | `school_roles` | `GET /schools/:school_id/school_roles`, `GET …/school_roles/new`, `POST …/school_roles` | `CS#A6` |
| SC-12 | Supprimer un rôle interne | **tout connecté** | ⚠️ échec silencieux, non scopé à l'école | `school_roles` | `DELETE /schools/:school_id/school_roles/:id` | `CS#A6` |
| SC-13 | Rattacher un membre du personnel par son contact | **tout connecté** | ⚠️ doublon affiché comme succès, rôle d'une autre école accepté | `school_staffs` | `GET /schools/:school_id/school_staffs`, `GET …/new`, `POST …/school_staffs` | `CS#A7` |
| SC-14 | Retirer un membre du personnel | **tout connecté** | ⚠️ non scopé à l'école | `school_staffs` | `DELETE /schools/:school_id/school_staffs/:id` | `CS#A7` |
| SC-15 | Voir le tableau de bord de l'établissement (espace direction) | `school_admin` | ⚠️ flux vide codé en dur | `school_staffs`, `classrooms`, `classroom_students`, `students`, `teacher_schools`, `levels` | `GET /schoolstaff` | `CS#A8` |
| SC-16 | Voir la page « en attente d'affectation » | `school_admin` sans école | ✅ | `school_staffs` | `GET /schoolstaff` | `CS#A8` |
| SC-17 | Lister les classes de son établissement, filtrer par niveau | `school_admin` | ✅ | `classrooms`, `levels` | `GET /schoolstaff/classrooms` | `CS#A9` |
| SC-18 | Consulter le tableau de bord d'une classe (direction) | `school_admin` | ❌ conditionnel (`NoMethodError`) + fuite inter-établissements + statistiques vides | `classrooms`, `classroom_students`, `classroom_assignments` | `GET /schoolstaff/classrooms/:id` | `CS#A9` |
| SC-19 | Créer une classe (direction) | `school_admin` | ❌ `ActionView::MissingTemplate` (pas de vue `new`) ; POST forgé : `ActiveRecord::ValueTooLong` | `classrooms` | `GET /schoolstaff/classrooms/new`, `POST /schoolstaff/classrooms` | `CS#A10` |
| SC-20 | Lister les élèves de l'établissement | `school_admin` | ✅ (inclut les comptes démo) | `students`, `classroom_students`, `classrooms`, `users` | `GET /schoolstaff/students` | `CS#A11` |
| SC-21 | Ajouter un élève existant à une classe de l'établissement | `school_admin` | ❌ depuis l'UI : aucun lien, `MissingTemplate` sur `new` ; POST direct ✅ | `classroom_students` | `GET /schoolstaff/students/new`, `POST /schoolstaff/students` | `CS#A11`, `IC` « Rattachement d'un élève existant… » |
| SC-22 | Lister les enseignants de l'établissement | `school_admin` | ✅ | `teacher_schools`, `teachers`, `users` | `GET /schoolstaff/teachers` | `CS#A11` |
| SC-23 | Rattacher un enseignant existant à l'établissement | `school_admin` | ❌ `MissingTemplate` sur `new` (lien présent) ; POST direct ✅ | `teacher_schools` | `GET /schoolstaff/teachers/new`, `POST /schoolstaff/teachers` | `CS#A11`, `IC` « Rattachement d'un enseignant existant à un second établissement » |
| SC-24 | Consulter et modifier son profil (direction) | `school_admin` | ✅ | `users` | `GET /schoolstaff/profile`, `GET /schoolstaff/profile/edit`, `PATCH /schoolstaff/profile` | `CS#A12` |
| SC-25 | Changer son mot de passe (direction) | `school_admin` | ⚠️ sans mot de passe actuel ; `GET …/settings/edit` sans vue | `users` | `GET /schoolstaff/settings`, `GET /schoolstaff/settings/edit`, `PATCH /schoolstaff/settings` | `CS#A12` |
| SC-26 | Lister les établissements d'une DRENA (API) | anonyme | ✅ | `schools` | `GET /api/v1/schools` | `CS#A13` |
| SC-27 | Être rattaché à un établissement à son inscription d'enseignant | anonyme → `teacher` | ✅ (voir `IC`) | `teacher_schools` | `GET|POST /teacher-signup` | `IC` « Inscription d'un enseignant » |

### 1.2 Contexte `classroom` — préfixe `CL`

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| CL-01 | Créer une classe dans un établissement (équipe) | `team` | ❌ « École introuvable » (slug passé à `find_by_id`), puis `ValueTooLong` (code à 6 caractères) | `classrooms` | `GET /schools/:school_id/classrooms/new`, `POST /schools/:school_id/classrooms` | `CS#B1` |
| CL-02 | Modifier une classe | `team` | ❌ « Classe introuvable » (slug passé à `find_by_id`), échec muet | `classrooms` | `GET /classrooms/:id/edit`, `PATCH /classrooms/:id` | `CS#B2` |
| CL-03 | Supprimer une classe | `team` | ⚠️ suppression définitive | `classrooms` + cascade | `DELETE /classrooms/:id` | `CS#B2` |
| CL-04 | Générer le code d'adhésion et l'afficher | système, enseignant, direction, équipe, élève | ⚠️ minuscules sur 3 écrans | `classrooms` | — | `CS#B3` |
| CL-05 | Partager le lien de classe sur WhatsApp | enseignant | 💀 rendu commenté | `classrooms` | — | `CS#B3` |
| CL-06 | Rejoindre une classe par lien `/c/:code` en créant son compte | anonyme | ⚠️ | `users`, `students`, `classroom_students` | `GET /c/:unique_code`, `POST /c/:unique_code` | `CS#B4`, `IC` |
| CL-07 | S'inscrire comme élève avec un code ou la cascade école → niveau → classe | anonyme | ✅ | `users`, `students`, `classroom_students` | `GET|POST /student-signup` | `CS#B5`, `IC` |
| CL-08 | Vérifier un code de classe et lister les classes d'un niveau (API) | anonyme | ⚠️ énumérable | `classrooms`, `schools`, `levels`, `series` | `GET /api/v1/classrooms/lookup`, `GET /api/v1/classrooms` | `CS#B6` |
| CL-09 | Déclarer les classes que l'on enseigne | `teacher` | ⚠️ ordre alphabétique, remplacement toutes écoles confondues | `teacher_classrooms`, `teacher_schools`, `classrooms`, `levels` | `GET /teachers/classrooms`, `POST /teachers/classrooms` | `CS#B7` |
| CL-10 | Consulter la fiche d'une de ses classes | `teacher` | ❌ conditionnel : `PG::UndefinedTable` puis `NoMethodError exercise_id` dès qu'un exercice a été assigné | `classrooms`, `classroom_students`, `classroom_assignments` | `GET /teachers/classrooms/:id` | `CS#B8` |
| CL-11 | Consulter un cours dans une de ses classes | `teacher` | ❌ `NameError Repositories::ClassroomAssignmentRepository` dès que le cours a une fiche ; `NoMethodError essential_id` dès qu'une fiche est assignée | `classroom_assignments`, `courses`, `essentials` | `GET /teachers/classrooms/:id/courses/:course_id` | `CS#B8` |
| CL-12 | Consulter une fiche essentielle dans une de ses classes | `teacher` | ❌ `PG::UndefinedColumn exercise_id` dès que la fiche a un exercice | `classroom_assignments`, `essentials`, `exercises` | `GET /teachers/classrooms/:id/essentials/:essential_id` | `CS#B8` |
| CL-13 | Consulter la fiche d'un élève de sa classe | `teacher` | ❌ conditionnel (même préchargement que CL-10) | `classroom_students`, `exercise_sessions`, `exercise_badges`, `users` | `GET /teachers/classrooms/:classroom_id/students/:public_id` | `CS#B8` |
| CL-14 | Consulter le tableau de bord générique d'une classe | **tout connecté**, toute classe | ❌ conditionnel (`NoMethodError course` / `exercise`) ; 3 compteurs sur 4 vides | `classrooms`, `classroom_students`, `classroom_assignments` | `GET /classrooms/:id` | `CS#B9` |
| CL-15 | Parcourir la liste paginée des élèves d'une classe | **tout connecté** | ⚠️ ligne en cache jamais invalidée | `classroom_students`, `students`, `exercise_sessions`, `exercise_badges` | `GET /classrooms/:id/students` | `CS#B10` |
| CL-16 | Assigner / retirer un cours à une classe (chemin générique) | `teacher` | 💀 aucun lien dans les vues ; ❌ `ArgumentError` si appelé | `classroom_assignments` | `POST /classrooms/:classroom_id/courses`, `DELETE /classrooms/:classroom_id/courses/:course_id` | `CS#B11` |
| CL-17 | Assigner / retirer une fiche à une classe (chemin générique) | `teacher` | 💀 aucun lien ; ❌ `ArgumentError` si appelé | `classroom_assignments` | `POST /classrooms/:classroom_id/essentials`, `DELETE /classrooms/:classroom_id/essentials/:id` | `CS#B11` |
| CL-18 | Consulter un cours dans le contexte d'une classe (chemin générique) | tout connecté | ❌ `ActionView::MissingTemplate` (aucune vue `show`) | `classroom_assignments`, `courses` | `GET /classrooms/:classroom_id/courses/:course_id` | nouveau |
| CL-19 | Consulter une fiche dans le contexte d'une classe (chemin générique) | tout connecté | ❌ `PG::UndefinedColumn` ou `MissingTemplate` | `classroom_assignments`, `essentials` | `GET /classrooms/:classroom_id/essentials/:id` | nouveau |
| CL-20 | Assigner / retirer un exercice à une classe | `teacher` de la classe | ⚠️ réassigner après retrait → `ActiveRecord::RecordNotUnique` | `classroom_assignments` | `POST /classrooms/:classroom_id/exercises`, `DELETE /classrooms/:classroom_id/exercises/:id` | nouveau (recoupe `assessment.md`) |
| CL-21 | Assigner cours / fiches / sujets depuis l'espace enseignant | `teacher` | 💀 six use cases inexistants ; bouton inatteignable | `classroom_assignments` | `POST|DELETE /teachers/classroom_course_assignments`, `…_essential_assignments`, `…_exam_assignments` | `CS#B12` |
| CL-22 | Voir sa classe et ses cours (espace élève) | `student` | ⚠️ affiche aussi les cours retirés (archivés) | `classroom_students`, `classrooms`, `classroom_assignments`, `courses`, `essentials` | `GET /students/classroom` | `CS#B13` |
| CL-23 | Voir son fil d'accueil (élève) | `student` | ❌ (inchangé, voir `CS#B14`) | idem + `exercise_sessions`, `messages` | `GET /students` | `CS#B14` |
| CL-24 | Peupler les classes d'élèves de démonstration | système | ⚠️ | `users` (`is_demo`), `students`, `classroom_students` | — | `CS#B15` |
| CL-25 | Générer des élèves démo pour une classe (second générateur) | système | 💀 job jamais enqueué ; ❌ méthode de repository absente | `users`, `students` | — | `CS#B16` |
| CL-26 | Simuler l'activité des élèves démo | système | 💀 job jamais enqueué | `exercise_sessions`, `question_attempts` | — | `CS#B16` |
| CL-27 | Purger les élèves démo d'une classe ou d'une école | enseignant, équipe (prévu) | 💀 aucun appelant ; ❌ méthode de repository absente | `users`, `students`, `classroom_students` | — | `CS#B17` |
| CL-28 | Lister toutes les classes | **tout connecté** | ⚠️ liste nationale pour tout non-enseignant | `classrooms`, `schools`, `levels`, `series` | `GET /classrooms` | nouveau |

**Totaux** : 27 features `SC` + 28 features `CL` = **55**, dont **5 absentes des deux inventaires** (CL-18, CL-19, CL-20, CL-28, et SC-27 absente de `classroom-school.md` mais décrite dans `IC`) et **4 éclatements** de fiches existantes en features distinctes (SC-16, CL-05, CL-11/12/13, CL-16/17).

---

## 2. Features absentes de l'inventaire

### CL-18 — Consulter un cours dans le contexte d'une classe (chemin générique)

- **Acteur** : tout utilisateur connecté (`authenticate_user!` seul, `app/controllers/classroom/classroom_courses_controller.rb:12`).
- **Parcours** : `GET /classrooms/:classroom_id/courses/:course_id` charge la classe par slug sans vérifier d'appartenance (`:50`), le cours, l'assignation active et les fiches (`:15-19`), puis rend `show`.
- **Règles métier** : l'assignation affichée est la première **non archivée** (`classroom_assignments.active`, `:17`).
- **Données** : `classrooms`, `courses`, `essentials`, `classroom_assignments`.
- **État** : ❌ — `app/views/classroom/classroom_courses/` ne contient que `_classroom_button.html.erb` : aucune vue `show.html.erb` → `ActionView::MissingTemplate`. Aucune vue ne génère `classroom_classroom_course_path` ; seul `classroom_essentials_controller.rb:37,49` y redirige.
- **À refaire différemment** : ne pas exposer une route sans écran ; ne pas charger une classe sans contrôle d'appartenance.

### CL-19 — Consulter une fiche dans le contexte d'une classe (chemin générique)

- **Acteur** : tout utilisateur connecté (`classroom_essentials_controller.rb:12`).
- **Parcours** : `GET /classrooms/:classroom_id/essentials/:id` → fiche, cours, exercices publiés ou non, carte des exercices assignés (`:17-27`).
- **Règles métier** : aucune ; aucun scope par classe de l'enseignant.
- **Données** : `classrooms`, `essentials`, `exercises`, `classroom_assignments`.
- **État** : ❌ — `where(exercise_id: …)` sur `classroom_assignments` (`:24-26`) : la colonne n'existe pas (`db/schema.rb:64-75`) → `PG::UndefinedColumn` dès que la fiche a au moins un exercice ; sinon `MissingTemplate` (pas de `show.html.erb` dans `app/views/classroom/classroom_essentials/`).
- **À refaire différemment** : lire les assignations par `(resource_type, resource_id)`, jamais par une colonne fantôme.

### CL-20 — Assigner / retirer un exercice à une classe

- **Acteur** : enseignant **de la classe** — c'est le seul chemin d'assignation dont la policy est correctement construite (`app/controllers/assessment/classroom_exercises_controller.rb:62-66`).
- **Parcours** : depuis la carte d'exercice (`app/views/components/_exercise_card.html.erb:171,179`), rendue dans la section « exercices assignables » du tableau de bord générique (`app/views/classroom/classrooms/show.html.erb:204-213`) → `POST /classrooms/:classroom_id/exercises` → toast « Exercice assigné à la classe. » ou « Exercice déjà assigné. » ; retrait par `DELETE` → « Exercice retiré de la classe. ».
- **Règles métier** :
  - Exercices proposés : publiés, rattachés à une fiche assignée à la classe, pas encore assignés (`app/controllers/classroom/classrooms_controller.rb:61-66`).
  - Idempotent sur une assignation **active** (`app/domain/use_cases/assessment/create_classroom_exercise.rb:41-42`).
  - `assigned_by_id` reçoit l'id du **profil enseignant** (`:48`) — même défaut que `CS#E10`.
  - Le retrait archive (`status = "archived"`, `app/infrastructure/repositories/classroom/classroom_assignment_repository.rb:68`).
  - Refus → redirection racine « Accès non autorisé à cette classe. » (`:65`).
- **Données** : `classroom_assignments`.
- **État** : ⚠️ — l'assignation initiale et le retrait fonctionnent. **Réassigner un exercice retiré lève `ActiveRecord::RecordNotUnique`** : la recherche d'existant filtre `active` (`classroom_assignment_repository.rb:19`), ne trouve pas la ligne archivée, et `save` insère une nouvelle ligne (`:41`) contre l'index unique `(classroom_id, resource_type, resource_id)` (`db/schema.rb:72`). Effet de bord : dès qu'un exercice est assigné, CL-10, CL-13, CL-14 et SC-18 tombent (voir §3).
- **À refaire différemment** : l'archivage et la réactivation doivent porter sur la **même** ligne ; un seul chemin d'assignation pour tous les types.

### CL-28 — Lister toutes les classes

- **Acteur** : tout utilisateur connecté (`classrooms_controller.rb:18`).
- **Parcours** : `GET /classrooms` (aucun lien dans les vues ; seul repli de `_form.html.erb:3`) → page « Classrooms » (titre anglais en dur, `app/views/classroom/classrooms/index.html.erb:6-8`) listant des cartes de classe ; lien « Gérer les écoles » pour l'équipe.
- **Règles métier** (`classrooms_controller.rb:37-45`) : `?school_id=` → classes de cette école ; sinon enseignant → ses classes ; sinon (**élève, direction, équipe**) → **toutes les classes de la plateforme**, triées par date de création.
- **Données** : `classrooms`, `schools`, `levels`, `series`.
- **État** : ⚠️ — fonctionne, sans aucun contrôle de portée.
- **À refaire différemment** : aucune liste nationale de classes accessible hors équipe.

### SC-27 — Rattachement enseignant ↔ établissement à l'inscription

Décrite dans [`identity-communication.md`](identity-communication.md) (« Inscription d'un enseignant », `teacher_schools`). Citée ici parce que c'est, avec SC-23, **la seule écriture de `teacher_schools`** (`app/infrastructure/repositories/identity/teacher_repository.rb:28-31`) — donc la condition d'accès de CL-09 à CL-13. Pas de fiche dupliquée.

### Éclatements de fiches existantes (précisions sans nouvelle fiche)

- **SC-16** est le premier embranchement de `CS#A8` (`app/controllers/schoolstaff/feed_controller.rb:13-16`) ; il n'est atteignable que si la ligne `school_staffs` a été supprimée par SC-14, puisque SC-10 la crée toujours.
- **CL-05** : le partage WhatsApp décrit en `CS#B3` vit dans `app/views/teachers/feed/content/_examen_dashboard.html.erb:47-49`, dont le rendu est **commenté** (`app/views/teachers/feed/index.html.erb:11`). Le même bloc affiche « Partage de revenus — Tes Gains Prépa BAC … FCFA » (`_examen_dashboard.html.erb:35-43`) : trace d'un modèle économique (voir §6).
- **CL-11 / CL-12 / CL-13** : `CS#B8` groupait quatre écrans sous un seul état ; leurs pannes sont distinctes (§3).

---

## 3. Corrections de l'inventaire

### 3.1 Règles chiffrées vérifiées par sondage

| # | Règle de l'inventaire | Verdict | Preuve |
|---|---|---|---|
| 1 | Code d'adhésion : 3 lettres parmi 24 (sans `i`, `o`) + 2 chiffres parmi 8 (2–9), boucle anti-collision | ✅ | `app/infrastructure/orm/classroom.rb:54-62` |
| 2 | Barème des classes par défaut (public / privée, 2nd et 1ère par série, Tle C/D/A1/A2) | ✅ | `app/domain/use_cases/catalog/generate_default_classrooms.rb:14-33` |
| 3 | Démo : 40–45 élèves, 2 premières classes par niveau, `123456` en BCrypt coût 4, contact `<code><index 5 chiffres>` | ✅ | `app/infrastructure/repositories/classroom/classroom_repository.rb:130,176,179,186` |
| 4 | Démo : 22 prénoms masculins, 19 féminins, 24 patronymes | ✅ | `classroom_repository.rb:157-159` |
| 5 | Second générateur : 15 prénoms, 11 noms, `12345678`, préfixes `01/05/07` | ✅ | `app/domain/use_cases/classroom/generate_demo_students.rb:19-27,45,53` |
| 6 | Cache des rôles 12 h | ✅ la constante ; ❌ l'effet décrit (§3.2 SC-11) | `app/infrastructure/repositories/school_role_repository.rb:37` |
| 7 | `classrooms.name` limité à 15, `unique_code` à 5 | ✅ | `db/schema.rb:92,97` |
| 8 | `schooltype` « obligatoire en base » (`CS#A1`) | ❌ colonne nullable ; seule la validation ORM l'impose | `db/schema.rb:339` ; `app/infrastructure/orm/school.rb:37` |
| 9 | % actifs, moyenne tronquée, total des badges affichés sur la fiche classe (`CS#B9`) | ❌ jamais calculés à l'écran (§3.2 CL-14) | `app/infrastructure/queries/classroom_dashboard_query.rb:16-21` |
| 10 | Code « affiché en majuscules dans toute l'interface » (`CS#B3`) | ❌ | voir CL-04 ci-dessous |

### 3.2 Affirmations fausses ou incomplètes

**SC-03 / `CS#A1`, `CS#C` — « Tout utilisateur connecté peut créer une école ».** Incomplet. `create` appelle `current_team.id` (`app/controllers/catalog/schools_controller.rb:62`) ; `current_team` vaut `nil` hors rôle `team` (`app/controllers/concerns/current_user_concern.rb:47-49`) → `NoMethodError`, 500. La création est donc réservée à l'équipe **par plantage**. En revanche `edit`, `update`, `destroy` et `import_json` restent ouverts à tout connecté (`schools_controller.rb:13`, aucun autre garde ; `:99` utilise `current_team&.id`). Deux autres 500 : nom en double (`index_schools_on_name` unique, `db/schema.rb:344`, aucune validation d'unicité, `ActiveRecord::RecordNotUnique` non rattrapée par `app/infrastructure/repositories/catalog/school_repository.rb:47`) et nom de 151 à 200 caractères (entité 200, `app/domain/entities/school.rb:40` ; colonne 150, `db/schema.rb:335` → `ValueTooLong`).

**SC-08 / `CAT#C` — « Importer des écoles : acteur `team`, un seul fichier ».** `catalog.md` et `classroom-school.md` se contredisent. Code : **tout connecté** (même contrôleur, aucun `authenticate_team!`) ; le formulaire n'envoie qu'**un** fichier (`app/views/catalog/schools/_import_form.html.erb:12`, pas de `multiple`) mais le contrôleur en accepte plusieurs (`schools_controller.rb:83,89`). Le formulaire n'est affiché qu'à l'équipe (`app/views/catalog/drenas/show.html.erb:21`).

**SC-04 / `CS#A2` — « `/schools` : liste avec recherche plein texte ».** Faux côté écran. Le champ `search` et le sélecteur DRENA ne sont dans aucun formulaire (`app/views/catalog/schools/index.html.erb:20-41`, commentaire « Visuel uniquement pour le mockup ») ; le bouton « Nouvelle École » pointe sur `"#"` (`:12`). La recherche `ILIKE` n'est branchée que sur la page DRENA (`app/controllers/catalog/drenas_controller.rb:46-49`). Aucun état vide sur `/schools`.

**SC-07 / `CS#A2`, SC-01 / `CAT#C` — « La suppression détruit en cascade `school_roles`, `school_staffs` ».** Faux dès qu'un membre du personnel existe. `Orm::School` détruit `school_roles` (`app/infrastructure/orm/school.rb:30`) **avant** `school_staffs` (`:31`) ; un rôle porté est protégé par `restrict_with_error` (`app/infrastructure/orm/school_role.rb:18`) ; Rails appelle `destroy!` sur chaque enfant (`activerecord-8.1.3.1/lib/active_record/associations/has_many_association.rb:129`) → `ActiveRecord::RecordNotDestroyed`, non rattrapée (`school_repository.rb:55-58`). Comme chaque inscription de direction (SC-10) crée une ligne `school_staffs` avec le rôle « Direction », **tout établissement ayant un administrateur est indestructible**, et toute DRENA qui le contient aussi. Le contrôleur ignore de toute façon le résultat et affiche « École supprimée. » (`schools_controller.rb:133-137`).

**SC-09 / `CS#A5` — « insensible aux accents » et « unicité sans collision ».** Deux précisions. (1) Le test collège est `/coll[eè]ge/` sur `downcase` (`generate_default_classrooms.rb:45`) : « collége » (é) n'est pas reconnu. (2) Le contact des élèves démo est bien sans collision, mais leur **slug** ne l'est pas : `"#{fullname.parameterize}-#{SecureRandom.hex(2)}"` (`classroom_repository.rb:198`), soit 65 536 suffixes pour 984 noms complets possibles (22×24 + 19×24), contre l'index unique `index_users_on_slug` (`db/schema.rb:566`). Estimation (calcul, non exécuté) : un lycée crée jusqu'à 14 classes démo × ~42 ≈ 595 comptes ; avec N comptes démo déjà en base, l'espérance de collisions d'une nouvelle école vaut ≈ N × 9,2·10⁻⁶ — soit ~24 % d'échec vers 50 écoles, ~42 % vers 100. Une collision fait échouer `insert_all!` et annule toute la génération (`:161`) **après** que l'école a été enregistrée (`schools_controller.rb:62-68`) : 500 et école sans classes. Même risque, faible, pour `unique_code` : `generate_unique_code` ne vérifie que la base, pas le lot en cours (`classroom_repository.rb:138`). Le slug de classe utilise `school.name.parameterize` (`:127`), pas `school.slug` comme l'écrit l'ADR-0019 §2.4. L'insertion de masse contourne le `titleize` de `Sluggable`.

**SC-10 / `CS#A4`.** Correct. Précision : `Orm::User has_one :school_staff` (`app/infrastructure/orm/user.rb:51`) — un compte de direction n'a qu'**un** profil, donc un seul établissement, par construction de l'ORM et pas seulement par le `find_by` de `CS#A8`.

**SC-11 / `CS#A6` — cache de 12 h et création.** (1) Le cache `roles/school/<id>` n'est lu par **aucun** appelant : `find_all_by_school` n'est appelée nulle part hors de sa définition et du port (`grep` sur `app/`) ; les écrans lisent `@school.school_roles` directement (`app/controllers/catalog/school_roles_controller.rb:16`, `app/views/catalog/school_staffs/new.html.erb:18`). L'invisibilité de 12 h est donc théorique. (2) **La création échoue aussi en silence** : le DTO ne valide que la présence (`app/domain/dtos/school/create_role_dto.rb:20-21`), l'ORM limite à 100 caractères (`orm/school_role.rb:20`), le repository renvoie `nil` sur échec (`school_role_repository.rb:22-26`) et le contrôleur affiche quand même « Rôle créé avec succès. » (`school_roles_controller.rb:33-35`).

**SC-12 / `CS#A6` — suppression d'un rôle.** Complément : `DeleteRole.call(params[:id])` (`school_roles_controller.rb:44-46`) supprime **n'importe quel rôle de la plateforme** par son id, l'école de l'URL n'étant jamais comparée.

**SC-13 / `CS#A7` — « un utilisateur ne peut être staff qu'une fois par école ».** La validation existe (`orm/school_staff.rb:20`) mais son message n'est jamais montré : le repository renvoie `nil` (`school_staff_repository.rb:23-27`), aucune exception n'est levée, le contrôleur affiche « Membre du personnel ajouté avec succès. » (`school_staffs_controller.rb:41-44`). De plus : `school_role_id` vient du formulaire sans contrôle d'appartenance à l'école (`:34`) ; le contact est cherché **brut**, sans la normalisation de la connexion (`:24`, à comparer à `ContactConcern.normalize_for_lookup`) ; le libellé invite à saisir un e-mail (`new.html.erb:11-12`), ce que rien ne gère.

**SC-14 / `CS#A7` — retrait.** Même défaut que SC-12 : `DeleteStaff.call(params[:id])` sans filtre d'école (`school_staffs_controller.rb:53-56`).

**SC-18 / `CS#A9` — état ⚠️.** À requalifier ❌ conditionnel. La vue partagée par la direction appelle `@classroom_courses.map(&:course)` sur des `Orm::Course` (`app/views/schoolstaff/classrooms/show.html.erb:155`) et rend `_classroom_exercise` sur des `Orm::Exercise` (`:257`), qui appelle `classroom_exercise.exercise` (`app/views/classroom/classrooms/_classroom_exercise.html.erb:6`) : `NoMethodError` dès qu'un cours ou un exercice est assigné. Les compteurs % actifs, moyenne et badges sont vides (voir CL-14). Le code s'y affiche en minuscules (`:41,133`).

**SC-19 / `CS#A10` — cause de l'état ❌.** La cause atteinte en premier n'est pas le code à 6 caractères : **la vue `app/views/schoolstaff/classrooms/new.html.erb` n'existe pas** (le dossier ne contient que `index` et `show`) → `ActionView::MissingTemplate` sur le lien « Nouvelle classe » (`app/views/schoolstaff/classrooms/index.html.erb:13`) et sur tout échec de `create` (`schoolstaff/classrooms_controller.rb:52,68`). Le bug du code n'est atteint que par un POST forgé : `SecureRandom.alphanumeric(6)` (`app/domain/use_cases/classroom/create_classroom.rb:42`), conservé par `||=` (`orm/classroom.rb:50`), refusé par `varchar(5)` → `ActiveRecord::ValueTooLong`, non rattrapée (`classroom_repository.rb:67` ne rattrape que `RecordNotUnique` et `RecordInvalid`). Un nom de plus de 15 caractères produit la même erreur.

**SC-21, SC-23 / `CS#A11` — « Ajouter → saisie du contact ».** Ni `students/new.html.erb` ni `teachers/new.html.erb` n'existent dans `app/views/schoolstaff/` : `MissingTemplate`. La liste des élèves n'a même pas de lien d'ajout (`app/views/schoolstaff/students/index.html.erb:5-7`) ; celle des enseignants en a un (`teachers/index.html.erb:7`). Seuls des POST forgés aboutissent (`students_controller.rb:26-38`, `teachers_controller.rb:23-33`).

**SC-25 / `CS#A12`.** `resource :settings, only: [:show, :edit, :update]` (`config/routes.rb:177`) mais aucune vue `edit` : `GET /schoolstaff/settings/edit` → `MissingTemplate`. Le formulaire est sur `show` (`app/views/schoolstaff/settings/show.html.erb:20`).

**CL-01 / `CS#B1` — cause de l'état ❌ pour l'équipe.** Le formulaire poste sur `school_classrooms_path(@school.slug)` (`app/views/classroom/classrooms/_form.html.erb:3`) ; `create` cherche l'école par `find_by_id(params[:school_id])` (`classrooms_controller.rb:91`) et le use case aussi (`create_classroom.rb:32-33`) → « École introuvable ». L'erreur n'est pas ajoutée à la classe (`classrooms_controller.rb:117-119`) et `@school` vaut `nil` : le formulaire est ré-affiché **sans message**, pointé vers `classrooms_path` (route `POST` inexistante). Le bug du code à 6 caractères n'est même pas atteint. Le `titleize` annoncé existe bien (`app/models/concerns/sluggable.rb`, `normalize_name`).

**CL-02 / `CS#B2` — « Modifier une classe ».** Cassé, pas ⚠️. Le formulaire poste sur `classroom_path(@classroom.slug)` (`_form.html.erb:3`) ; `UpdateClassroom` ne cherche que par id (`app/domain/use_cases/classroom/update_classroom.rb:30`) → « Classe introuvable », et la branche d'échec n'ajoute pas l'erreur (`classrooms_controller.rb:151-155`) : ré-affichage muet. La suppression, elle, cherche par id puis slug (`:160`) et fonctionne. Complément : supprimer un **niveau** du catalogue détruit toutes les classes de ce niveau dans tout le pays, avec leurs adhésions et assignations (`app/infrastructure/orm/level.rb:25`, `dependent: :destroy`).

**CL-02 / `CS#B2` — « Les sessions d'exercices survivent, orphelines de classe ».** Formulation trompeuse : `exercise_sessions` n'a **ni `classroom_id` ni `teacher_id`** (`db/schema.rb:172-187`) ; une session n'a jamais été liée à une classe.

**CL-04 / `CS#B3` — « affiché en majuscules dans toute l'interface ».** Faux. En minuscules : tableau de bord générique (`app/views/classroom/classrooms/show.html.erb:41,133`), tableau de bord direction (`app/views/schoolstaff/classrooms/show.html.erb:41,133`), fiche école (`app/views/catalog/schools/show.html.erb:86`). En majuscules : espace enseignant, feed enseignant, espace élève (`teachers/classrooms/show.html.erb:23`, `teachers/feed/content/_classrooms.html.erb:62`, `students/classroom/show.html.erb:28`). Le même objet s'appelle « Code d'inscription » (`classroom/classrooms/show.html.erb:39`), « Code de classe » (`students/registrations/new.html.erb:79`) et « Code » ailleurs.

**CL-05 / `CS#B3` — « bouton de partage WhatsApp sur le feed enseignant ».** 💀 : partial jamais rendu (`app/views/teachers/feed/index.html.erb:11`, `<%#= render … %>`).

**CL-09 / `CS#B7` — règles de sélection.** Deux compléments. (1) Les niveaux sont triés **alphabétiquement** (`"levels.name ASC, classrooms.name ASC"`, `app/infrastructure/queries/teacher_classroom_query.rb:23`) : « 1ère » avant « 6ème », « Tle » en dernier, « 4ème 10 » avant « 4ème 2 ». (2) `current_teacher.classrooms = verified_classrooms` (`app/controllers/classroom/teachers/classrooms_controller.rb:82`) remplace **toutes** les classes de l'enseignant, y compris celles d'un autre établissement ; et `schools.first` est **sans ordre** (`app/infrastructure/orm/teacher.rb:35-41`) : dès que la direction d'un second établissement le rattache (SC-23), l'école affichée peut changer d'une requête à l'autre.

**CL-10, CL-13 / `CS#B8` — cause de l'état ❌.** Précision : l'erreur est **conditionnelle**. `set_classroom` précharge `classroom_exercises: { exercise: :essential }` (`classrooms_controller.rb:93-98` de l'espace enseignant) ; le `belongs_to :exercise` porte une condition sur la table `classroom_assignments` (`app/infrastructure/orm/classroom_assignment.rb:11`) que la requête de préchargement ne joint pas → `PG::UndefinedTable` **seulement si la classe a au moins une assignation d'exercice** (le préchargement n'émet aucune requête sans propriétaire). Puis `index_by(&:exercise_id)` (`:42`) lève `NoMethodError` : `ClassroomAssignment` n'a pas d'attribut `exercise_id`. Comme CL-20 est le seul chemin d'assignation qui fonctionne, **le premier exercice assigné casse la fiche de la classe et les fiches de ses élèves**.

**CL-11 / `CS#B8` — l'écran « cours » n'était pas signalé.** ❌ : `index_by(&:essential_id)` (`:52`) → `NoMethodError` dès qu'une fiche est assignée ; et la vue rend chaque fiche avec le bouton d'assignation (`app/views/teachers/classrooms/course.html.erb:52`), qui instancie `Repositories::ClassroomAssignmentRepository` (`app/views/classroom/classroom_essentials/_classroom_button.html.erb:8`) — classe inexistante (seule `Repositories::Classroom::ClassroomAssignmentRepository` existe, `app/infrastructure/repositories/classroom/classroom_assignment_repository.rb:15`) → `NameError` dès que le cours a une fiche.

**CL-12 / `CS#B8`.** `where(exercise_id: …)` (`:60-62`) → `PG::UndefinedColumn` dès que la fiche a un exercice.

**Vues de l'espace enseignant.** `Classroom::Teachers::ClassroomsController.controller_path` vaut `"teachers/classrooms"` (`:13-15`) : les vues rendues sont celles de `app/views/teachers/classrooms/`. Les dix fichiers de `app/views/classroom/teachers/classrooms/` en sont des **copies identiques jamais rendues** (vérifié par `cmp`).

**CL-14 / `CS#B9` — calculs de la fiche classe.** Faux. Les formules décrites (% actifs, moyenne tronquée, total des badges) vivent dans `ClassroomRepository#get_stats` (`classroom_repository.rb:86-96`), **qui n'est appelé nulle part**. La vue lit `@class_stats[:active_percentage]`, `[:average_score]`, `[:total_badges]` (`app/views/classroom/classrooms/show.html.erb:72,86,96`) dans un hash qui ne contient que `students_count`, `courses_count`, `essentials_count`, `exercises_count` (`classroom_dashboard_query.rb:16-21`) : trois compteurs affichent « % » vide. En outre ❌ conditionnel : `@classroom_courses.map(&:course)` sur des `Orm::Course` (`show.html.erb:155`) → `NoMethodError` dès qu'un cours est assigné ; `_classroom_exercise` (`:192`) → `NoMethodError` dès qu'un exercice est assigné (CL-20).

**CL-15 / `CS#B10`.** Complément : chaque ligne est mise en cache sur la clé de l'élève (`app/views/classroom/classrooms/_student.html.erb:5`) ; terminer une session ne modifie pas `students.updated_at` : **moyenne et badges affichés restent périmés**. Reste de la fiche vérifié (`:24-28` progression toujours 0, `:33` trois badges, `:41` lien `"#"`).

**CL-16, CL-17 / `CS#B11` — parcours.** Faux : la fiche de cours du catalogue et la carte de fiche n'appellent **pas** ces routes. Leurs boutons pointent vers l'espace enseignant 💀 (`app/views/classroom/classroom_courses/_classroom_button.html.erb:14,23` → `teachers_classroom_course_assignment(s)_path` ; idem pour les fiches). Aucune vue ne génère `classroom_classroom_courses_path` ni `classroom_classroom_essentials_path`. Les routes génériques sont donc **inatteignables** depuis l'interface (💀), et lèvent `ArgumentError` si on les appelle : `ManageClassroomAssignment` construit par défaut `Policies::ClassroomAccessPolicy.new` (`app/domain/use_cases/classroom/manage_classroom_assignment.rb:21`) alors que `classroom_repo:` est obligatoire (`app/domain/policies/classroom_access_policy.rb:27`). Aucune vue `create.turbo_stream.erb` / `destroy.turbo_stream.erb` n'existe pour ces contrôleurs. Le toast est émis quel que soit le résultat (`classroom_courses_controller.rb:28,41`).

**CL-16, CL-17, CL-20 / `CS#B11` — « Réassigner une ressource archivée la réactive au statut `added` (ADR-0016) ».** Faux. La réactivation (`classroom_assignment_repository.rb:46`) n'est atteinte que si l'entité porte l'id d'une ligne archivée ; or tous les use cases cherchent l'existant parmi les lignes **actives** (`:19`), ne trouvent rien, et créent une nouvelle ligne → `ActiveRecord::RecordNotUnique` sur l'index unique (`db/schema.rb:72`). **Une ressource retirée ne peut plus jamais être réassignée à la même classe.** L'entité ignore d'ailleurs `archived` dans ses statuts (`app/domain/entities/classroom_assignment.rb:33-37`).

**CL-16, CL-17 / `CS#B11` — « Toutes les lectures filtrent sur non archivé ».** Faux. `Orm::Classroom has_many :courses/:essentials/:exercises, through: :classroom_assignments` sans condition de statut (`app/infrastructure/orm/classroom.rb:32-34`), de même que `classroom_courses/essentials/exercises` (`:36-38`). Voir CL-22.

**CL-22 / `CS#B13` — « liste des cours assignés à la classe ».** Incomplet : `classroom.courses` (`app/infrastructure/queries/student_classroom_query.rb:21`) inclut les assignations **archivées** — l'élève voit encore les cours que l'enseignant a retirés.

**CL-24 / `CS#B15`, `CS#E9` — « comptes réels et connectables ; quiconque connaît un code de classe peut se connecter en élève démo ».** **Faux.** La connexion normalise le contact en **ne gardant que les chiffres** (`app/models/concerns/contact_concern.rb:18-27`, appelé par `app/controllers/identity/sessions_controller.rb:28-29`, seul chemin d'authentification — `user.authenticate` n'apparaît qu'ici et dans `user_repository.rb:50`). Le contact démo `kaz4700001` devient `4700001`, qui ne correspond à aucun compte. **Les comptes démo ne sont pas connectables par le formulaire.** Ils restent des lignes `users` réelles avec un mot de passe trivial, et d'autres défauts : leur contact viole la validation de format du modèle (`contact_concern.rb:31-34`), donc tout `save` ultérieur d'un compte démo échoue ; leur genre vaut `"M"`/`"F"` (`classroom_repository.rb:182`) alors que l'entité n'accepte que `male`/`female` (`app/domain/entities/user.rb:37`) ; et `is_demo` n'est filtré **nulle part** hors du job de simulation 💀 (`app/jobs/simulate_classroom_exercise_job.rb:21`) — les comptes démo gonflent les effectifs de la direction (`schoolstaff/feed_controller.rb:20`), des DRENA et des classes. Cette correction touche aussi [`securite.md`](../securite.md) et la ligne F-20 / C-09 de [`feuille-de-route.md`](../feuille-de-route.md), qui reprennent « connectables ».

**`CS#C` — synthèse des permissions.** Trois lignes à corriger : `/schools` création → de fait `team` ; `/classrooms/:id/courses/:id` → inatteignable (💀), et `ArgumentError` avant tout contrôle, pas « 500 si non-enseignant » seulement ; ajouter `GET /classrooms` (tout connecté, liste nationale) et `DELETE …/school_roles/:id`, `DELETE …/school_staffs/:id` (tout connecté, **toute école**).

---

## 4. Écarts avec les décisions

> Les écarts déjà au registre de [`feuille-de-route.md` §4](../feuille-de-route.md#4-registre-des-contradictions-entre-sources) sont cités par leur ID sans être redécrits. **Aucun n'est tranché ici.**

| Sujet | Source A dit | Source B dit | Qui devrait trancher |
|---|---|---|---|
| Contexte borné de DRENA, école, classe | ADR-0023 §2 : contexte `Identity` | conventions §2 et architecture §5 : `school` et `classroom` ; architecture §5 : DRENA dans `catalog` ; glossaire §2 : noms racine `Entities::Drena`, `Entities::School` (legacy selon conventions) | **déjà C-03** → F-02 (ADR-0027) ; ajouter le glossaire à la ligne |
| Types assignables | ADR-0007 §3 et §5 : `Course`, `Essential`, `ExamSubject` | glossaire §5 et code (`entities/classroom_assignment.rb:30`) : + `Exercise` | **déjà C-04** |
| Statuts d'assignation | ADR-0007 §5 : `added`, `active`, `validated` (sans `archived`) | ADR-0016 §2 : `archived` + réactivation ; colonne : défaut `active` ; glossaire : 4 statuts | **déjà C-10** → F-26 ; préciser que l'ADR-0016 **étend** l'ADR-0007 sans le déclarer |
| Réactivation d'une assignation retirée | ADR-0016 §2 : réassigner réactive la ligne archivée | code : `RecordNotUnique`, jamais réactivée (§3 CL-16) | constat pour F-26 (ADR-0048) — aucun écart de décision, un bug |
| `assigned_by_id` | ADR-0007 §3 : « ID de l'enseignant ou de l'administrateur » | schéma : clé étrangère vers `users` (`db/schema.rb:573`) ; `Orm::Teacher` la lit par `user_id` (`orm/teacher.rb:30`) ; use cases : id du profil `teachers` | F-26 tranche déjà « référence un utilisateur » ; l'ADR-0007 §3 est à marquer remplacé |
| Traçabilité enseignant de l'activité | ADR-0016 §2 : `ExerciseSession` trace le `teacher_id` | schéma : aucune colonne `teacher_id` ni `classroom_id` sur `exercise_sessions` (`db/schema.rb:172-187`) | ADR à écrire (F-14 ou F-26) : garder ou abandonner cette promesse |
| Suppression d'une classe | ADR-0016 : l'historique d'assignation ne se détruit pas | code : `dependent: :destroy` sur `classroom_assignments` (`orm/classroom.rb:31`) ; suppression d'un niveau détruit les classes (`orm/level.rb:25`) | F-14 (ADR-0036) et F-19 (ADR-0041) |
| Enseignant multi-établissements | ADR-0004 §3–4 : établissements illimités, « tableau de bord unique » | interface : `schools.first` sans ordre ; plan : une école en V1 | **déjà C-01** → F-06 |
| Création de classe par l'enseignant | ADR-0004 §2 : un enseignant est « autorisé à l'accès et la création de classes » dans ses établissements | code : aucune route de création pour `teacher` ; seuls `team` (CL-01) et `school_admin` (SC-19) | ADR à écrire avec F-06 : qui crée une classe |
| Élève qui rejoint une classe supplémentaire | ADR-0003 §4 : « un élève peut rejoindre n'importe quel cours du soir avec un simple code de classe » | code : `/c/:code` et `/student-signup` **créent un compte** ; aucun chemin pour un élève connecté ; seule la direction ajoute un élève existant (SC-21, sans vue) | **à joindre à C-12** → F-18 (ADR-0040) |
| Unicité de l'adhésion principale | ADR-0003 §3 : une inscription `primary: true` = la classe officielle | schéma : aucune contrainte (`db/schema.rb:77-87`) ; SC-21 crée `primary: false` | F-18 (index partiel recommandé) |
| Élèves démo : déclencheur | ADR-0019 §2.2 : « à la création d'une classe » | ADR-0019 §2.4 et code : à la création d'un **établissement**, 2 classes par niveau ; aucune génération à la création d'une classe seule | **joindre à C-09** → F-20 (ADR-0042) |
| Élèves démo : filtrage | ADR-0019 §2.1 : `is_demo` « simplifie le filtrage dans l'analytique » | code : jamais filtré (§3 CL-24) | F-20 |
| Élèves démo : connectables | [`securite.md`](../securite.md), `CS#E9`, F-20 : comptes connectables | code : non connectables par `/login` (§3 CL-24) | correction d'inventaire, pas une décision ; F-20 à reformuler |
| Unicité sans collision | ADR-0020 §2.3 : « 0 % de probabilité de conflit » | code : contact sans collision, **slug** utilisateur aléatoire sur 2 octets (§3 SC-09) | F-20 / ADR-0042 |
| Slug des classes de masse | ADR-0019 §2.4 et ADR-0020 §2.2 : `[ecole-slug]-[classe]-[code]` | code : `school.name.parameterize` (`classroom_repository.rb:127`) | F-05 (ADR-0029) : les URL de classe passent au `public_id` |
| Rôle de la direction : une ou plusieurs écoles | glossaire §1 : unicité « par école » (laisse entendre plusieurs) | ORM : `has_one :school_staff` (`orm/user.rb:51`) — une seule | F-22 (ADR-0044) |
| Vocabulaire absent du glossaire | glossaire, règle 3 : « un terme absent ne s'invente pas » | code et UI : `unique_code` / « code d'inscription » / « code de classe » ; « élève de démonstration » / `is_demo` ; « prépa », « classe de révision » (`prepa_registrations_controller.rb:62`) | glossaire à compléter par le chantier qui tranche F-02 |
| Recherche et filtre des établissements | UDR-0002 §3 : barre de recherche + sélecteur DRENA, état vide « Aucune école trouvée » | `/schools` : maquette non branchée, aucun état vide ; bouton « Nouvelle École » → `"#"` | UDR à remplacer (F-09 / UDR-0005 ou UDR dédiée à la V2) |
| Composant de référence | UDR-0002 §4 : `_school_card.html.erb` unique | deux cartes : `app/views/components/schools/_school_card.html.erb` (`/schools`) et `app/views/catalog/schools/_school_card.html.erb` (DRENA) | même UDR |
| Badges de statut et de type | UDR-0002 §2–3 : `bg-green-100 text-green-800`, libellés « Actif », « En attente », « Public », « Privé » | code : `bg-green-50 text-green-700` ; libellés `titleize` des valeurs brutes (« Draft », « Privée ») | **déjà C-05** pour les tokens ; libellés → i18n (conventions, règle d'or 3) |
| Navigation école → classes | UDR-0002 §3 : onglets sous le nom de l'école | fiche école : aucun onglet | UDR de la V2 |
| Protection de la fiche classe | ADR-0004 §2 : aucun accès hors des classes où l'enseignant intervient | `GET /classrooms/:id`, `/classrooms/:id/students`, `GET /classrooms` : tout connecté ; `/schoolstaff/classrooms/:id` : toute école | F-04 (ADR-0028) |

---

## 5. Couverture

### 5.1 Tables

| Table | IDs | Remarque |
|---|---|---|
| `drenas` | SC-01, SC-02, SC-26 | — |
| `schools` | SC-03 à SC-09, SC-26 | — |
| `school_roles` | SC-10, SC-11, SC-12 | — |
| `school_staffs` | SC-10, SC-13, SC-14, SC-15, SC-16 | — |
| `teacher_schools` | SC-22, SC-23, SC-27, CL-09 | — |
| `classrooms` | SC-09, SC-17, SC-19, CL-01 à CL-04, CL-08, CL-28 | colonne `public_id` jamais lue (`CS#F2`) |
| `classroom_students` | SC-20, SC-21, CL-06, CL-07, CL-15, CL-22, CL-24 | — |
| `teacher_classrooms` | CL-09 à CL-13, policy de CL-20 | — |
| `classroom_assignments` | CL-10 à CL-12, CL-14, CL-16 à CL-22 | statut `validated` jamais écrit (`CS#F3`) |
| `users.is_demo` | CL-24 à CL-27 | — |
| `students.matricule` | CL-24 | seul écrivain : génération démo (`classroom_repository.rb:214`) |
| `level_series` (lecture) | SC-09 | table du catalogue |

### 5.2 Routes

Toutes les routes de `config/routes.rb` du périmètre sont rattachées en §1, **sauf** :

| Route | Rattachement |
|---|---|
| `GET /teachers/classroom_exercises/:slug`, `…/report`, `…/remediation` (`config/routes.rb:141-143`) | hors périmètre → mission 4 (`AS`) |
| `GET /teachers`, `/teachers/dashboard`, `/teachers/setup`, `/teams*`, `/schoolstaff` en tant que feed | mission 5 (`TR`) ; `/schoolstaff` est aussi SC-15/16 |
| `GET|POST /teachers/prepa_acquisitions*` | mission 5 (`TR`) |

### 5.3 Code mort de ce périmètre (preuves)

| Élément | Preuve |
|---|---|
| `app/views/classroom/teachers/classrooms/*` (10 fichiers) | `controller_path` = `"teachers/classrooms"` (`classroom/teachers/classrooms_controller.rb:13-15`) ; fichiers identiques à `app/views/teachers/classrooms/*` |
| `ClassroomRepository#get_stats` | aucun appelant (`grep get_stats app` → définition seule) |
| `SchoolRoleRepository#find_all_by_school` (et son cache) | aucun appelant |
| `teachers/feed/content/_examen_dashboard.html.erb` (WhatsApp, gains prépa) | rendu commenté, `teachers/feed/index.html.erb:11` |
| `Catalog::GenerateSchoolDemoDataJob`, `SimulateClassroomExerciseJob`, `PurgeDemoStudents` | aucun `perform_later` ni appelant (`grep` sur `app lib config db`) ; `config/recurring.yml` ne les cite pas |
| `Classroom::ClassroomCoursesController`, `ClassroomEssentialsController` (actions `create`/`destroy`) | aucune vue ne génère leurs routes (§3 CL-16) |
| Contrôleurs `Teachers::Classroom{Course,Essential,Exam}AssignmentsController` | use cases inexistants (`grep "class AssignCourseToClassroom"` etc. : aucun résultat) |

---

## 6. Ce que je n'ai pas pu déterminer

1. **Le modèle économique « Prépa BAC ».** Outre `prepa_status` / `prepa_joined_at` (`CS#F1`), le partial mort `_examen_dashboard.html.erb:35-43` affiche « Partage de revenus », « Tes Gains Prépa BAC … FCFA » répartis entre les enseignants de la classe (`@prepa_gains`). Qui paie, combien, et comment le revenu se partage : aucune table ne le dit. Relève de F-24.
2. **Le comportement exact de l'interface en cas d'échec d'un `insert_all!` démo** n'a pas été exécuté : l'estimation du §3 SC-09 est un calcul, pas une mesure. Le seuil réel dépend de la distribution des prénoms et des slugs des comptes réels.
3. **Si des assignations de cours ou de fiches existent en base.** Aucun chemin applicatif ne les crée (CL-16, CL-17, CL-21 morts ou cassés) ; seule une reprise de données ou une console a pu en produire. Les pannes conditionnelles de CL-14 et SC-18 sur les cours en dépendent.
4. **Si le préchargement de CL-10 lève `PG::UndefinedTable` ou une autre erreur SQL** : déduit de la lecture de `classroom_assignment.rb:11` et du mécanisme de preload, non exécuté.
5. **Pourquoi deux cartes d'établissement coexistent** (`components/schools/` et `catalog/schools/`) : migration UDR-0002 interrompue ou doublon involontaire.
6. **Le rôle attendu de `school_roles` au-delà de « Direction »** : aucun écran ne lit le rôle d'un membre pour lui donner des droits ; les rôles sont purement descriptifs.
7. **Ce que devait afficher la colonne « Progression »** de la liste d'élèves (`_student.html.erb:24`) : aucun modèle ne l'expose (`CS#E14`).
