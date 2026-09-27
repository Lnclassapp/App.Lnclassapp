# Inventaire — Aspects transverses

> Carte du squelette de l'application actuelle : tout ce qui n'appartient à aucun
> contexte métier en particulier et que le nouveau projet Rails devra reconstruire.
>
> | | |
> |---|---|
> | **Chantier** | `refonte-application` |
> | **Établi le** | 2026-09-18 |
> | **Source** | dépôt `Lnclassapp`, branche `docs/process-v2`, commit `2449373` |
> | **Nature** | état des lieux factuel — aucune recommandation |

**Volumétrie de référence**

| Mesure | Valeur |
|---|---|
| Fichiers `.rb` sous `app/` + `lib/` | 275 |
| Fichiers `.rb` qu'aucun test ne charge | 114 |
| Vues `.erb` | 315 |
| Use cases | 47 |
| Contrôleurs | 52 (+ 1 concern partagé) |
| Contrôleurs Stimulus | 31 |
| Fichiers de test | 69 |
| Entrées de routes applicatives | 197 |
| Entrées de routes internes Rails | 26 |
| Migrations | 19 |
| Tables (métier + infra) | 46 |
| Fichiers de locales | 3 |

---

# 1. La carte complète des routes

Source unique : `config/routes.rb` (7,7 Ko). Tout est déclaré à plat dans un seul
fichier, sans `constraints`, sans `defaults`, sans contrainte de format.
197 entrées applicatives générées par `bin/rails routes`.

## 1.1 Espace public / non authentifié

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/` | `homepage#index` | `root` |
| GET | `/login` | `identity/sessions#new` | `new_session` |
| POST | `/login` | `identity/sessions#create` | `session` |
| DELETE | `/logout` | `identity/sessions#destroy` | `destroy_session` |
| GET | `/student-signup` | `identity/students/registrations#new` | `new_student_registration` |
| POST | `/student-signup` | `identity/students/registrations#create` | `student_registration` |
| GET | `/teacher-signup` | `teachers/registrations#new` | `new_teacher_registration` |
| POST | `/teacher-signup` | `teachers/registrations#create` | `teacher_registration` |
| GET | `/staff-signup` | `school_admins/registrations#new` | `new_staff_registration` |
| POST | `/staff-signup` | `school_admins/registrations#create` | `staff_registration` |
| GET | `/team-signup` | `teams/registrations#new` | `new_team_registration` |
| POST | `/team-signup` | `teams/registrations#create` | `team_registration` |
| GET | `/c/:unique_code` | `students/prepa_registrations#new` | `prepa_class` |
| POST | `/c/:unique_code` | `students/prepa_registrations#create` | — |
| GET | `/manifest` | `rails/pwa#manifest` | `pwa_manifest` |
| GET | `/service-worker` | `rails/pwa#service_worker` | `pwa_service_worker` |

Le namespace d'inscription est incohérent : l'élève passe par
`identity/students/registrations`, les trois autres rôles par `teachers/`,
`school_admins/`, `teams/` — hors du contexte borné `identity`.

## 1.2 Identité (`scope module: "identity"`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/users` | `identity/users#index` | `users` |
| GET | `/users/:public_id` | `identity/users#show` | `user` |
| GET | `/users/:public_id/edit` | `identity/users#edit` | `edit_user` |
| PATCH | `/users/:public_id` | `identity/users#update` | — |
| PUT | `/users/:public_id` | `identity/users#update` | — |
| DELETE | `/users/:public_id` | `identity/users#destroy` | — |

`param: :public_id` — seule ressource du projet à ne pas router sur `:id` ou `:slug`.

## 1.3 Catalogue (`scope module: "catalog"`) — sans préfixe d'espace

### Cours

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/courses` | `catalog/courses#index` | `courses` |
| POST | `/courses` | `catalog/courses#create` | — |
| GET | `/courses/new` | `catalog/courses#new` | `new_course` |
| GET | `/courses/:id` | `catalog/courses#show` | `course` |
| GET | `/courses/:id/edit` | `catalog/courses#edit` | `edit_course` |
| PATCH | `/courses/:id` | `catalog/courses#update` | — |
| PUT | `/courses/:id` | `catalog/courses#update` | — |
| DELETE | `/courses/:id` | `catalog/courses#destroy` | — |
| POST | `/courses/import_json` | `catalog/courses#import_json` | `import_json_courses` |

### Essentiels

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/courses/:course_id/essentials` | `catalog/essentials#index` | `course_essentials` |
| POST | `/courses/:course_id/essentials` | `catalog/essentials#create` | — |
| GET | `/courses/:course_id/essentials/new` | `catalog/essentials#new` | `new_course_essential` |
| POST | `/courses/:course_id/essentials/import_json` | `catalog/essentials#import_json` | `import_json_course_essentials` |
| GET | `/essentials/:id` | `catalog/essentials#show` | `essential` |
| GET | `/essentials/:id/edit` | `catalog/essentials#edit` | `edit_essential` |
| PATCH | `/essentials/:id` | `catalog/essentials#update` | — |
| PUT | `/essentials/:id` | `catalog/essentials#update` | — |
| DELETE | `/essentials/:id` | `catalog/essentials#destroy` | — |

### DRENA

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/drenas` | `catalog/drenas#index` | `drenas` |
| POST | `/drenas` | `catalog/drenas#create` | — |
| GET | `/drenas/new` | `catalog/drenas#new` | `new_drena` |
| GET | `/drenas/:id` | `catalog/drenas#show` | `drena` |
| GET | `/drenas/:id/edit` | `catalog/drenas#edit` | `edit_drena` |
| PATCH | `/drenas/:id` | `catalog/drenas#update` | — |
| PUT | `/drenas/:id` | `catalog/drenas#update` | — |
| DELETE | `/drenas/:id` | `catalog/drenas#destroy` | — |

### Établissements

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/schools` | `catalog/schools#index` | `schools` |
| GET | `/schools/:id` | `catalog/schools#show` | `school` |
| GET | `/schools/:id/edit` | `catalog/schools#edit` | `edit_school` |
| PATCH | `/schools/:id` | `catalog/schools#update` | — |
| PUT | `/schools/:id` | `catalog/schools#update` | — |
| DELETE | `/schools/:id` | `catalog/schools#destroy` | — |
| POST | `/drenas/:drena_id/schools` | `catalog/schools#create` | `drena_schools` |
| GET | `/drenas/:drena_id/schools/new` | `catalog/schools#new` | `new_drena_school` |
| POST | `/drenas/:drena_id/schools/import_json` | `catalog/schools#import_json` | `import_json_drena_schools` |

La création d'un établissement n'est possible que sous une DRENA ; la lecture et
la suppression sont à plat. Deux préfixes pour une seule ressource.

### Rôles et personnels d'établissement

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/schools/:school_id/school_roles` | `catalog/school_roles#index` | `school_school_roles` |
| POST | `/schools/:school_id/school_roles` | `catalog/school_roles#create` | — |
| GET | `/schools/:school_id/school_roles/new` | `catalog/school_roles#new` | `new_school_school_role` |
| DELETE | `/schools/:school_id/school_roles/:id` | `catalog/school_roles#destroy` | `school_school_role` |
| GET | `/schools/:school_id/school_staffs` | `catalog/school_staffs#index` | `school_school_staffs` |
| POST | `/schools/:school_id/school_staffs` | `catalog/school_staffs#create` | — |
| GET | `/schools/:school_id/school_staffs/new` | `catalog/school_staffs#new` | `new_school_school_staff` |
| DELETE | `/schools/:school_id/school_staffs/:id` | `catalog/school_staffs#destroy` | `school_school_staff` |

Ni `school_roles` ni `school_staffs` n'ont d'action `show`, `edit` ou `update`.

### Taxonomie — matières, niveaux, séries

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/new-material` | `catalog/materials#new` | `new_material` |
| GET | `/materials` | `catalog/materials#index` | `materials` |
| POST | `/materials` | `catalog/materials#create` | — |
| GET | `/materials/:id` | `catalog/materials#show` | `material` |
| GET | `/materials/:id/edit` | `catalog/materials#edit` | `edit_material` |
| PATCH | `/materials/:id` | `catalog/materials#update` | — |
| PUT | `/materials/:id` | `catalog/materials#update` | — |
| DELETE | `/materials/:id` | `catalog/materials#destroy` | — |
| GET | `/new-level` | `catalog/levels#new` | `new_level` |
| GET | `/levels` | `catalog/levels#index` | `levels` |
| POST | `/levels` | `catalog/levels#create` | — |
| GET | `/levels/:id` | `catalog/levels#show` | `level` |
| GET | `/levels/:id/edit` | `catalog/levels#edit` | `edit_level` |
| PATCH | `/levels/:id` | `catalog/levels#update` | — |
| PUT | `/levels/:id` | `catalog/levels#update` | — |
| DELETE | `/levels/:id` | `catalog/levels#destroy` | — |
| GET | `/new-series` | `catalog/series#new` | `new_series` |
| GET | `/series` | `catalog/series#index` | `series_index` |
| POST | `/series` | `catalog/series#create` | — |
| GET | `/series/:id` | `catalog/series#show` | `series` |
| GET | `/series/:id/edit` | `catalog/series#edit` | `edit_series` |
| PATCH | `/series/:id` | `catalog/series#update` | — |
| PUT | `/series/:id` | `catalog/series#update` | — |
| DELETE | `/series/:id` | `catalog/series#destroy` | — |

Les trois routes `GET /new-material`, `/new-level`, `/new-series` sont hors REST :
le `new` a été sorti de `resources` pour obtenir une URL courte.

## 1.4 Évaluation (`scope module: "assessment"`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/essentials/:essential_id/exercises` | `assessment/exercises#index` | `essential_exercises` |
| POST | `/essentials/:essential_id/exercises` | `assessment/exercises#create` | — |
| GET | `/essentials/:essential_id/exercises/new` | `assessment/exercises#new` | `new_essential_exercise` |
| POST | `/essentials/:essential_id/exercises/import_content_engine` | `assessment/exercises#import_content_engine` | `import_content_engine_essential_exercises` |
| GET | `/exercises/:id` | `assessment/exercises#show` | `exercise` |
| GET | `/exercises/:id/edit` | `assessment/exercises#edit` | `edit_exercise` |
| PATCH | `/exercises/:id` | `assessment/exercises#update` | — |
| PUT | `/exercises/:id` | `assessment/exercises#update` | — |
| DELETE | `/exercises/:id` | `assessment/exercises#destroy` | — |
| POST | `/exercises/:exercise_id/exercise_sessions` | `assessment/exercise_sessions#create` | `exercise_exercise_sessions` |
| GET | `/exercise_sessions/:id` | `assessment/exercise_sessions#show` | `exercise_session` |
| PATCH | `/exercise_sessions/:id` | `assessment/exercise_sessions#update` | — |
| PUT | `/exercise_sessions/:id` | `assessment/exercise_sessions#update` | — |
| GET | `/exercise_sessions/:id/result` | `assessment/exercise_sessions#result` | `result_exercise_session` |
| POST | `/remediation_sessions` | `assessment/remediation_sessions#create` | `remediation_sessions` |
| POST | `/classrooms/:classroom_id/exercises` | `assessment/classroom_exercises#create` | `classroom_classroom_exercises` |
| DELETE | `/classrooms/:classroom_id/exercises/:id` | `assessment/classroom_exercises#destroy` | `classroom_classroom_exercise` |

Les exercices sont déclarés dans le `scope module: "catalog"` mais redirigés vers
`controller: "/assessment/exercises"` par un chemin absolu. Même mécanisme pour
`classroom_exercises`, déclaré sous `scope module: "classroom"`.

## 1.5 Classes (`scope module: "classroom"`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/classrooms` | `classroom/classrooms#index` | `classrooms` |
| GET | `/classrooms/:id` | `classroom/classrooms#show` | `classroom` |
| GET | `/classrooms/:id/edit` | `classroom/classrooms#edit` | `edit_classroom` |
| PATCH | `/classrooms/:id` | `classroom/classrooms#update` | — |
| PUT | `/classrooms/:id` | `classroom/classrooms#update` | — |
| DELETE | `/classrooms/:id` | `classroom/classrooms#destroy` | — |
| GET | `/classrooms/:id/students` | `classroom/classrooms#students` | `students_classroom` |
| POST | `/schools/:school_id/classrooms` | `classroom/classrooms#create` | `school_classrooms` |
| GET | `/schools/:school_id/classrooms/new` | `classroom/classrooms#new` | `new_school_classroom` |
| POST | `/classrooms/:classroom_id/courses` | `classroom/classroom_courses#create` | `classroom_classroom_courses` |
| GET | `/classrooms/:classroom_id/courses/:course_id` | `classroom/classroom_courses#show` | `classroom_classroom_course` |
| DELETE | `/classrooms/:classroom_id/courses/:course_id` | `classroom/classroom_courses#destroy` | — |
| POST | `/classrooms/:classroom_id/essentials` | `classroom/classroom_essentials#create` | `classroom_classroom_essentials` |
| GET | `/classrooms/:classroom_id/essentials/:id` | `classroom/classroom_essentials#show` | `classroom_classroom_essential` |
| DELETE | `/classrooms/:classroom_id/essentials/:id` | `classroom/classroom_essentials#destroy` | — |

`classroom_courses` utilise `param: :course_id` ; `classroom_essentials` reste sur
`:id`. Deux conventions pour deux ressources jumelles.

## 1.6 API (`namespace :api / :v1`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/api/v1/schools` | `api/v1/schools#index` | `api_v1_schools` |
| GET | `/api/v1/classrooms` | `api/v1/classrooms#index` | `api_v1_classrooms` |
| GET | `/api/v1/classrooms/lookup` | `api/v1/classrooms#lookup` | `lookup_api_v1_classrooms` |

Trois endpoints en lecture seule, `render json:` direct, sans sérialiseur ni
jbuilder. `GET /api/v1/schools` exige le paramètre `drena_id` sous peine de 400 ;
`lookup` exige `unique_code`. Les deux contrôleurs appellent
`skip_before_action :authenticate_user!, raise: false` alors qu'`ApplicationController`
ne déclare **aucun** `before_action :authenticate_user!` — l'appel est un no-op et
les endpoints sont publics par construction.

Le fichier de routes porte l'aveu, `config/routes.rb:87` :
`# Should be catalog? Wait, api/v1 controllers were not moved.`

## 1.7 Espace élève (`namespace :students`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/students` | `students/feed#index` | `students_feed` |
| GET | `/students/classroom` | `students/classroom#show` | `students_my_classroom` |
| GET | `/students/training-examens` | `students/exam_subjects#training` | `students_exam_training` |
| GET | `/students/subject-examens` | `students/exam_subjects#subject` | `students_exam_subject_special` |
| GET | `/students/examens` | `students/exam_subjects#index` | `students_exam_subjects` |
| GET | `/students/examens/:id` | `students/exam_subjects#show` | `students_exam_subject` |
| POST | `/students/examens/:id/retry` | `students/exam_subjects#retry` | `retry_students_exam_subject` |

## 1.8 Espace enseignant (`namespace :teachers`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/teachers` | `teachers/feed#index` | `teachers_feed` |
| GET | `/teachers/dashboard` | `teachers/dashboard#index` | `teachers_dashboard` |
| GET | `/teachers/setup` | `teachers/dashboard#setup` | `teachers_setup` |
| GET | `/teachers/classrooms` | `classroom/teachers/classrooms#index` | `teachers_classrooms` |
| POST | `/teachers/classrooms` | `classroom/teachers/classrooms#create` | — |
| GET | `/teachers/classrooms/:id` | `classroom/teachers/classrooms#show` | `teachers_classroom` |
| GET | `/teachers/classrooms/:id/courses/:course_id` | `classroom/teachers/classrooms#course` | `teachers_classroom_course` |
| GET | `/teachers/classrooms/:id/essentials/:essential_id` | `classroom/teachers/classrooms#essential` | `teachers_classroom_essential` |
| GET | `/teachers/classrooms/:classroom_id/students/:public_id` | `classroom/teachers/classrooms#student_detail` | `teachers_classroom_student` |
| GET | `/teachers/classroom_exercises/:slug` | `teachers/classroom_exercises#show` | `teachers_classroom_exercise` |
| GET | `/teachers/classroom_exercises/:slug/report` | `teachers/classroom_exercises#report` | `teachers_classroom_exercise_report` |
| GET | `/teachers/classroom_exercises/:slug/remediation` | `teachers/classroom_exercises#remediation` | `teachers_classroom_exercise_remediation` |
| GET | `/teachers/prepa_acquisitions/new` | `teachers/prepa_acquisitions#new` | `new_teachers_prepa_acquisition` |
| POST | `/teachers/prepa_acquisitions` | `teachers/prepa_acquisitions#create` | `teachers_prepa_acquisitions` |
| GET | `/teachers/prepa_acquisitions/download` | `teachers/prepa_acquisitions#download` | `download_teachers_prepa_acquisitions` |
| GET | `/teachers/training-examens` | `teachers/exam_subjects#training` | `teachers_exam_training` |
| GET | `/teachers/subject-examens` | `teachers/exam_subjects#subject` | `teachers_exam_subject_special` |
| GET | `/teachers/examens` | `teachers/exam_subjects#index` | `teachers_exam_subjects` |
| GET | `/teachers/examens/:id` | `teachers/exam_subjects#show` | `teachers_exam_subject` |
| POST | `/teachers/classroom_exam_assignments` | `teachers/classroom_exam_assignments#create` | `teachers_classroom_exam_assignments` |
| DELETE | `/teachers/classroom_exam_assignments/:id` | `teachers/classroom_exam_assignments#destroy` | `teachers_classroom_exam_assignment` |
| POST | `/teachers/classroom_course_assignments` | `teachers/classroom_course_assignments#create` | `teachers_classroom_course_assignments` |
| DELETE | `/teachers/classroom_course_assignments/:id` | `teachers/classroom_course_assignments#destroy` | `teachers_classroom_course_assignment` |
| POST | `/teachers/classroom_essential_assignments` | `teachers/classroom_essential_assignments#create` | `teachers_classroom_essential_assignments` |
| DELETE | `/teachers/classroom_essential_assignments/:id` | `teachers/classroom_essential_assignments#destroy` | `teachers_classroom_essential_assignment` |

Six routes sont écrites à la main pour pointer **hors** du namespace, vers
`/classroom/teachers/classrooms`. Trois ressources d'assignation distinctes
(`exam`, `course`, `essential`) écrivent pourtant dans la **même** table polymorphe
`classroom_assignments`.

## 1.9 Espace équipe (`namespace :teams`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/teams` | `teams/feed#index` | `teams_feed` |
| GET | `/teams/dashboard` | `teams/dashboard#index` | `teams_dashboard` |
| GET | `/teams/setup` | `teams/dashboard#setup` | `teams_setup` |
| GET | `/teams/lnclassai` | `teams/dashboard#lnclassai` | `teams_lnclassai` |
| GET | `/teams/examens` | `teams/exam_subjects#index` | `teams_exam_subjects` |
| GET | `/teams/examens/new` | `teams/exam_subjects#new` | `new_teams_exam_subject` |
| GET | `/teams/examens/:id` | `teams/exam_subjects#show` | `teams_exam_subject` |
| DELETE | `/teams/examens/:id` | `teams/exam_subjects#destroy` | — |
| POST | `/teams/examens/import_json` | `teams/exam_subjects#import_json` | `import_json_teams_exam_subjects` |

`teams/exam_subjects` a un `new` mais **pas de `create`** : le formulaire n'a pas
de cible. La création passe uniquement par `import_json`.

## 1.10 Espace personnel d'établissement (`namespace :schoolstaff`)

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/schoolstaff` | `schoolstaff/feed#index` | `schoolstaff_feed` |
| GET | `/schoolstaff/profile` | `schoolstaff/profiles#show` | `schoolstaff_profile` |
| GET | `/schoolstaff/profile/edit` | `schoolstaff/profiles#edit` | `edit_schoolstaff_profile` |
| PATCH | `/schoolstaff/profile` | `schoolstaff/profiles#update` | — |
| PUT | `/schoolstaff/profile` | `schoolstaff/profiles#update` | — |
| GET | `/schoolstaff/settings` | `schoolstaff/settings#show` | `schoolstaff_settings` |
| GET | `/schoolstaff/settings/edit` | `schoolstaff/settings#edit` | `edit_schoolstaff_settings` |
| PATCH | `/schoolstaff/settings` | `schoolstaff/settings#update` | — |
| PUT | `/schoolstaff/settings` | `schoolstaff/settings#update` | — |
| GET | `/schoolstaff/classrooms` | `schoolstaff/classrooms#index` | `schoolstaff_classrooms` |
| POST | `/schoolstaff/classrooms` | `schoolstaff/classrooms#create` | — |
| GET | `/schoolstaff/classrooms/new` | `schoolstaff/classrooms#new` | `new_schoolstaff_classroom` |
| GET | `/schoolstaff/classrooms/:id` | `schoolstaff/classrooms#show` | `schoolstaff_classroom` |
| GET | `/schoolstaff/teachers` | `schoolstaff/teachers#index` | `schoolstaff_teachers` |
| POST | `/schoolstaff/teachers` | `schoolstaff/teachers#create` | — |
| GET | `/schoolstaff/teachers/new` | `schoolstaff/teachers#new` | `new_schoolstaff_teacher` |
| GET | `/schoolstaff/students` | `schoolstaff/students#index` | `schoolstaff_students` |
| POST | `/schoolstaff/students` | `schoolstaff/students#create` | — |
| GET | `/schoolstaff/students/new` | `schoolstaff/students#new` | `new_schoolstaff_student` |

Seul espace doté d'un contrôleur de base dédié : `schoolstaff/base_controller.rb`.

## 1.11 Transverse

| Verbe | Chemin | Contrôleur#action | Helper |
|---|---|---|---|
| GET | `/messages` | `messages#index` | `messages` |
| POST | `/messages` | `messages#create` | — |
| GET | `/messages/new` | `messages#new` | `new_message` |
| GET | `/messages/:id` | `messages#show` | `message` |
| GET | `/messages/:id/edit` | `messages#edit` | `edit_message` |
| PATCH | `/messages/:id` | `messages#update` | — |
| PUT | `/messages/:id` | `messages#update` | — |
| DELETE | `/messages/:id` | `messages#destroy` | — |
| DELETE | `/messages/:id/dismiss` | `messages#dismiss` | `dismiss_message` |
| GET | `/profile/edit` | `profiles#edit` | `edit_profile` |
| PATCH | `/profile` | `profiles#update` | `profile` |
| PUT | `/profile` | `profiles#update` | — |
| PATCH | `/install_banner` | `install_banner#update` | `install_banner` |

`resources :messages` est déclaré à la racine, hors de tout scope, alors que le
contexte borné `communication` existe (`repositories/communication/message_repository.rb`).

## 1.12 Routes internes Rails (26 entrées, fournies par les gems)

- `turbo/native/navigation#recede|resume|refresh` — 3 routes (`turbo-rails`)
- `action_mailbox/ingresses/*` — 6 routes (postmark, relay, sendgrid, mandrill ×2, mailgun)
- `rails/conductor/action_mailbox/*` — 8 routes (développement uniquement)
- `active_storage/*` — 9 routes (blobs redirect/proxy, representations, disk, direct_uploads)
- `Debugbar::Engine` monté sur `/_debugbar` — 5 routes internes (développement)

Action Mailbox est routé alors qu'aucune classe de boîte de réception n'existe.

## 1.13 Routes orphelines et contrôleurs sans route

Vérification par résolution de constantes et introspection `action_methods` sur
l'application chargée.

**Contrôleurs inexistants : aucun.** Chaque `controller#action` routé correspond à
une classe présente sur le disque.

**Action routée absente de son contrôleur (1)**

| Route | Problème |
|---|---|
| `GET /schoolstaff/settings/edit` → `schoolstaff/settings#edit` | L'action `edit` n'existe pas dans `app/controllers/schoolstaff/settings_controller.rb` |

**Action publique sans route (1)**

| Action | Fichier |
|---|---|
| `catalog/drenas#import_json` | `app/controllers/catalog/drenas_controller.rb` — seuls `catalog/schools#import_json` et `catalog/courses#import_json` sont routés |

**Contrôleurs sans aucune route (2)** — les deux sont des classes de base, c'est attendu

- `app/controllers/application_controller.rb`
- `app/controllers/schoolstaff/base_controller.rb`

**Routes qui lèvent à l'exécution (10)** — les 10 routes `exam_subjects` des trois
espaces : `Orm::ExamSubject` n'existe pas (voir §2.7). `NameError` garanti.

**Route attendue et absente (1)** — il n'existe **aucune route `/up`**, alors que
`config/environments/production.rb:47` déclare
`config.silence_healthcheck_path = "/up"`. Le healthcheck par défaut de Rails 8 a
été retiré de `config/routes.rb`. Toute sonde Railway sur `/up` reçoit un 404.

---

# 2. Le schéma de base complet

Source : `db/schema.rb` (620 lignes), `ActiveRecord::Schema[8.1]`, version
`2026_08_29_235900`. PostgreSQL, une seule extension activée :
`pg_catalog.plpgsql`. **46 tables** — 27 métier, 5 d'infrastructure Rails,
14 de la Solid Suite.

Convention de lecture : les colonnes `id` (bigserial) et les paires
`created_at` / `updated_at` (`datetime null: false`) sont présentes partout sauf
mention contraire, et ne sont pas répétées.

## 2.1 Tables métier — identité

### `users`

| Colonne | Type | Contraintes |
|---|---|---|
| `contact` | string | **limit: 10**, `null: false` |
| `firstname` | string | `null: false` |
| `lastname` | string | `null: false` |
| `fullname` | string | limit: 150, `null: false` |
| `gender` | string | — |
| `password_digest` | string | `null: false` |
| `public_id` | string | `null: false` |
| `role` | integer | défaut 0, `null: false` |
| `slug` | string | `null: false` |
| `is_demo` | boolean | défaut false, `null: false` |
| `install_banner_status` | integer | défaut 0, `null: false` |
| `install_banner_last_changed_at` | datetime | — |

Index : `contact` (unique), `public_id` (unique), `slug` (unique), `role`.
Clés étrangères : aucune (table racine).

### `students`

| Colonne | Type | Contraintes |
|---|---|---|
| `matricule` | string | limit: 15 |
| `user_id` | bigint | `null: false` |

Index : `matricule`, `user_id`. FK : `students → users` `on_delete: :cascade`.

### `teachers`

| Colonne | Type | Contraintes |
|---|---|---|
| `material_id` | bigint | — |
| `user_id` | bigint | `null: false` |

Index : `material_id`, `user_id`. FK : `teachers → users` cascade.
**Aucune FK vers `materials`** — seule colonne `_id` métier du schéma sans clé étrangère.

### `teams`

| Colonne | Type | Contraintes |
|---|---|---|
| `user_id` | bigint | `null: false` |

Index : `user_id`. FK : `teams → users` cascade. Table à une seule colonne utile.

## 2.2 Tables métier — organisation scolaire

### `drenas`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 50 |
| `public_id` | string | — |
| `slug` | string | — |
| `team_id` | bigint | — |

Index : `name` (unique), `public_id` (unique), `slug` (unique), `team_id`.
FK : `drenas → teams` `on_delete: :nullify`.

### `schools`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 150, `null: false` |
| `schoolsigle` | string | limit: 10 |
| `schoolstatus` | string | `null: false` |
| `schooltype` | integer | — |
| `drena_id` | bigint | `null: false` |
| `team_id` | bigint | — |
| `public_id` | string | — |
| `slug` | string | `null: false` |

Index : `drena_id`, `name` (unique), `public_id` (unique), `slug` (unique), `team_id`.
FK : `schools → drenas` cascade, `schools → teams` nullify.

### `school_roles`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | **ni `null: false`, ni `limit`** |
| `school_id` | bigint | `null: false` |

Index : `school_id`. FK : `school_roles → schools` cascade.

### `school_staffs`

| Colonne | Type | Contraintes |
|---|---|---|
| `school_id` | bigint | `null: false` |
| `school_role_id` | bigint | `null: false` |
| `user_id` | bigint | `null: false` |

Index : `school_id`, `school_role_id`, `user_id` — **trois index simples, aucun unique**.
FK : `→ school_roles` `on_delete: :restrict`, `→ schools` cascade, `→ users` cascade.

### `classrooms`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | **limit: 15**, `null: false` |
| `unique_code` | string | **limit: 5**, `null: false` |
| `level_id` | bigint | `null: false` |
| `school_id` | bigint | `null: false` |
| `series_id` | bigint | — |
| `public_id` | string | — |
| `slug` | string | — |

Index : `level_id`, `public_id` (unique), `[school_id, name]` (unique), `school_id`,
`series_id`, `slug` (unique), `unique_code` (unique).
FK : `→ levels` cascade, `→ schools` cascade, `→ series` nullify.

### `classroom_students`

| Colonne | Type | Contraintes |
|---|---|---|
| `classroom_id` | bigint | `null: false` |
| `student_id` | bigint | `null: false` |
| `primary` | boolean | défaut false, `null: false` |
| `joined_at` | datetime | — |

Index : `classroom_id`, `[student_id, classroom_id]` (unique), `student_id`.
FK : `→ classrooms` cascade, `→ students` cascade. Porte l'ADR-0003 (multi-appartenance).

### `teacher_classrooms`

| Colonne | Type | Contraintes |
|---|---|---|
| `classroom_id` | bigint | `null: false` |
| `teacher_id` | bigint | `null: false` |

Index : `classroom_id`, `[teacher_id, classroom_id]` (unique), `teacher_id`.
FK : `→ classrooms` cascade, `→ teachers` cascade.

### `teacher_schools`

| Colonne | Type | Contraintes |
|---|---|---|
| `school_id` | bigint | `null: false` |
| `teacher_id` | bigint | `null: false` |

Index : `school_id`, `[teacher_id, school_id]` (unique), `teacher_id`.
FK : `→ schools` cascade, `→ teachers` cascade. Porte l'ADR-0004.

## 2.3 Tables métier — taxonomie et catalogue

### `levels`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 20 |
| `public_id` | string | — |
| `slug` | string | — |
| `team_id` | bigint | — |

Index : `name` (unique), `public_id` (unique), `slug` (unique), `team_id`.
FK : `→ teams` nullify.

### `series`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | `null: false` |
| `public_id` | string | `null: false` |
| `slug` | string | `null: false` |

Index : `name` (unique), `public_id` (unique), `slug` (unique).
FK : **aucune** — seule table métier sans clé étrangère sortante. Pas de `team_id`,
contrairement à `levels`, `materials` et `drenas`.

### `level_series`

| Colonne | Type | Contraintes |
|---|---|---|
| `level_id` | bigint | `null: false` |
| `series_id` | bigint | `null: false` |

Index : `[level_id, series_id]` (unique), `level_id`, `series_id`.
FK : `→ levels` cascade, `→ series` cascade.

### `materials`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 25, `null: false` |
| `shortname` | string | limit: 10 |
| `category` | integer | défaut 2 |
| `public_id` | string | — |
| `slug` | string | — |
| `team_id` | bigint | — |

Index : `name` (unique), `public_id` (unique), `slug` (unique), `team_id`.
FK : `→ teams` nullify.

### `courses`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 200, `null: false` |
| `subtitle` | string | limit: 150 |
| `status` | string | `null: false` |
| `published_at` | date | — |
| `essentials_count` | integer | défaut 0, `null: false` |
| `import_data` | jsonb | défaut `{}` |
| `level_id` | bigint | `null: false` |
| `material_id` | bigint | `null: false` |
| `series_id` | bigint | — |
| `slug` | string | `null: false` |

Index : `import_data` (**GIN**), `level_id`, `material_id`, `name` (unique),
`series_id`, `slug` (unique).
FK : `→ levels` cascade, `→ materials` cascade, `→ series` nullify.

### `essentials`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 150, `null: false` |
| `subtitle` | string | limit: 150 |
| `course_id` | bigint | `null: false` |
| `exercises_count` | integer | défaut 0, `null: false` |
| `import_data` | jsonb | défaut `{}` |
| `slug` | string | `null: false` |
| `validated_at` | date | — |
| `validated_by` | integer | — (entier nu, pas une FK) |

Index : `[course_id, name]` (unique), `course_id`, `import_data` (**GIN**).
FK : `→ courses` cascade. **Aucun index sur `slug`**, contrairement à `courses`.

## 2.4 Tables métier — évaluation

### `exercises`

| Colonne | Type | Contraintes |
|---|---|---|
| `title` | string | `null: false` |
| `description` | text | — |
| `essential_id` | bigint | **nullable** |
| `exercise_type` | integer | — |
| `published` | boolean | défaut false |
| `questions_count` | integer | défaut 0, `null: false` |
| `recurrence_rate` | integer | — |
| `source_exam` | string | — |
| `import_data` | jsonb | défaut `{}` |
| `team_id` | bigint | — |
| `slug` | string | — |

Index : `essential_id`, `import_data` (**GIN**), `slug` (**non unique**), `team_id`.
FK : `→ essentials` cascade, `→ teams` nullify.

### `questions`

| Colonne | Type | Contraintes |
|---|---|---|
| `content` | text | `null: false` |
| `exercise_id` | bigint | `null: false` |
| `explanation` | text | — |
| `position` | integer | — |
| `question_type` | integer | défaut 0, `null: false` |

Index : `exercise_id`. FK : `→ exercises` cascade.

### `answers`

| Colonne | Type | Contraintes |
|---|---|---|
| `content` | string | `null: false` |
| `is_correct` | boolean | défaut false, `null: false` |
| `question_id` | bigint | `null: false` |

Index : `question_id`. FK : `→ questions` cascade.
`content` est une `string` (255) alors que `questions.content` est un `text`.

### `exercise_sessions`

| Colonne | Type | Contraintes |
|---|---|---|
| `exercise_id` | bigint | `null: false` |
| `student_id` | bigint | `null: false` |
| `status` | string | défaut `"started"` (sans `null: false`) |
| `score` | float | défaut 0.0 (sans `null: false`) |
| `percentage` | integer | défaut 0 (sans `null: false`) |
| `badge_level` | string | — |
| `started_at` | datetime | — |
| `completed_at` | datetime | — |
| `slug` | string | — |

Index : `exercise_id`, `slug` (unique), `student_id`.
FK : `→ exercises` cascade, `→ students` cascade.

### `question_attempts`

| Colonne | Type | Contraintes |
|---|---|---|
| `exercise_session_id` | bigint | `null: false` |
| `question_id` | bigint | `null: false` |
| `is_correct` | boolean | défaut false |
| `provided_answer` | text | — |
| `answer_data` | jsonb | défaut `{}` |
| `attempted_answer_ids` | integer[] | défaut `[]`, array |

Index : `exercise_session_id`, `question_id`.
FK : `→ exercise_sessions` cascade, `→ questions` cascade.
Trois représentations concurrentes de la réponse : `provided_answer`,
`answer_data`, `attempted_answer_ids`.

### `exercise_badges`

| Colonne | Type | Contraintes |
|---|---|---|
| `exercise_id` | bigint | `null: false` |
| `student_id` | bigint | `null: false` |
| `level` | integer | `null: false` |
| `earned_at` | datetime | — |
| `slug` | string | — |

Index : `exercise_id`, `slug` (unique), `[student_id, exercise_id]` (unique), `student_id`.
FK : `→ exercises` cascade, `→ students` cascade. Porte l'ADR-0008 (gamification).

### `knowledge_gaps`

**Clé primaire `id: :string`** — seule table du schéma à ne pas utiliser un bigint.

| Colonne | Type | Contraintes |
|---|---|---|
| `student_id` | bigint | `null: false` |
| `essential_id` | bigint | `null: false` |
| `exercise_session_id` | bigint | — |
| `status` | string | défaut `"pending"`, `null: false` |
| `failed_attempts_count` | integer | défaut 1, `null: false` |
| `resolved_at` | datetime | — |

Index (7) : `essential_id`, `exercise_session_id`, `status`,
`[student_id, essential_id, status]`, `[student_id, essential_id]`,
`[student_id, status]`, `student_id`.
FK : `→ essentials` cascade, `→ exercise_sessions` nullify, `→ students` cascade.
Table la plus indexée du schéma. Porte l'ADR-0018 (remédiation just-in-time).

## 2.5 Tables métier — assignation et communication

### `classroom_assignments`

Table **polymorphe** introduite par `20260829202238_create_classroom_assignments.rb`
pour fusionner les anciennes `classroom_courses`, `classroom_essentials` et
`classroom_exercises`.

| Colonne | Type | Contraintes |
|---|---|---|
| `classroom_id` | bigint | `null: false` |
| `resource_type` | string | `null: false` |
| `resource_id` | bigint | `null: false` |
| `assigned_by_id` | bigint | — |
| `status` | string | défaut `"active"`, `null: false` |

Index : `[classroom_id, resource_type, resource_id]` (unique),
`classroom_id`, `[resource_type, resource_id]`.
FK : `→ classrooms`, `→ users` (colonne `assigned_by_id`) nullify.
Aucune contrainte ne restreint les valeurs de `resource_type` — il accepte
`"ExamSubject"`, un type sans table. Porte l'ADR-0007 et l'ADR-0016.

### `messages`

| Colonne | Type | Contraintes |
|---|---|---|
| `name` | string | limit: 100, `null: false` |
| `audience` | integer | `null: false` |
| `message_status` | integer | `null: false` |
| `published_at` | date | `null: false` |
| `team_id` | bigint | — |
| `slug` | string | `null: false` |

Index : `slug` (unique), `team_id`. FK : `→ teams` nullify.
Le corps du message n'est pas dans la table : `Orm::Message` déclare
`has_one_attached :image_cover` et `has_one_attached :message_audio`.

## 2.6 Tables d'infrastructure

### Rails (5)

| Table | Colonnes | Index |
|---|---|---|
| `action_text_rich_texts` | `body` (text), `name` (`null: false`), `record_id`, `record_type` | `[record_type, record_id, name]` unique |
| `active_storage_attachments` | `blob_id`, `name`, `record_id`, `record_type` (pas d'`updated_at`) | `blob_id`, `[record_type, record_id, name, blob_id]` unique |
| `active_storage_blobs` | `byte_size` (`null: false`), `checksum`, `content_type`, `filename` (`null: false`), `key` (`null: false`), `metadata` (text), `service_name` (`null: false`) — pas d'`updated_at` | `key` unique |
| `active_storage_variant_records` | `blob_id`, `variation_digest` — pas de timestamps | `[blob_id, variation_digest]` unique |
| `friendly_id_slugs` | `slug` (`null: false`), `scope`, `sluggable_id` (integer, `null: false`), `sluggable_type` (limit: 50) — pas d'`updated_at` | `[slug, sluggable_type, scope]` unique, `[slug, sluggable_type]`, `[sluggable_type, sluggable_id]` |

FK : `active_storage_attachments → active_storage_blobs` (`blob_id`),
`active_storage_variant_records → active_storage_blobs` (`blob_id`).

### Solid Suite (14)

Créées en bloc par `20260829235900_create_solid_tables.rb`.

| Table | Rôle |
|---|---|
| `solid_cache_entries` | `key` (binary), `key_hash` (bigint), `value` (binary), `byte_size` — 3 index dont `key_hash` unique |
| `solid_cable_messages` | `channel` (binary), `channel_hash` (bigint), `payload` (binary) — 3 index |
| `solid_queue_jobs` | `class_name`, `queue_name`, `active_job_id`, `arguments` (text), `priority`, `scheduled_at`, `finished_at`, `concurrency_key` — 5 index |
| `solid_queue_ready_executions` | `job_id` unique, `queue_name`, `priority` — 3 index |
| `solid_queue_scheduled_executions` | `job_id` unique, `scheduled_at`, `priority`, `queue_name` |
| `solid_queue_claimed_executions` | `job_id` unique, `process_id` |
| `solid_queue_blocked_executions` | `job_id` unique, `concurrency_key`, `expires_at`, `priority`, `queue_name` |
| `solid_queue_failed_executions` | `job_id` unique, `error` (text) |
| `solid_queue_processes` | `kind`, `name`, `pid`, `hostname`, `last_heartbeat_at`, `supervisor_id`, `metadata` |
| `solid_queue_pauses` | `queue_name` unique |
| `solid_queue_semaphores` | `key` unique, `value` (défaut 1), `expires_at` |
| `solid_queue_recurring_tasks` | `key` unique, `schedule` (`null: false`), `command` (limit: 2048), `class_name`, `arguments`, `priority`, `queue_name`, `static` (défaut true), `description` |
| `solid_queue_recurring_executions` | `job_id` unique, `task_key`, `run_at`, `[task_key, run_at]` unique |

Les 6 tables d'exécution portent toutes une FK
`→ solid_queue_jobs (job_id) on_delete: :cascade`.

## 2.7 Table manquante : `exam_subjects`

`Orm::ExamSubject` **n'existe pas** — ni fichier dans `app/infrastructure/orm/`,
ni table dans PostgreSQL (vérifié par `ActiveRecord::Base.connection.tables`).
La constante est pourtant référencée **3 fois** :

- `app/infrastructure/queries/exam_catalog_query.rb:12`
- `app/infrastructure/queries/exam_catalog_query.rb:13`
- `app/infrastructure/queries/exam_catalog_query.rb:24`

`Entities::ExamSubject` existe bien (`app/domain/entities/exam_subject.rb`,
5 références) et `app/infrastructure/repositories/assessment/exam_repository.rb:9`
déclare dans son en-tête HITL utiliser `Orm::ExamSubject`.

Conséquence : les **10 routes** `exam_subjects` des trois espaces lèvent
`NameError` à l'exécution. Chantier ouvert :
`docs/chantiers/acteurs-fantomes-parent-examsubject/memo.md` — décision produit du
2026-09-18 : le concept est **reporté, pas abandonné** (il sera traité pendant la
période de préparation aux examens).

Deux autres constantes ORM ont disparu dans la même migration vers
`classroom_assignments`, sans que les requêtes de lecture soient adaptées :

| Constante | Références |
|---|---|
| `Orm::ClassroomEssential` | `app/infrastructure/queries/teachers_feed_query.rb:49` |
| `Orm::ClassroomExercise` | `app/controllers/teachers/classroom_exercises_controller.rb:76`, `app/infrastructure/queries/student_feed_query.rb:30` |

Chantier : `docs/chantiers/queries-constantes-orm-disparues/memo.md`, gravité
« bloquant — aucun élève ni enseignant ne peut se connecter ».

## 2.8 Tables vides de sens ou jamais écrites

| Table | Preuve |
|---|---|
| `level_series` | `Orm::LevelSeries` n'a que 3 références, toutes dans les déclarations d'association (`orm/level.rb:23`, `orm/series.rb:21`, `orm/level_series.rb`). L'écriture passe par `record.series = Orm::Series.where(id: ids)` (`repositories/catalog/level_repository.rb:53`) et `level.series << series` (`course_repository.rb:139`). `taxonomy_repository.rb:22` porte le commentaire « Si une table de jointure level_series existe (comme avant) » — le modèle était en cours d'abandon |
| `friendly_id_slugs` | La migration `20260814165405` la crée, mais les 2 seuls usages de FriendlyId déclarent `use: :slugged` **sans** `:history` (`orm/user.rb:31`, `models/concerns/sluggable.rb:20`). `:slugged` seul écrit dans la colonne `slug` du modèle. La table ne reçoit jamais de ligne |
| `action_text_rich_texts` | Aucun `has_rich_text` dans `app/`. Seuls `trix` et `@rails/actiontext` sont importés côté JS (`app/javascript/application.js:14-15`) et `actiontext.css` dans la feuille Tailwind |
| `teacher_classrooms` | Lue en `joins` (`classroom_repository.rb:43`, `teachers_feed_query.rb:32`) mais **aucune écriture** dans `app/`. Aucun use case ne lie un enseignant à une classe |
| `answers` | 3 références, toutes en lecture. Aucun use case ne crée de réponse hors import JSON |

La base de développement locale est **entièrement vide** — 0 ligne dans les
32 tables métier — ce qui interdit toute mesure d'usage par les données.

## 2.9 Colonnes sans aucun usage dans `app/`

Recherche par nom sur tout `app/` (`.rb` et `.erb`), fichier ORM inclus.

| Colonne | Table | Occurrences |
|---|---|---|
| `validated_at` | `essentials` | **0** |
| `validated_by` | `essentials` | **0** |
| `recurrence_rate` | `exercises` | **0** |
| `answer_data` (jsonb) | `question_attempts` | **0** |
| `source_exam` | `exercises` | 1 (la déclaration seule) |
| `import_data` (jsonb, 3 tables, 3 index GIN) | courses, essentials, exercises | 2 |

`validated_at` et `validated_by` correspondent aux vues
`app/views/community_validations/` (ADR-0011, validation collaborative) : les
partiels sont rendus par 4 vues, mais aucun contrôleur, aucune route et aucun use
case n'écrivent ces colonnes.

## 2.10 Incohérences du schéma

1. **`classrooms.unique_code` limit: 5** alors que `app/domain/use_cases/classroom/create_classroom.rb:42` génère `SecureRandom.alphanumeric(6)` — 6 caractères. Chantier : `docs/chantiers/classroom-code-adhesion-trop-long/memo.md`.
2. **`users.contact` limit: 10** — numéro de téléphone sans indicatif pays possible, alors que c'est l'identifiant de connexion (ADR-0002).
3. **`school_roles.name`** : ni `null: false`, ni `limit`, alors que toutes les autres colonnes `name` du schéma ont au moins un `limit`.
4. **`school_staffs`** : aucun index unique sur `[user_id, school_id]` ni `[user_id, school_role_id]` — un même utilisateur peut être inséré N fois dans le même établissement.
5. **`teachers.material_id`** : index présent, **aucune FK** vers `materials`.
6. **`essentials.validated_by`** : `integer` nu, sans FK vers `users`, alors que `classroom_assignments.assigned_by_id` est un `bigint` avec FK.
7. **`exercises.essential_id` nullable** alors que `courses.level_id`, `courses.material_id` et `essentials.course_id` sont `null: false` — asymétrie dans la hiérarchie pédagogique (ADR-0007).
8. **`exercises.slug` non unique** alors que `courses.slug`, `essentials.slug`, `classrooms.slug`, `exercise_sessions.slug`, `exercise_badges.slug`, `messages.slug`, `users.slug` le sont tous. Or `teachers/classroom_exercises#show|report|remediation` route sur `:slug`.
9. **`essentials.slug`** : `null: false` mais **aucun index**, contrairement à toutes les autres colonnes `slug` du schéma.
10. **`exercise_sessions.status`, `score`, `percentage`** : valeurs par défaut mais pas de `null: false`.
11. **`knowledge_gaps.id: :string`** — seule clé primaire non-bigint du schéma.
12. **`classroom_assignments.resource_type`** : polymorphe sans contrainte de valeur ; accepte `"ExamSubject"`, type sans table.
13. **`series`** est la seule table de taxonomie sans `team_id`, alors que `levels`, `materials` et `drenas` en ont un.
14. **`answers.content`** est une `string` (255 caractères) tandis que `questions.content` est un `text`.

## 2.11 Migrations

**19 fichiers** dans `db/migrate/`, du `20260814165405` au `20260829235900`.

| Migration | Contenu |
|---|---|
| `20260814165405_create_friendly_id_slugs.rb` | Table `friendly_id_slugs` |
| `20260814165415_create_active_storage_tables.active_storage.rb` | 3 tables Active Storage |
| `20260814165416_create_action_text_tables.action_text.rb` | `action_text_rich_texts` |
| `20260814165912_create_priority1_tables.rb` | — |
| `20260814165957_create_priority2_tables.rb` | — |
| `20260814170059_create_priority3_tables.rb` | — |
| `20260814170117_create_priority4_tables.rb` | — |
| `20260814170154_create_priority5_tables.rb` | — |
| `20260814170204_create_priority6_tables.rb` | — |
| `20260814170325_create_messages.rb` | `messages` |
| `20260814170350_add_install_banner_status_to_users.rb` | 2 colonnes sur `users` |
| `20260819181851_create_school_roles.rb` | `school_roles` |
| `20260819181855_create_school_staffs.rb` | `school_staffs` |
| `20260819181858_add_school_to_students.rb` | `students.school_id` |
| `20260827140000_create_knowledge_gaps.rb` | `knowledge_gaps` |
| `20260827145746_add_is_demo_to_users.rb` | `users.is_demo` |
| `20260829201522_remove_school_id_from_students.rb` | Retire `students.school_id` |
| `20260829202238_create_classroom_assignments.rb` | `classroom_assignments` |
| `20260829235900_create_solid_tables.rb` | 14 tables Solid Suite |

**Cohérence** : la version du schéma (`2026_08_29_235900`) correspond exactement à
la dernière migration. `db/schema.rb` est à jour vis-à-vis de `db/migrate/`.

Anomalies :

- `bin/rails db:migrate:status` affiche une ligne `up 000 ********** NO FILE **********` : la table `schema_migrations` de la base de développement contient une version fantôme `000` sans fichier correspondant.
- Six migrations `create_priorityN_tables` créent tout le schéma métier en blocs anonymes — la nomenclature ne dit rien de leur contenu.
- Aller-retour complet : `20260819181858_add_school_to_students.rb` puis, dix jours plus tard, `20260829201522_remove_school_id_from_students.rb`.
- `db/seeds.rb` ne fait que 494 octets ; `bin/ci` exécute pourtant `db:seed:replant` comme étape de test.
- Trois schémas séparés existent pour la Solid Suite (`db/cable_schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb`) alors que les 14 tables sont dans la base primaire via `20260829235900`. Aucune base secondaire n'est déclarée dans `config/database.yml` : ces trois fichiers ne sont jamais chargés.

---

# 3. Les jobs et le traitement asynchrone

**5 jobs** dans `app/jobs/`, tous en `queue_as :default`, tous héritant de
`ApplicationJob` (`app/jobs/application_job.rb`) — qui ne configure **aucun**
`retry_on` ni `discard_on` : les deux lignes du générateur sont restées commentées.
Aucune file nommée, aucune priorité, aucune politique de reprise.

| Job | Fichier | Ce qu'il fait | Déclencheur | Criticité |
|---|---|---|---|---|
| `ImportCoursesJsonJob` | `app/jobs/import_courses_json_job.rb` | Lit un JSON temporaire, appelle `Repositories::Catalog::CourseRepository#bulk_import_courses`, supprime le fichier en `ensure` | `app/controllers/catalog/courses_controller.rb:183` | Peuplement du catalogue. Échec silencieux : aucune trace en base, aucune notification à l'utilisateur |
| `ImportDrenasJsonJob` | `app/jobs/import_drenas_json_job.rb` | `Strategies::DrenaImportStrategy` + `UseCases::ImportCatalogData#execute` | `app/controllers/catalog/drenas_controller.rb:35` | Idem |
| `ImportSchoolsJsonJob` | `app/jobs/import_schools_json_job.rb` | `Strategies::SchoolImportStrategy` + `UseCases::ImportCatalogData#execute` | `app/controllers/catalog/schools_controller.rb:99` | Idem |
| `SimulateClassroomExerciseJob` | `app/jobs/simulate_classroom_exercise_job.rb` | Pour chaque élève `is_demo: true` d'une classe, exécute `UseCases::Assessment::SimulateDemoStudentSession` | **Aucun appelant** | **Mort** (ADR-0019) |
| `Catalog::GenerateSchoolDemoDataJob` | `app/jobs/catalog/generate_school_demo_data_job.rb` | Génère les classes par défaut d'un établissement (`UseCases::Catalog::GenerateDefaultClassrooms`) puis injecte des élèves de démo dans les 2 premières classes de chaque niveau (`UseCases::Classroom::GenerateDemoStudents`) | **Aucun appelant** | **Mort** (ADR-0019) |

Preuve des deux jobs morts : `grep -rn "perform_later\|perform_now" app/ lib/` ne
renvoie que les trois appels d'import listés ci-dessus.

Les trois jobs vivants partagent le même patron : fichier temporaire écrit par le
contrôleur, chemin passé en argument, `return unless File.exist?(file_path)`,
suppression en `ensure`. Le fichier temporaire est un couplage au système de
fichiers local — sur Railway, un job repris par un autre conteneur ne trouvera pas
le fichier et sortira silencieusement.

**Aucun e-mail n'est jamais envoyé** : `app/mailers/` ne contient que
`application_mailer.rb` et aucun `Mailer.` n'apparaît dans `app/`.

## 3.1 Solid Suite (ADR-0010 — ni Redis ni Sidekiq)

### solid_queue

`config/queue.yml` : 1 dispatcher (`polling_interval: 1`, `batch_size: 500`),
workers sur `queues: "*"`, 3 threads, `ENV.fetch("JOB_CONCURRENCY", 1)` processus.
La configuration est **identique dans les trois environnements** (`<<: *default`).

L'adaptateur n'est activé qu'en production
(`config/environments/production.rb:54` : `config.active_job.queue_adapter = :solid_queue`).
En développement et en test, ActiveJob reste sur l'adaptateur `:async` par défaut —
les jobs s'exécutent en mémoire, dans le processus, et disparaissent au redémarrage.

Lancement du worker : `bin/jobs` (`SolidQueue::Cli`), ou à l'intérieur de Puma si
`ENV["SOLID_QUEUE_IN_PUMA"]` est posé (`config/puma.rb:39`).

### solid_cache

`config/cache.yml` : `max_size: 256 Mo`, `namespace: <%= Rails.env %>`,
`max_age` commenté. Actif en production seulement
(`config.cache_store = :solid_cache_store`) ; `:memory_store` en développement,
`:null_store` en test.

### solid_cable

`config/cable.yml` : `async` en développement, `test` en test,
**`solid_cable` uniquement en production** (`polling_interval: 0.1.seconds`,
`message_retention: 1.day`).

Le répertoire `app/channels/` **n'existe pas** et aucun `broadcast` n'apparaît
dans `app/` : Action Cable est configuré de bout en bout mais jamais utilisé.
Les mises à jour temps réel passent exclusivement par Turbo Streams — 35 vues
concernées, dont 33 fichiers `*.turbo_stream.erb`.

### Tâches récurrentes

`config/recurring.yml` ne définit qu'une entrée, **en production seulement** :

```yaml
clear_solid_queue_finished_jobs:
  command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
  schedule: every hour at minute 12
```

Aucune tâche métier planifiée (pas de relance, pas de rapport, pas de purge de
données applicatives).

---

# 4. L'internationalisation

**3 fichiers** dans `config/locales/`, 80 lignes cumulées.

| Fichier | Taille | Contenu réel |
|---|---|---|
| `config/locales/en.yml` | 31 lignes | 29 lignes de commentaires du générateur Rails, puis `en: hello: "Hello world"` |
| `config/locales/fr.yml` | 25 lignes | `hello`, puis `activemodel.models` et `activemodel.attributes` pour 5 entités : `entities/user` (fullname, firstname, lastname, contact, gender, password, role), `entities/student` (matricule), `entities/teacher` (material_id), `entities/team` (user_id), `entities/series` (name) |
| `config/locales/gamification.fr.yml` | 24 lignes | Deux listes de 10 phrases d'encouragement : `fr.gamification.correct` et `fr.gamification.incorrect` |

**Configuration** — `config/application.rb:29-30` :

```ruby
config.i18n.default_locale = :fr
config.i18n.available_locales = [ :fr, :en ]
```

La gem `rails-i18n ~> 8.1` fournit les traductions standard (dates, messages de
validation ActiveModel, formats de nombres).

## 4.1 Taux de couverture réel

**314 vues sur 315 ne contiennent aucun appel `t(` ni `I18n.t`.**

L'unique exception est `app/views/assessment/exercise_sessions/_feedback_card.html.erb`,
qui lit les phrases de `gamification.fr.yml`.

**Zéro appel à `I18n.t` dans tout le code Ruby de `app/`** — contrôleurs, use cases,
repositories, jobs confondus.

Toutes les chaînes d'interface sont écrites en dur, en français, directement dans
les vues et les contrôleurs. Échantillon :

| Chaîne | Emplacement |
|---|---|
| `"Veuillez vous connecter pour continuer."` | `app/controllers/concerns/current_user_concern.rb:63` |
| `"Accès non autorisé."` | `app/controllers/concerns/current_user_concern.rb:73` |
| `"Accès réservé aux élèves"` | `app/controllers/students/exam_subjects_controller.rb:25` |
| `"Code requis"`, `"Classe introuvable"` | `app/controllers/api/v1/classrooms_controller.rb:25,33` — **réponses JSON d'API** |
| `"Drena ID is required"` | `app/controllers/api/v1/schools_controller.rb:22` — seule chaîne d'interface en anglais |
| `name: "Aucun niveau"` | `app/views/schoolstaff/feed/content/_levels.html.erb:28` |
| `name: "Aucune activité récente"` | `app/views/schoolstaff/feed/content/_activities.html.erb:147` |
| `name: "Aucun message"` | `app/views/schoolstaff/feed/content/_messages.html.erb:45` |
| `"Charger la suite"` | `app/views/classroom/classrooms/students.html.erb:27` |

## 4.2 Garde-fous absents

- `config.i18n.raise_on_missing_translations` est **commenté** dans `config/environments/development.rb:64` et `config/environments/test.rb:47` : aucune détection de clé manquante.
- `config.i18n.fallbacks = true` n'est posé qu'en production (`production.rb:70`).
- Aucun test ne vérifie la parité entre `fr.yml` et `en.yml`.

Le seul point où la locale influence le rendu est
`app/views/layouts/application.html.erb:5` : `<html lang="<%= I18n.locale %>">`.
Le reste de l'application rendrait exactement la même page en `:en`.

La règle d'or n°3 du `CLAUDE.md` (« I18n — locale par défaut `:fr`, toujours
`t(".key")` ») n'est appliquée nulle part.

---

# 5. La configuration et le déploiement

## 5.1 Les gems du Gemfile

`Gemfile` — 2,9 Ko, `Gemfile.lock` — 24 Ko. Ruby 3.4.9 (`.ruby-version`),
Node 24.13.1 (`.node-version`).

### Socle Rails 8

| Gem | Version | Usage |
|---|---|---|
| `rails` | `~> 8.1.3, >= 8.1.3.1` | `require "rails/all"` dans `config/application.rb` |
| `pg` | `~> 1.1` | PostgreSQL |
| `puma` | `>= 5.0` | `config/puma.rb` |
| `bootsnap` | — | `require: false`, `config/boot.rb`, précompilé dans le `Dockerfile` |
| `tzinfo-data` | — | plateformes Windows/JRuby uniquement |

### Assets et frontend

| Gem | Usage |
|---|---|
| `propshaft` | Pipeline d'assets |
| `jsbundling-rails` | Bridge esbuild |
| `cssbundling-rails` | Bridge Tailwind CLI |
| `turbo-rails` | 35 vues utilisent `turbo_stream` |
| `stimulus-rails` | 31 contrôleurs Stimulus |

### Fonctionnel

| Gem | Version | Preuve d'usage |
|---|---|---|
| `bcrypt` | `~> 3.1.7` | `has_secure_password` — `app/infrastructure/orm/user.rb:19` |
| `friendly_id` | — | 2 usages : `orm/user.rb:31`, `models/concerns/sluggable.rb:20` |
| `pagy` | `~> 9.3` | `include Pagy::Backend` (`application_controller.rb:13`), `pagy_array` (`classroom/classrooms_controller.rb:78`), `config/initializers/pagy.rb` charge `pagy/extras/array` |
| `heroicons` | `~> 2.2` | 138 occurrences dans les vues ; configuré par `config/initializers/heroicons.rb` (variant `:outline`, classes par défaut) |
| `image_processing` | `~> 1.2` | 3 usages de `variant` |
| `active_storage_validations` | `~> 3.0` | 5 `has_one_attached` : `essential.image_cover`, `user.avatar`, `course.image_cover`, `message.image_cover`, `message.message_audio` |
| `rails-i18n` | `~> 8.1` | Traductions standard `fr` |
| `ostruct` | — | 179 occurrences — les use cases retournent des `OpenStruct` (ADR-0013) |

### Développement et test

`debug`, `bundler-audit` (config `config/bundler-audit.yml`), `brakeman`,
`rubocop-rails-omakase`, `web-console`, `debugbar`, `capybara`,
`selenium-webdriver`, `simplecov`.

### Gems sans usage détecté

| Gem | Preuve |
|---|---|
| `kamal` | `docs/guide/stack.md:203` : « Kamal n'est pas utilisé. La gem `kamal` est encore au Gemfile, `bin/kamal`, `config/deploy.yml` et `.kamal/` existent encore : aucun de ces fichiers n'a de rôle opérationnel. » `config/deploy.yml` contient toujours l'IP du générateur (`servers: web: - 192.168.0.1`), `.kamal/hooks/` ne contient que 9 fichiers `.sample` |
| `jbuilder` | **0 fichier `.jbuilder`** dans `app/views`. Les deux contrôleurs API font `render json:` sur des structures Ruby |
| `thruster` | Utilisée seulement dans le `CMD` du `Dockerfile` (`./bin/thrust`). Active en production via l'image Railway, absente du développement |

`gem "bullet"` est commentée dans le groupe `:development`.

## 5.2 Configuration par environnement

| Aspect | development | test | production |
|---|---|---|---|
| `enable_reloading` | `true` | `false` | `false` |
| `eager_load` | `false` | `ENV["CI"].present?` | `true` |
| `consider_all_requests_local` | `true` | `true` | `false` |
| `cache_store` | `:memory_store` | `:null_store` | `:solid_cache_store` |
| `perform_caching` | selon `tmp/caching-dev.txt` | — | `true` |
| ActiveJob | défaut (`:async`) | défaut (`:async`) | `:solid_queue` |
| Action Cable | `async` | `test` | `solid_cable` |
| Active Storage | `:local` | `:test` | **`:local`** |
| Base | `lnclassapp_development`, user/pass `dev-rails` **codés en dur** | `app_lnclassapp_test`, mêmes identifiants | `ENV["DATABASE_URL"]` + `DATABASE_NAME`/`USERNAME`/`PASSWORD`/`PORT` |
| Logs | fichier ; `verbose_query_logs`, `query_log_tags_enabled`, `verbose_enqueue_logs`, `verbose_redirect_logs` | stderr | STDOUT taggé `request_id`, niveau `ENV["RAILS_LOG_LEVEL"]` (défaut `info`) |
| Mailer host | `localhost:3000` | `example.com` | **`example.com`** (valeur du générateur) |
| SMTP | — | `delivery_method :test` | **entièrement commenté** |
| `raise_on_missing_callback_actions` | `true` | `true` | — |
| `annotate_rendered_view_with_filenames` | `true` | commenté | — |
| `migration_error` | `:page_load` | — | — |
| `dump_schema_after_migration` | — | — | `false` |
| `attributes_for_inspect` | — | — | `[:id]` |
| `i18n.fallbacks` | — | — | `true` |
| `silence_healthcheck_path` | — | — | `"/up"` (**route inexistante**) |
| SSL | — | — | `assume_ssl`, `force_ssl`, `ssl_options` **tous commentés** |
| `config.hosts` | — | — | **commenté** — pas de protection DNS rebinding |
| `allow_forgery_protection` | — | `false` | — |

Points saillants :

- `config/environments/production.rb:20` garde `config.active_storage.service = :local` : les fichiers téléversés (avatars, `image_cover` de cours/essentiels/messages, `message_audio`) sont écrits sur le disque du conteneur Railway et disparaissent à chaque déploiement. `config/storage.yml` ne définit que `test` et `local` ; les blocs `amazon`, `google`, `mirror` sont commentés.
- `config/database.yml` contient un bloc `db_config` avec `username: dev-rails` / `password: dev-rails` en clair, partagé par `development` et `test`. Le fichier apparaît modifié dans `git status`.
- `config/database.yml` déclare pour `production` à la fois `url: ENV["DATABASE_URL"]` **et** les quatre variables `DATABASE_*` : les deux mécanismes coexistent.
- `config/initializers/content_security_policy.rb` est **entièrement commenté** : aucune CSP n'est appliquée, alors que la page charge du JS tiers (jsdelivr, Google Tag Manager, Microsoft Clarity) et des polices Google.
- `config/initializers/filter_parameter_logging.rb` filtre 12 motifs : `:passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc`. **`:contact` n'y est pas** — or `contact` est le numéro de téléphone servant d'identifiant de connexion (ADR-0002) : il apparaît en clair dans les logs.

## 5.3 Déploiement : GitHub → Railway

Arbitré par `docs/decisions/adr/0010-stack-ops-solid-suite-postgresql-railway.md`
(encadré du 2026-09-18) et `docs/guide/stack.md:199-205`.

**Push sur la branche principale → webhook Railway → build de l'image et mise en
ligne.** Aucune commande de déploiement à lancer à la main.

**Kamal n'est PAS utilisé.** La gem `kamal` reste au `Gemfile` sans rôle
opérationnel, de même que `bin/kamal`, `config/deploy.yml` et `.kamal/`.

Ce qui sert réellement :

| Artefact | Rôle |
|---|---|
| `Dockerfile` (3,3 Ko) | Base de l'image construite par Railway. Multi-stage : `ruby:3.4.9-slim` → stage `build` (build-essential, libpq-dev, libvips, node-build 24.13.1, yarn 4.5.3) → stage final. `bundle install` + `yarn install --immutable` + `bootsnap precompile` ×2 + `assets:precompile` avec `SECRET_KEY_BASE_DUMMY=1`. `rm -rf node_modules` avant le stage final. Utilisateur non-root `rails` (uid/gid 1000). `EXPOSE 80`. `CMD ["./bin/thrust", "./bin/rails", "server"]` |
| `bin/docker-entrypoint` | Exécute `./bin/rails db:prepare` avant le serveur — les migrations tournent au boot de **chaque** conteneur |
| `bin/jobs` | Worker Solid Queue (`SolidQueue::Cli`) — nécessite un second service Railway, ou `SOLID_QUEUE_IN_PUMA=1` |
| `bin/thrust` | Proxy Thruster (compression, X-Sendfile, cache HTTP) |
| `.dockerignore` (874 o) | Exclusions du contexte de build |

**Aucun fichier de configuration Railway dans le dépôt** : pas de `railway.json`,
`railway.toml`, `nixpacks.toml`, ni `Procfile` de production. Seul `Procfile.dev`
existe (`web` / `js` / `css` pour `foreman`, via `bin/dev`). Toute la configuration
Railway — services, variables, healthcheck, commande de démarrage — vit dans
l'interface du PaaS et **n'est pas versionnée**.

Conséquence directe : `config.silence_healthcheck_path = "/up"` est déclaré alors
qu'aucune route `/up` n'existe dans `config/routes.rb`.

## 5.4 Variables d'environnement et secrets attendus

Relevé exhaustif par balayage de `app/`, `lib/`, `config/`, `bin/`, `Dockerfile`,
`Procfile.dev`.

| Variable | Lieu | Rôle | Défaut |
|---|---|---|---|
| `DATABASE_URL` | `config/database.yml` (production) | Connexion PostgreSQL — fournie par Railway | — |
| `DATABASE_NAME` | `config/database.yml` | Redondante avec `DATABASE_URL` | — |
| `DATABASE_USERNAME` | `config/database.yml` | Idem | — |
| `DATABASE_PASSWORD` | `config/database.yml` | Idem | — |
| `DATABASE_PORT` | `config/database.yml` | Idem | — |
| `RAILS_MAX_THREADS` | `config/puma.rb:29`, `config/database.yml` (`max_connections`) | Threads Puma / pool AR | 3 / 5 |
| `PORT` | `config/puma.rb:32`, `bin/dev` | Port d'écoute — imposé par Railway | 3000 |
| `WEB_CONCURRENCY` | `config/puma.rb` (commentaire) | Workers Puma — **non lue activement** | — |
| `JOB_CONCURRENCY` | `config/queue.yml` | Processus Solid Queue | 1 |
| `SOLID_QUEUE_IN_PUMA` | `config/puma.rb:39` | Active le superviseur dans Puma | absente |
| `RAILS_LOG_LEVEL` | `config/environments/production.rb:44` | Niveau de log | `info` |
| `PIDFILE` | `config/puma.rb:42` | Fichier PID, optionnel | — |
| `RAILS_ENV` | `Dockerfile` | `production` dans l'image | — |
| `RAILS_MASTER_KEY` | `Dockerfile` (commentaire), `config/master.key` | Déchiffre `credentials.yml.enc` | — |
| `SECRET_KEY_BASE_DUMMY` | `Dockerfile` | Contourne la clé au `assets:precompile` | — |
| `BUNDLE_DEPLOYMENT`, `BUNDLE_PATH`, `BUNDLE_WITHOUT`, `LD_PRELOAD` | `Dockerfile` | Bundler + jemalloc | — |
| `CI` | `config/environments/test.rb:14` | Force l'eager load | — |
| `RUBOCOP_CACHE_ROOT` | `.github/workflows/ci.yml` | Cache RuboCop | — |
| `STRIX_LLM`, `LLM_API_KEY` | `.github/workflows/security.yml` | Secrets GitHub du scan Strix | — |

**Credentials chiffrés** — `config/credentials.yml.enc` (808 o) contient
**deux clés seulement** : `:secret_key_base` et `:strix`.

`config/master.key` est présent sur le disque et exclu par `.gitignore`
(`/config/*.key`). `.env*` est également ignoré, mais aucun fichier `.env` n'existe.

**Aucune variable n'est prévue** pour SMTP, pour un stockage objet (S3/GCS), ni
pour les identifiants analytiques — ces derniers sont codés en dur (voir §6).

## 5.5 Les assets : Propshaft + esbuild + cssbundling

| Élément | Détail |
|---|---|
| Pipeline | `propshaft` (pas de Sprockets) |
| JS | `yarn build` = `esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets` |
| CSS | `yarn build:css` = `npx @tailwindcss/cli -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify` |
| Dépendances npm | `@hotwired/stimulus ^3.2.2`, `@hotwired/turbo-rails ^8.0.23`, `@rails/actiontext ^7.2.302`, `@tailwindcss/cli ^4.3.3`, `tailwindcss ^4.3.3`, `canvas-confetti ^1.9.4`, `trix ^2.1.19` |
| devDependency | `esbuild ^0.28.2` (unique) |
| Feuille source | `app/assets/stylesheets/application.tailwind.css` — 254 lignes, bloc `@theme` CSS-first conforme à Tailwind v4 (tokens `--font-display`, `--font-body`, `--color-primary`, `--color-primary-50/100/200/hover`, `--color-secondary`, `--color-success`), import Google Fonts (Inter, Montserrat) **depuis un CDN externe**, import de `actiontext.css` |
| Sorties | `app/assets/builds/application.css` (188 Ko), `application.js` (622 Ko), `application.js.map` (1,3 Mo) |
| Versionnement | `.gitignore` exclut `/app/assets/builds/*` sauf `.keep` — confirmé par `git ls-files` |
| Images | `app/assets/images/` — 5 `.png`, 5 `.jpg`, 3 `.svg` (logos, fonds, illustrations de rôle) |
| JS applicatif | `app/javascript/application.js` (entrée) + `app/javascript/controllers/` : 31 contrôleurs Stimulus, tous enregistrés dans `index.js`, **aucun fichier orphelin ni enregistrement sans fichier** |

**KaTeX est chargé depuis un CDN, pas depuis le bundle** :
`app/views/layouts/application.html.erb:42-44` insère trois balises vers
`cdn.jsdelivr.net/npm/katex@0.16.21` (CSS, JS, auto-render).
`app/javascript/application.js:24` appelle `renderMathInElement` sur `turbo:load`
en vérifiant son existence. Ni la gem `katex` ni le paquet npm ne sont déclarés.

`config/initializers/assets.rb` définit `config.assets.version = "1.0"` — directive
Sprockets, sans effet sous Propshaft.

## 5.6 Qualité, hooks et CI

| Élément | Contenu |
|---|---|
| `.github/workflows/ci.yml` (6,2 Ko) | Chaîne à 3 étages : `purity` + `scan_ruby` + `lint` → `test` → `system-test`. La pureté du domaine est vérifiée par `ruby -Itest test/domain/domain_purity_test.rb`, hors Rails et hors base. Le job `lint` refuse tout `# :nocov:` dans `app/` et `lib/` (ADR-0024). Le job `system-test` refuse de passer si `test/system/` est vide. PostgreSQL en service pour les deux derniers étages, `DATABASE_URL: postgres://postgres:postgres@localhost:5432`. Artefacts : rapport de couverture, captures d'écran des échecs |
| `.github/workflows/hitl_audit.yml` (1,5 Ko) | `bin/validate_hitl --base origin/<base>` (bloquant) + `--all --report` (informatif) + `find app -name "*.rb" \| xargs ruby -c` (anti-régression syntaxique). `fetch-depth: 0` |
| `.github/workflows/security.yml` (985 o) | Scan Strix sur chaque PR (`--scan-mode quick --max-budget 10`), échec si le statut du run n'est pas `completed`, upload SARIF via `github/codeql-action/upload-sarif@v3` |
| `.github/dependabot.yml` | 247 o |
| `.github/PULL_REQUEST_TEMPLATE.md` | 2,5 Ko |
| `config/ci.rb` + `bin/ci` | Reproduction locale via `ActiveSupport::ContinuousIntegration`, 10 étapes. **Deux étapes sont locales seulement**, absentes de la CI GitHub : `yarn audit` et `env RAILS_ENV=test bin/rails db:seed:replant` |
| `bin/setup` | Idempotent : `bundle check \|\| bundle install`, `yarn install`, `git config core.hooksPath .githooks`, `db:prepare`, `log:clear tmp:clear`, puis `exec bin/dev` sauf `--skip-server`. Les hooks ne sont actifs qu'après son exécution |
| `.githooks/` | Pre-commit (contournable par `SKIP_HOOKS=1`, d'où le filet CI) |
| `.rubocop.yml` / `.rubocop_todo.yml` | Hérite de `rubocop-rails-omakase` ; le todo fait 84 octets |
| `bin/validate_hitl` (5,8 Ko) | Vérifie l'en-tête HITL 3 lignes en tête de chaque fichier de `app/` |
| SimpleCov | Seuil appliqué depuis `test/test_helper.rb` (cliquet à 45 % lignes / 29 % branches), rapport dans `coverage/`, non versionné |

Note : le commentaire de `config/ci.rb` affirme « Aucun seuil : décision explicite
du projet » alors que `.github/workflows/ci.yml` documente un cliquet SimpleCov
bloquant à 45 % / 29 %. Les deux fichiers se contredisent.

---

# 6. Ce qui est mort

Liste franche, avec la preuve courte de la mort de chaque élément.

## 6.1 Jobs

| Élément | Preuve |
|---|---|
| `app/jobs/simulate_classroom_exercise_job.rb` | `grep -rn "perform_later\|perform_now" app/ lib/` ne renvoie aucun appel |
| `app/jobs/catalog/generate_school_demo_data_job.rb` | Idem |

## 6.2 Tables

| Élément | Preuve |
|---|---|
| Table `friendly_id_slugs` | Les 2 seuls usages de FriendlyId déclarent `use: :slugged` sans `:history` (`orm/user.rb:31`, `models/concerns/sluggable.rb:20`) ; la table n'est jamais écrite |
| Table `action_text_rich_texts` | Aucun `has_rich_text` dans `app/` |
| Table `level_series` | `Orm::LevelSeries` n'a que 3 références, toutes dans les déclarations d'association ORM |
| Table `teacher_classrooms` | Lue en `joins`, **jamais écrite** — aucun use case ne lie un enseignant à une classe |
| `db/cable_schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb` | Aucune base secondaire n'est déclarée dans `config/database.yml` ; les 14 tables Solid sont dans la base primaire via `20260829235900_create_solid_tables.rb`. Ces trois fichiers ne sont jamais chargés |

## 6.3 Colonnes

| Élément | Preuve |
|---|---|
| `essentials.validated_at` | 0 occurrence du nom dans tout `app/` |
| `essentials.validated_by` | 0 occurrence |
| `exercises.recurrence_rate` | 0 occurrence |
| `question_attempts.answer_data` (jsonb) | 0 occurrence |
| `exercises.source_exam` | 1 occurrence — la déclaration ORM elle-même |
| Les 3 index GIN sur `import_data` | La colonne n'est lue que 2 fois dans tout `app/` ; aucune requête ne filtre dessus |

## 6.4 Routes et actions

| Élément | Preuve |
|---|---|
| `GET /schoolstaff/settings/edit` | L'action `edit` n'existe pas dans `app/controllers/schoolstaff/settings_controller.rb` |
| `catalog/drenas#import_json` | Action publique sans route déclarée |
| Les 10 routes `exam_subjects` (students, teachers, teams) | `Orm::ExamSubject` inexistant → `NameError` à l'exécution |
| `GET /teams/examens/new` | Aucune action `create` n'est routée — le formulaire n'a pas de cible |
| `skip_before_action :authenticate_user!` (×2, contrôleurs API) | Aucun `before_action :authenticate_user!` dans `ApplicationController` — no-op neutralisé par `raise: false` |
| Les 6 routes `action_mailbox/ingresses/*` | Aucune classe de boîte de réception dans le projet |

## 6.5 Fichiers, classes et vues

| Élément | Preuve |
|---|---|
| `app/views/schools/` | Répertoire **vide** — les vues des établissements sont dans `app/views/catalog/schools/` |
| `app/views/layouts/shared/analytics/_analytics_script.html.erb` | 0 référence ; seul `_analytics.html.erb` est rendu (`layouts/application.html.erb:52`) |
| `app/helpers/exam_subjects_helper.rb` | Module **vide** — 0 méthode |
| `app/javascript/controllers/hello_controller.js` | Contrôleur du générateur ; `data-controller="hello"` absent des 315 vues |
| `app/javascript/controllers/homepage_teacher_modal_controller.js` | 0 vue le référence, alors que son pendant `homepage-student-modal` est utilisé |
| `app/views/community_validations/_card.html.erb`, `_success.html.erb` | Rendus par 4 vues (`components/_exercise_card.html.erb:75`, `catalog/essentials/show.html.erb:66`, `assessment/exercises/_questions_list.html.erb:8`, `assessment/exercises/show.html.erb:157`), mais aucun contrôleur, route ni use case n'écrit `validated_at`/`validated_by` — la fonctionnalité (ADR-0011) est un décor |

### Méthodes de helpers sans aucun appel (16)

`app/helpers/application_helper.rb` (10 sur 22) : `human_time_ago`,
`status_button_class`, `material_math_icon`, `material_physics_icon`,
`material_svt_icon`, `material_philo_icon`, `material_french_icon`,
`material_history_geo_icon`, `material_edhc_icon`, `default_initial_icon`.

`app/helpers/components_helper.rb` (4 sur 8) : `initialize`, `header?`, `body?`, `footer?`.

`app/helpers/homepage_helper.rb` (1 sur 1) : `material_chip` — le helper entier est mort.

`app/helpers/layout_helper.rb` (1 sur 5) : `hide_layout_components?`.

Preuve : `grep -rlw <méthode> app/views app/controllers` → 0 fichier.

## 6.6 Configuration

| Élément | Preuve |
|---|---|
| Gem `kamal`, `bin/kamal`, `config/deploy.yml`, `.kamal/` (9 `.sample`) | `docs/guide/stack.md:203` : aucun rôle opérationnel. `deploy.yml` contient encore `servers: web: - 192.168.0.1` |
| Gem `jbuilder` | 0 fichier `.jbuilder` dans `app/views` |
| `config/initializers/content_security_policy.rb` | 100 % commenté |
| `config/initializers/inflections.rb` | 100 % commenté |
| `config/initializers/assets.rb` | `config.assets.version` est une directive Sprockets, sans effet sous Propshaft |
| `app/views/pwa/manifest.json.erb` | Contenu du générateur non modifié : `"name": "AppLnclassapp"`, `"description": "AppLnclassapp."`, `"theme_color": "red"`, `"background_color": "red"`, icône `/icon.png` — alors que le layout déclare `theme-color #0066ff` et que les icônes réelles sont dans `app/assets/images/lnclass/` |
| `config.action_mailer.default_url_options = { host: "example.com" }` en production | Valeur du générateur ; combinée à l'absence de SMTP et de mailer, aucun e-mail n'est jamais envoyé |
| `config.silence_healthcheck_path = "/up"` | La route `/up` n'existe pas dans `config/routes.rb` |
| Version `000` dans `schema_migrations` | `bin/rails db:migrate:status` affiche `up 000 ********** NO FILE **********` |
| Commentaire « Aucun seuil » de `config/ci.rb` | Contredit par `test/test_helper.rb:44` : `minimum_coverage line: 45, branch: 29` |

## 6.7 Duplication racine / contexte borné

Les deux familles coexistent et sont **toutes deux référencées** — aucune n'est
morte ; c'est la duplication qui l'est.

### Entités (13 doublons)

À la racine de `app/domain/entities/` : `classroom.rb`, `course.rb`, `drena.rb`,
`essential.rb`, `level.rb`, `material.rb`, `school.rb`, `school_staff.rb`,
`series.rb`, `student.rb`, `teacher.rb`, `team.rb`, `user.rb`.

| Racine | Références | Contexte | Références |
|---|---|---|---|
| `Entities::User` | 41 | `Entities::Identity::User` | 5 |
| `Entities::Classroom` | 22 | `Entities::Identity::Classroom` | 4 |
| `Entities::Level` | 17 | `Entities::Catalog::Level` | 3 |
| `Entities::Material` | 15 | `Entities::Catalog::Material` | 4 |
| `Entities::Series` | 15 | `Entities::Catalog::Series` | 3 |
| `Entities::Essential` | 14 | `Entities::Catalog::Essential` | 2 |
| `Entities::Course` | 12 | `Entities::Catalog::Course` | 3 |
| `Entities::School` | 8 | `Entities::Identity::School` | 6 |
| `Entities::Drena` | 8 | `Entities::Identity::Drena` | 3 |
| `Entities::Student` | 7 | `Entities::Identity::Student` | 1 |
| `Entities::Teacher` | 7 | `Entities::Identity::Teacher` | 1 |
| `Entities::SchoolStaff` | 4 | `Entities::Identity::SchoolStaff` | 2 |
| `Entities::Team` | 3 | `Entities::Identity::Team` | 1 |

Chantier ouvert : `docs/chantiers/catalog-lecture-ecriture-incompatibles/memo.md`,
gravité critique — édition et suppression de cours cassées.

Restent à la racine sans doublon contextualisé : `classroom_assignment.rb`,
`exam_subject.rb`, `knowledge_gap.rb`, `message.rb`, `school_role.rb`.

### Repositories (5 doublons)

À la racine de `app/infrastructure/repositories/` : `catalog_repository.rb` (1 réf),
`knowledge_gap_repository.rb` (4), `school_role_repository.rb` (4),
`school_staff_repository.rb` (4), `user_repository.rb` (3).

### Ports (11 doublons)

À la racine de `app/domain/ports/` : `catalog_repository_port.rb` (3 réfs),
`classroom_assignment_repository_port.rb` (6), `classroom_repository_port.rb` (8),
`exam_repository_port.rb` (3), `knowledge_gap_repository_port.rb` (2),
`school_repository_port.rb` (4), `student_repository_port.rb` (4),
`teacher_repository_port.rb` (4), `user_repository_port.rb` (8), plus deux
**mal nommés, sans suffixe `_port`** : `school_role_repository.rb` (3) et
`school_staff_repository.rb` (3).

### La béquille

`config/initializers/repositories_aliases.rb` maintient **13 alias de constantes**
dans un bloc `to_prepare` pour faire cohabiter les deux nommages
(`Repositories::SchoolRepository = Repositories::Catalog::SchoolRepository`, etc.).
C'est ce fichier qui rend la duplication invisible à l'exécution.

Chantier ouvert : `docs/chantiers/dette-contrats-ports-et-injection/memo.md`.

## 6.8 Défauts transverses non couverts par les chantiers ouverts

| Constat | Emplacement |
|---|---|
| **Identifiants analytiques codés en dur** : Google Tag Manager `GTM-N8FK5T78` et Microsoft Clarity `fhs9um41ic`. Chargés si `Rails.env.production?`, sans variable d'environnement, sans consentement, sans CSP | `app/views/layouts/shared/analytics/_analytics.html.erb`, `_analytics_script.html.erb` |
| **Identifiants PostgreSQL de développement en clair** (`username: dev-rails`, `password: dev-rails`) — fichier modifié dans `git status` | `config/database.yml` |
| **`contact` absent de `filter_parameters`** alors qu'il est l'identifiant de connexion : le numéro de téléphone apparaît en clair dans les logs | `config/initializers/filter_parameter_logging.rb` |
| **Rôle `parent` déclaré sans support** : `ROLES = %i[student teacher team school_admin parent]` — ni table, ni entité persistée, ni route. Couvert par `docs/chantiers/acteurs-fantomes-parent-examsubject/` | `app/controllers/concerns/current_user_concern.rb:15` |
| **`creator?` appelle `admin?`**, méthode jamais définie — `ROLES` contient `school_admin`, pas `admin`. Ne lève que si `teacher?` et `team?` sont tous deux faux | `app/controllers/concerns/current_user_concern.rb:52` |
| **`after_sign_in_path_for(resource)`** est une signature Devise, alors que l'authentification est native (ADR-0002, `identity/sessions_controller`) — vestige à vérifier | `app/controllers/application_controller.rb:18` |
| **En-tête HITL périmé** : annonce `Orm::ClassroomCourse, Orm::ClassroomEssential, Orm::ClassroomExercise`, trois constantes disparues | `app/infrastructure/repositories/classroom/classroom_assignment_repository.rb:9` |
| **En-têtes HITL citant un titre d'ADR inexistant** : plusieurs contrôleurs Stimulus mentionnent « ADR-0009 (Hotwire, Stimulus & KaTeX) » alors que l'ADR-0009 s'intitule « stack frontend vanilla CSS / Tailwind / Hotwire ». Chantier : `docs/chantiers/hitl-refs-adr-obsoletes/` | `app/javascript/controllers/*.js` |
| **Stub de pagination laissé en place** : `@pagy = OpenStruct.new(next: nil) # Stub pagination` | `app/controllers/catalog/courses_controller.rb:51` |
| **`Entities::Message` reçoit des objets ActiveRecord** — violation de la règle d'or « zéro couplage ». Chantier : `docs/chantiers/message-repository-fuite-activerecord/` | `app/infrastructure/repositories/communication/message_repository.rb:74-76` |

---

# Annexe — Chantiers de bugs déjà ouverts

Huit chantiers documentés dans `docs/chantiers/`, tous ouverts le 2026-09-18.
Leurs diagnostics n'ont pas été refaits ici.

| Chantier | Type | Gravité |
|---|---|---|
| `queries-constantes-orm-disparues` | bugfix | 🔴🔴 Bloquant — aucun élève ni enseignant ne peut se connecter ; seul le rôle `team` a un espace fonctionnel |
| `catalog-lecture-ecriture-incompatibles` | bugfix | 🔴 Critique — édition et suppression de cours cassées |
| `classroom-assignment-belongs-to-casses` | bugfix | 🟠 Haute — 3 méthodes de repository lèvent dès qu'une assignation existe |
| `message-repository-fuite-activerecord` | refactoring | 🟠 Haute — violation de la règle d'or « zéro couplage » |
| `acteurs-fantomes-parent-examsubject` | bugfix défensif | 🟡 Moyenne — décision produit rendue : `Parent` et `ExamSubject` reportés, pas abandonnés |
| `classroom-code-adhesion-trop-long` | bugfix | 🟡 Moyenne — `SecureRandom.alphanumeric(6)` contre `limit: 5` |
| `dette-contrats-ports-et-injection` | refactoring | 🟡 Moyenne — dette structurelle |
| `hitl-refs-adr-obsoletes` | refactoring | 🟢 Faible — mécanique, 3 cas ambigus |
