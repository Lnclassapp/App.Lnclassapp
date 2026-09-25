# Plan d'exécution — Boucle pédagogique (V1)

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Règles de collision : [`boucle-de-travail.md`](../refonte-application/boucle-de-travail.md) §6.
> Specs : [`prd.md`](prd.md). Cadrage : [`memo.md`](memo.md).

**Conventions de lecture de ce plan**

- **Un chemin du nouveau dépôt n'apparaît qu'une fois** avant la section « Vérification de collision ». C'est ce qui rend la commande de vérification probante. Les autres mentions d'un fichier passent par le nom de sa classe (`Result`, `Ports::Classroom::AssignmentRepositoryPort`…).
- Les écrans de l'**ancienne application** (lecture seule, `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp`) sont notés `⟨ancienne⟩ views/…` ou `⟨ancienne⟩ javascript/…`. Ces chemins sont relatifs à son répertoire `app/`. On les **lit** pour reproduire les parcours et la mise en page. On ne recopie jamais leur code.
- Les fiches d'inventaire sont dans [`refonte-application/inventaire/`](../refonte-application/inventaire/). On les cherche par leur ID (`grep -n "CL-09" inventaire/*.md`).
- Le design est **mixte** :
  - **les écrans et les parcours** viennent de l'ancienne application ;
  - **les tokens** viennent de la nouvelle landing (UDR-0005) ;
  - **les composants** `ui_*` et **le shell** `layout "shell"` viennent du Lot 0c (UDR-0006).
- Aucun lot n'écrit de classe CSS arbitraire (`[…]`) ni de couleur `#hex` dans une vue.
- Chaque lot écrit **l'UDR de ses écrans** sous le numéro réservé ci-dessous, dans `docs/decisions/udr/`. L'**orchestrateur** l'indexe dans le README des UDR au merge : c'est le seul à écrire dans ce fichier.

## Graphe

```
                 Lot 0c (design, livré par un autre agent : composants + shell)
                   │
Lot 0 — SOCLE (orchestrateur, séquentiel : 0.1 → 0.10)
  │   schéma complet · Orm · domaine (Result, entités, ports, policies, DTO)
  │   repositories · seeds · routes V1 complètes · auth 0b · shell branché
  │
  ├─ Vague 1 : 21 lots en parallèle ─────────────────────────────────────────┐
  │                                                                          │
  │  A — Élève         B — Contenu & équipe          C — Évaluation          │
  │  ├─► A1 inscription├─► B1 catalogue + cours      ├─► C1 détail exercice  │
  │  ├─► A2 accueil    ├─► B2 gestion cours          ├─► C2 jouer session    │
  │  ├─► A3 ma classe  ├─► B3 fiche + progression    └─► C3 résultat + badge │
  │  └─► A4 landing    ├─► B4 gestion fiches                                 │
  │                    ├─► B5 gestion exercices      D — Enseignant & classe │
  │                    ├─► B6 accueil équipe         ├─► D1 inscription ens. │
  │                    ├─► B7 invitation équipe      ├─► D2 déclarer classes │
  │                    └─► B8 débloquer un compte    ├─► D3 accueil ens.     │
  │                                                  ├─► D4 page classe      │
  │                                                  ├─► D5 assignation ─────┼─┐
  │                                                  └─► D8 créer une classe │ │
  ├──────────────────────────────────────────────────────────────────────────┘ │
  │                                                                            │
  ├─ Vague 2 : D6 fiche dans la classe  ◄── D5                                 │
  │            D7 assigner depuis le cours ◄── D5 ─────────────────────────────┘
  │
  └─ Vague 3 : Lot E — preuve bout en bout (Chrome headless) ◄── tous les lots
```

**25 lots** : Lot 0, puis 23 lots verticaux, puis le Lot E. Les lots verticaux ne dépendent que du Lot 0, sauf D6 et D7 qui dépendent de D5 : ils réutilisent son partial de bascule d'assignation.

### Pourquoi le Lot 0 est plus gros que « des routes vides »

Trois familles de fichiers seraient partagées par plusieurs lots verticaux. Le Lot 0 les écrit une fois pour toutes, et les lots n'y touchent plus.

1. **Les routes.**
   - Plusieurs lots écrivent dans un même contexte : 4 dans `catalog`, 8 dans `classroom`. Un fichier de routes vide par contexte les mettrait donc en collision.
   - Le Lot 0 dessine **toutes** les routes V1. Une route qui pointe vers un contrôleur pas encore écrit ne casse rien tant qu'on ne l'appelle pas.
   - Le shell du Lot 0c exige déjà les noms de route `student_home_path`, `teacher_home_path`, etc. Sans eux, ses entrées de navigation restent inactives.
2. **Les repositories.** Un même port sert plusieurs lots. Par exemple, `AssignmentRepositoryPort` sert A2, C2, D5 et D6. Chaque repository est donc écrit au Lot 0, avec son test de contrat. Les lots n'écrivent que leurs **use cases**, leurs **queries** (lecture, une par écran), leurs contrôleurs et leurs vues.
3. **Les fabriques de test.** Deux lots d'un même contexte se disputeraient `test/support/factories/<ctx>.rb`. Le Lot 0 les écrit **complètes**, pour toutes les tables. Un lot qui a besoin d'un assemblage particulier l'écrit dans son propre fichier de test.

Les contrôleurs Stimulus sont chargés **par motif de fichier** (`esbuild-rails`). Il n'y a donc pas de manifeste `index.js` à éditer. Un lot qui dépose `app/javascript/controllers/<ctx>/<nom>_controller.js` est enregistré sous l'identifiant `<ctx>--<nom>`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + delivery (authentification, shell) + seeds
- **Fichiers**     : tous les chemins des tableaux 0.1 à 0.10 ci-dessous, colonne « Fichier ». La liste est exhaustive.
- **Dépend de**    : V0 mergée (garde-fous, CI, `/up`) et Lot 0c mergé (composants `ui_*`, `layout "shell"`, `NavigationHelper`, `ComponentsHelper`, toasts).
- **Test associé** : colonne « Test » des tableaux 0.1 à 0.10. Il y a en plus les tests d'architecture de 0.10.
- **Done quand**   :
  - `bin/rails db:prepare db:seed` passe deux fois de suite sans erreur ;
  - un élève, un enseignant et un membre de l'équipe seedés en développement se connectent, un membre de l'équipe passant son TOTP, et chacun arrive sur son accueil. Chaque accueil peut encore répondre 404 tant que son lot n'est pas mergé ;
  - `bin/ci` est vert ;
  - les ports sont **gelés** : toute modification ultérieure d'un port passe par l'orchestrateur, jamais par un lot vertical.
- **Exécution**    : l'orchestrateur code, un commit par sous-étape (`feat(<ctx>): …`), dans l'ordre 0.1 → 0.10. Il le fait sur `feature/boucle-pedagogique`, avant de créer la moindre branche de lot.
- **UDR**          : UDR-0008 couvre les écrans connexion, second facteur, récupération du PIN et écrans de sortie.

### 0.1 Dépendances et configuration

| Fichier | Contenu | Test |
|---|---|---|
| `Gemfile` · `Gemfile.lock` | Décommenter `bcrypt ~> 3.1.7`. Ajouter `rotp ~> 6.3` (TOTP) et `rqrcode ~> 2.2` (QR d'enrôlement, rendu SVG). Aucune autre gemme. | `bin/bundler-audit` vert |
| `package.json` · `yarn.lock` | Ajouter `katex` (dépendance, dans le bundle, pas de CDN : TR-41) et `esbuild-rails` (dev). Le script `build` devient `node esbuild.config.mjs`. | `yarn build` vert |
| `esbuild.config.mjs` | Point d'entrée `app/javascript/application.js`, plugin `rails()` de `esbuild-rails` pour les imports par motif, sortie `app/assets/builds`, `--minify` en production | — |
| `app/javascript/controllers/index.js` | Remplace le manifeste généré : `import controllers from "./**/*_controller.js"`, puis `controllers.forEach(c => application.register(c.name, c.module.default))`. Identifiant d'un fichier en sous-dossier : `<dossier>--<nom>`. | `test/javascript_bundle_test.rb` : le bundle compilé contient l'identifiant `math` et aucune URL `cdn.` |
| `app/javascript/controllers/math_controller.js` | Rendu KaTeX (`renderMathInElement` de `katex/contrib/auto-render`) des délimiteurs `$…$` et `$$…$$` dans l'élément porteur de `data-controller="math"`. Sert à B1, B3, C1, C2 et C3. | couvert par les tests système des lots |
| `app/assets/stylesheets/application.tailwind.css` | **Une ligne** ajoutée au fichier du Lot 0c : `@import "katex/dist/katex.min.css";`. Rien d'autre n'y est modifié. | — |
| `config/application.rb` | `config.i18n.default_locale = :fr`, `available_locales = [:fr]`, `load_path += Dir[Rails.root.join("config/locales/**/*.yml")]`, `time_zone = "Africa/Abidjan"`. | — |
| `config/environments/test.rb` | `config.cache_store = :memory_store` (nécessaire à `rate_limit`), `config.i18n.raise_on_missing_translations = true`, `config.action_controller.perform_caching = false`. Le helper de 0.9 l'active par test. | — |
| `config/environments/development.rb` | `config.i18n.raise_on_missing_translations = true` | — |
| `config/initializers/filter_parameter_logging.rb` | Ajouter `:pin, :new_pin, :code, :otp, :backup_code, :token, :join_code`. | `test/initializers/filter_parameter_logging_test.rb` |
| `config/credentials.yml.enc` | Ajouter les clés `active_record_encryption` (`bin/rails db:encryption:init`), nécessaires à `encrypts :otp_secret`. La clé maître de production est fournie par le porteur. | — |

### 0.2 Migrations

Horodatage `20260925100001` → `20260925100029`, dans cet ordre. **Règles communes** :

- clés `bigint` ;
- `timestamps null: false` sauf mention contraire ;
- toutes les FK en `on_delete: :restrict`. **Aucune cascade** (ADR-0036). Seule exception : `user_sessions`, en `cascade` ;
- énumérations en `string` avec contrainte `CHECK`, jamais en `integer` ;
- `public_id` : `string(16) null: false`, index unique. La valeur est un `SecureRandom.base58(16)` généré par le modèle `Orm::`, sans préfixe (ADR-0029) ;
- slug : `string null: false`, index unique global, généré par `friendly_id` (`use: :slugged`) à la création, puis **jamais régénéré**.

**`db/migrate/20260925100001_create_users.rb`** — `users`

| Colonne | Type | Null | Défaut | Note |
|---|---|---|---|---|
| `public_id` | string(16) | non | — | unique |
| `last_name` | string(60) | non | — | « Nom », ADR-0037 |
| `first_names` | string(90) | non | — | « Prénom(s) » |
| `contact` | string(10) | non | — | unique ; `CHECK (contact ~ '^(01\|05\|07)[0-9]{8}$')` |
| `gender` | string | non | — | `CHECK (gender IN ('male','female'))` |
| `role` | string | non | — | `CHECK (role IN ('student','teacher','team'))` ; index |
| `password_digest` | string | non | — | bcrypt du PIN |

**`db/migrate/20260925100002_create_drenas.rb`** — `drenas`
- `name` string(50), non null, unique.
- Aucun `team_id`, aucun slug.

**`db/migrate/20260925100003_create_schools.rb`** — `schools`
- `drena_id` : FK, non null, index.
- `public_id` : unique.
- `name` string(150), non null.
- `short_name` string(10), nullable.
- `sector` string, non null, `CHECK IN ('public','private','mixed')`.
- `status` string, non null, défaut `'active'`, `CHECK IN ('draft','active','inactive')`.
- Unique `(drena_id, name)`.

**`db/migrate/20260925100004_create_levels.rb`** — `levels`
- `name` string(20), non null, unique.
- `position` integer, non null, unique.
- `cycle` string, non null, `CHECK IN ('first','second')`.

**`db/migrate/20260925100005_create_series.rb`** — `series`
- `name` string(5), non null, unique.

**`db/migrate/20260925100006_create_level_series.rb`** — `level_series`
- `level_id` et `series_id` : FK, non null.
- Unique `(level_id, series_id)`, index `series_id`.

**`db/migrate/20260925100007_create_materials.rb`** — `materials`
- `name` string(40), non null, unique.
- `short_name` string(10), non null, unique.
- `category` string, non null, `CHECK IN ('literature','science','other')`.
- `icon` string(40), non null, défaut `'book-open'` : nom d'heroicon, CA-26.

**`db/migrate/20260925100008_create_students.rb`** — `students`
- `user_id` : FK, non null, **unique** (sécurité n° 15).

**`db/migrate/20260925100009_create_teachers.rb`** — `teachers`
- `user_id` : FK, non null, unique.
- `material_id` : FK, non null, index.
- `onboarded_at` datetime, nullable : état persisté de l'onboarding, qui remplace TR-08.

**`db/migrate/20260925100010_create_teams.rb`** — `teams`
- `user_id` : FK, non null, unique.
- `otp_secret` string, nullable, chiffré par `encrypts` côté Orm. Les clés Active Record Encryption vont dans les credentials, voir 0.1 Risques.
- `otp_enabled_at` datetime, nullable.
- `otp_last_used_step` bigint, nullable : anti-rejeu.

**`db/migrate/20260925100011_create_teacher_schools.rb`** — `teacher_schools`
- `teacher_id` et `school_id` : FK, non null.
- `primary` boolean, non null, défaut `false`.
- Unique `(teacher_id, school_id)`.
- **Unique partiel** `(teacher_id) WHERE primary` (ADR-0030).
- Index `school_id`.

**`db/migrate/20260925100012_create_classrooms.rb`** — `classrooms`
- `school_id` et `level_id` : FK, non null.
- `series_id` : FK, nullable.
- `public_id` : unique.
- `name` string(15), non null. Unique `(school_id, name)`.
- `join_code` string(5), non null, unique, `CHECK (join_code ~ '^[a-hj-np-z]{3}[2-9]{2}$')`. La longueur de la colonne égale celle du code généré, et le CHECK impose les minuscules. Ce test de schéma ferme le chantier `classroom-code-adhesion-trop-long`.

**`db/migrate/20260925100013_create_classroom_students.rb`** — `classroom_students`
- `classroom_id` et `student_id` : FK, non null.
- `primary` boolean, non null, défaut `false`.
- `joined_at` datetime, non null.
- Unique `(student_id, classroom_id)`.
- **Unique partiel** `(student_id) WHERE primary`.
- Index `classroom_id`.

**`db/migrate/20260925100014_create_teacher_classrooms.rb`** — `teacher_classrooms`
- `teacher_id` et `classroom_id` : FK, non null.
- Unique `(teacher_id, classroom_id)`, index `classroom_id`.

**`db/migrate/20260925100015_create_courses.rb`** — `courses`
- `level_id` et `material_id` : FK, non null.
- `series_id` : FK, nullable.
- `author_id` : FK vers `users`, non null.
- `name` string(200), non null. Unique `(material_id, level_id, name)`.
- `slug` : unique.
- `subtitle` string(150), nullable.
- `status` string, non null, défaut `'draft'`, `CHECK IN ('draft','published','archived')`.
- `published_at` et `archived_at` datetime, nullables.
- `CHECK (status <> 'published' OR published_at IS NOT NULL)`.
- Index `(status, level_id)`.
- Le contenu est un rich text Action Text `content`, dont la table existe déjà.

**`db/migrate/20260925100016_create_essentials.rb`** — `essentials`
- `course_id` : FK, non null.
- `author_id` : FK vers `users`, non null.
- `name` string(150), non null.
- `slug` : unique global.
- `subtitle` string(150).
- `position` integer, non null.
- `status`, `published_at`, `archived_at` : comme `courses`.
- Unique `(course_id, name)` et `(course_id, position)`.
- Rich text `content`.

**`db/migrate/20260925100017_create_exercises.rb`** — `exercises`
- `essential_id` : FK, **non null** (ADR-0054).
- `author_id` : FK vers `users`, non null.
- `title` string(200), non null.
- `description` text.
- `slug` : unique global.
- `kind` string, non null, défaut `'fixation'`, `CHECK IN ('fixation','evaluation')`.
- `position` integer, non null.
- `status`, `published_at`, `archived_at` : comme `courses`.
- Unique `(essential_id, position)`.

**`db/migrate/20260925100018_create_questions.rb`** — `questions`
- `exercise_id` : FK, non null.
- `position` integer, non null.
- `content` text, non null.
- `explanation` text.
- `question_type` string, non null, `CHECK IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3')`.
- Unique `(exercise_id, position)`.

**`db/migrate/20260925100019_create_answers.rb`** — `answers`
- `question_id` : FK, non null.
- `position` integer, non null.
- `content` string(500), non null.
- `correct` boolean, non null, défaut `false`.
- Unique `(question_id, position)`.

**`db/migrate/20260925100020_create_exercise_sessions.rb`** — `exercise_sessions`
- `public_id` : unique.
- `student_id` et `exercise_id` : FK, non null.
- `status` string, non null, défaut `'in_progress'`, `CHECK IN ('in_progress','completed','abandoned')`.
- `questions_total` integer, non null, `CHECK > 0` : figé au démarrage.
- `answered_count` integer, non null, défaut 0 : **avancement** (F-11).
- `correct_count` integer, non null, défaut 0.
- `score_percent` integer, nullable : **score**, renseigné à la clôture.
- `started_at` datetime, non null.
- `completed_at` datetime, nullable.
- `CHECK (status <> 'completed' OR (completed_at IS NOT NULL AND score_percent IS NOT NULL))`.
- **Unique partiel** `(student_id, exercise_id) WHERE status = 'in_progress'`.
- Index `(student_id, completed_at)` et `exercise_id`.

**`db/migrate/20260925100021_create_question_attempts.rb`** — `question_attempts`
- `exercise_session_id` et `question_id` : FK, non null.
- `selected_answer_ids` bigint[], non null, `CHECK (cardinality(selected_answer_ids) > 0)`.
- `correct` boolean, non null.
- `created_at` datetime, non null. **Pas de `updated_at`** : la ligne est immuable.
- **Unique `(exercise_session_id, question_id)`** (sécurité n° 30, ADR-0054).

**`db/migrate/20260925100022_create_exercise_badges.rb`** — `exercise_badges`
- `student_id` et `exercise_id` : FK, non null.
- `exercise_session_id` : FK, non null : la session qui l'a fait gagner.
- `level` string, non null, `CHECK IN ('bronze','silver','gold')`.
- `score_percent` integer, non null.
- `earned_at` datetime, non null.
- Unique `(student_id, exercise_id)`.

**`db/migrate/20260925100023_create_classroom_assignments.rb`** — `classroom_assignments`
- `classroom_id` : FK, non null.
- `assignable_type` string, non null, `CHECK IN ('course','essential','exercise')`. C'est un vocabulaire de domaine, **jamais** un nom de classe `Orm::`.
- `assignable_id` bigint, non null.
- `status` string, non null, défaut `'active'`, `CHECK IN ('active','archived')`.
- `assigned_by_id` : FK vers **`users`**, non null.
- `assigned_at` datetime, non null.
- `archived_at` datetime, nullable.
- Unique `(classroom_id, assignable_type, assignable_id)`.
- Index `(assignable_type, assignable_id, status)`.

**`db/migrate/20260925100024_create_user_sessions.rb`** — `user_sessions`
- `user_id` : FK, non null, `on_delete: :cascade`.
- `token_digest` string(64), non null, unique : SHA-256 du jeton du cookie.
- `ip_address` inet.
- `user_agent` string(255).
- `second_factor_verified_at` datetime, nullable.
- `last_active_at` datetime, non null.
- `expires_at` datetime, non null.
- `created_at` datetime, non null.
- Index `user_id`.

**`db/migrate/20260925100025_create_login_failures.rb`** — `login_failures`
- `contact` string(10), non null. C'est le numéro **normalisé**, même inconnu.
- `ip_address` inet.
- `created_at` datetime, non null.
- Index `(contact, created_at)`.

**`db/migrate/20260925100026_create_audit_events.rb`** — `audit_events`
- `actor_id` : FK vers `users`, **nullable** (tentative anonyme).
- `action` string(60), non null.
- `subject_type` string(40), nullable.
- `subject_id` bigint, nullable.
- `metadata` jsonb, non null, défaut `{}`.
- `ip_address` inet.
- `created_at` datetime, non null.
- Index `(action, created_at)`, `(actor_id, created_at)`, `(subject_type, subject_id)`.

**`db/migrate/20260925100027_create_pin_recovery_codes.rb`** — `pin_recovery_codes`
- `user_id` : FK, non null.
- `issued_by_id` : FK vers `users`, non null.
- `code_digest` string, non null : bcrypt.
- `failed_attempts` integer, non null, défaut 0.
- `expires_at` datetime, non null.
- `used_at` et `revoked_at` datetime, nullables.
- `created_at` datetime, non null.
- Index `(user_id) WHERE used_at IS NULL AND revoked_at IS NULL`.

**`db/migrate/20260925100028_create_team_backup_codes.rb`** — `team_backup_codes`
- `team_id` : FK, non null.
- `code_digest` string, non null : bcrypt.
- `used_at` datetime, nullable.
- `created_at` datetime, non null.
- Index `team_id`.

**`db/migrate/20260925100029_create_team_invitations.rb`** — `team_invitations`
- `invited_by_id` : FK vers `users`, non null.
- `contact` string(10), non null.
- `last_name` string(60) et `first_names` string(90), non null.
- `token_digest` string(64), non null, unique.
- `expires_at` datetime, non null.
- `accepted_at` et `revoked_at` datetime, nullables.
- `accepted_user_id` : FK vers `users`, nullable.
- Unique partiel `(contact) WHERE accepted_at IS NULL AND revoked_at IS NULL`.

| Fichier | Contenu | Test |
|---|---|---|
| `db/schema.rb` | Régénéré après les 29 migrations | `test/db/schema_constraints_test.rb` |

Ce test couvre :
- la longueur de `join_code`, égale à `Entities::Classroom::JoinCode::LENGTH` ;
- chaque index unique et chaque index partiel ci-dessus ;
- l'absence de `on_delete: :cascade` hors de `user_sessions` ;
- l'absence de colonne `updated_at` sur `question_attempts`.

### 0.3 Modèles `Orm::`

Tous les modèles sont dans `app/infrastructure/orm/`. Chacun :
- hérite d'`ApplicationRecord` et déclare `self.table_name` ;
- déclare ses associations avec `class_name: "Orm::…"` et `inverse_of` ;
- porte les validations de **cohérence de schéma**, jamais de règle métier ;
- ne contient **aucun callback métier**. Exception : la génération de `public_id` et du slug.

**Tests.** Les modèles n'ont pas de test propre. Ils sont couverts par les tests de repository (0.5). Seul `Orm::User` a un test : `has_secure_password`, et le PIN absent de `inspect`.

| Fichier | Particularités |
|---|---|
| `app/infrastructure/orm/user.rb` | `has_secure_password`, `has_one :student/:teacher/:team`, `before_validation :assign_public_id, on: :create`, `filter_attributes` pour `password_digest` |
| `app/infrastructure/orm/student.rb` | `belongs_to :user`, `has_many :classroom_students` |
| `app/infrastructure/orm/teacher.rb` | `belongs_to :user, :material`, `has_many :teacher_schools, :teacher_classrooms` |
| `app/infrastructure/orm/team.rb` | `belongs_to :user`, `encrypts :otp_secret`, `has_many :team_backup_codes` |
| `app/infrastructure/orm/team_backup_code.rb` | `belongs_to :team` |
| `app/infrastructure/orm/team_invitation.rb` | `belongs_to :invited_by, class_name: "Orm::User"` |
| `app/infrastructure/orm/user_session.rb` | `belongs_to :user` |
| `app/infrastructure/orm/login_failure.rb` | — |
| `app/infrastructure/orm/audit_event.rb` | `belongs_to :actor, optional: true`, `readonly?` vrai après création |
| `app/infrastructure/orm/pin_recovery_code.rb` | `belongs_to :user`, `belongs_to :issued_by` |
| `app/infrastructure/orm/drena.rb` | `has_many :schools` |
| `app/infrastructure/orm/school.rb` | `belongs_to :drena`, `has_many :classrooms`, `public_id` |
| `app/infrastructure/orm/teacher_school.rb` | `belongs_to :teacher, :school` |
| `app/infrastructure/orm/level.rb` | `has_many :level_series` |
| `app/infrastructure/orm/series.rb` | classe `Orm::Series` (singulier = pluriel, sans inflexion à ajouter) |
| `app/infrastructure/orm/level_series.rb` | classe `Orm::LevelSeries`, `self.table_name = "level_series"` |
| `app/infrastructure/orm/material.rb` | — |
| `app/infrastructure/orm/classroom.rb` | `belongs_to :school, :level`, `belongs_to :series, optional: true`, `public_id`. **Aucune** association polymorphe vers les ressources assignées : c'est la cause du chantier `classroom-assignment-belongs-to-casses`. |
| `app/infrastructure/orm/classroom_student.rb` | `belongs_to :classroom, :student` |
| `app/infrastructure/orm/teacher_classroom.rb` | `belongs_to :teacher, :classroom` |
| `app/infrastructure/orm/classroom_assignment.rb` | `belongs_to :classroom`, `belongs_to :assigned_by, class_name: "Orm::User"` ; `assignable_type` / `assignable_id` sont de simples colonnes |
| `app/infrastructure/orm/course.rb` | `extend FriendlyId`, `friendly_id :name, use: :slugged`, `should_generate_new_friendly_id?` vrai seulement à la création ; `has_rich_text :content` ; `has_many :essentials` |
| `app/infrastructure/orm/essential.rb` | idem, slug construit sur le nom du cours puis celui de la fiche ; `has_rich_text :content` ; `has_many :exercises` |
| `app/infrastructure/orm/exercise.rb` | slug ; `has_many :questions, -> { order(:position) }` |
| `app/infrastructure/orm/question.rb` | `has_many :answers, -> { order(:position) }` |
| `app/infrastructure/orm/answer.rb` | `belongs_to :question` |
| `app/infrastructure/orm/exercise_session.rb` | `public_id` ; `has_many :question_attempts` |
| `app/infrastructure/orm/question_attempt.rb` | `readonly?` vrai si `persisted?` |
| `app/infrastructure/orm/exercise_badge.rb` | `belongs_to :student, :exercise, :exercise_session` |

| Fichier | Test |
|---|---|
| (voir `Orm::User` ci-dessus) | `test/infrastructure/orm/user_test.rb` |

### 0.4 Domaine — `Result`, entités, objets-valeurs

**`Result`** (ADR-0026)

| Fichier | Contenu | Test |
|---|---|---|
| `app/domain/result.rb` | `Result = Data.define(:value, :error, :details)`. Constructeurs `Result.success(value = nil)` et `Result.failure(error, details = {})`. Méthodes `success?` et `failure?`. `error` appartient à `ERRORS = %i[forbidden not_found invalid conflict locked expired].freeze` : un symbole hors liste lève `ArgumentError`. `details` contient les erreurs de champ (`{ field: [messages] }`) ou le contexte d'affichage. Le résultat est immuable. | `test/domain/result_test.rb` |

**Règles communes aux entités.**
- Ruby pur : `Data.define` pour les objets-valeurs, `ActiveModel::Model` + `ActiveModel::Validations` toléré pour les entités validées (ADR-0026, F-03).
- Aucune référence à `Orm::`, `ActiveRecord`, `Repositories::` ni à Rails hors `ActiveModel` et `ActiveSupport`.
- Les constantes métier sont **nommées** dans l'entité qui les porte.

| Fichier | Classe | Attributs et règles | Test |
|---|---|---|---|
| `app/domain/entities/identity/actor.rb` | `Entities::Identity::Actor` (Data) | `user_id, public_id, role, display_name, student_id, teacher_id, team_id, second_factor_verified`. Prédicats `student?`, `teacher?`, `team?`. Un `Actor` team non vérifié n'est **jamais** construit hors du socle d'authentification. | `test/domain/entities/identity/actor_test.rb` |
| `app/domain/entities/identity/user.rb` | `Entities::Identity::User` | `id, public_id, last_name, first_names, contact, gender, role`. `full_name` vaut `"#{first_names} #{last_name}"`, sans aucune transformation de casse (ADR-0037). `ROLES = %w[student teacher team]`, `GENDERS = %w[male female]`. | `test/domain/entities/identity/user_test.rb` |
| `app/domain/entities/identity/contact.rb` | `Entities::Identity::Contact` (Data `value`) | `Contact.normalize(raw)` : garde les chiffres ; si la longueur dépasse 10, retire le préfixe `00225`, puis `225`. `valid?` si `FORMAT = /\A(01\|05\|07)\d{8}\z/`. Message : clé `errors.contact.format` (ID-28). | `test/domain/entities/identity/contact_test.rb` |
| `app/domain/entities/identity/person_name.rb` | `Entities::Identity::PersonName` | `normalize(raw)` : `strip` et espaces multiples réduits à un seul. **Rien d'autre**. `MAX_LAST = 60`, `MAX_FIRST = 90`. | `test/domain/entities/identity/person_name_test.rb` |
| `app/domain/entities/identity/pin.rb` | `Entities::Identity::Pin` | `FORMAT = /\A\d{4}\z/`. `valid_for?(pin, contact:)` est faux si le format est mauvais ou si `pin == contact[-4..]`. Le PIN n'est jamais stocké dans une entité : `inspect` le masque. | `test/domain/entities/identity/pin_test.rb` |
| `app/domain/entities/identity/home_destination.rb` | `Entities::Identity::HomeDestination` | `for(role:, second_factor_verified:, primary_classroom:, primary_school:, onboarded:)` renvoie un symbole. **Student** : `:student_home` s'il a une classe principale, sinon `:student_pending`. **Teacher** : `:teacher_pending` sans école principale, sinon `:teacher_selection` s'il n'est pas configuré, sinon `:teacher_home`. **Team** : `:second_factor` s'il n'est pas vérifié, sinon `:team_home`. Aucune destination ne renvoie vers une page qui la redirige elle-même. | `test/domain/entities/identity/home_destination_test.rb` |
| `app/domain/entities/identity/user_session.rb` | `Entities::Identity::UserSession` | `ABSOLUTE_TTL = { student: 30.days, teacher: 30.days, team: 12.hours }`, `IDLE_TTL = { student: 7.days, teacher: 7.days, team: 1.hour }`. `expired?(now:)`. `TOUCH_EVERY = 5.minutes` : `last_active_at` n'est écrit qu'au-delà de ce délai. **Valeurs proposées, à fixer par l'ADR-0050.** | `test/domain/entities/identity/user_session_test.rb` |
| `app/domain/entities/identity/second_factor.rb` | `Entities::Identity::SecondFactor` | `BACKUP_CODES_COUNT = 10`, `BACKUP_CODE_LENGTH = 10` (alphabet base32 sans 0/1/O/I), `generate_backup_codes`, `DRIFT_BEHIND = 1` pas de 30 s | `test/domain/entities/identity/second_factor_test.rb` |
| `app/domain/entities/identity/pin_recovery_code.rb` | `Entities::Identity::PinRecoveryCode` | `TTL = 15.minutes`, `LENGTH = 6` chiffres, `MAX_FAILED_ATTEMPTS = 5`, `generate`, `usable?(now:)` (non expiré, non utilisé, non révoqué, moins de 5 échecs) | `test/domain/entities/identity/pin_recovery_code_test.rb` |
| `app/domain/entities/identity/team_invitation.rb` | `Entities::Identity::TeamInvitation` | `TTL = 72.hours`, `generate_token` (`SecureRandom.urlsafe_base64(32)`), `digest(token)` (SHA-256 hexadécimal), `acceptable?(now:)` | `test/domain/entities/identity/team_invitation_test.rb` |
| `app/domain/entities/school/drena.rb` | `Entities::School::Drena` (Data) | `id, name` | couvert par le repository |
| `app/domain/entities/school/school.rb` | `Entities::School::School` (Data) | `id, public_id, drena_id, name, short_name, sector, status` | couvert par le repository |
| `app/domain/entities/classroom/join_code.rb` | `Entities::Classroom::JoinCode` | `LETTERS = ("a".."z").to_a - %w[i o]`, `DIGITS = ("2".."9").to_a`, `LENGTH = 5`. `generate` : 3 lettres puis 2 chiffres. `normalize(raw)` : `raw.to_s.gsub(/\s/, "").downcase`. `valid?` s'il correspond au format. `display(code)` : `code.upcase` (CL-04). | `test/domain/entities/classroom/join_code_test.rb` |
| `app/domain/entities/classroom/classroom.rb` | `Entities::Classroom::Classroom` | `id, public_id, school_id, level_id, series_id, name, join_code`. Validations : `name` présent, au plus 15 caractères, normalisé comme un nom de personne. | `test/domain/entities/classroom/classroom_test.rb` |
| `app/domain/entities/classroom/membership.rb` | `Entities::Classroom::Membership` (Data) | `student_id, classroom_id, primary, joined_at` | couvert par le repository |
| `app/domain/entities/classroom/assignable.rb` | `Entities::Classroom::Assignable` (Data `type, id, name`) | `TYPES = %w[course essential exercise]`. Un type hors liste lève `ArgumentError`. | `test/domain/entities/classroom/assignable_test.rb` |
| `app/domain/entities/classroom/assignment.rb` | `Entities::Classroom::Assignment` | `classroom_id, assignable, status, assigned_by_id, assigned_at, archived_at`. `STATUSES = %w[active archived]`. `active?`. `reactivate(by:, at:)` et `archive(at:)` renvoient une nouvelle instance (ADR-0048). | `test/domain/entities/classroom/assignment_test.rb` |
| `app/domain/entities/catalog/content_status.rb` | `Entities::Catalog::ContentStatus` | `VALUES = %w[draft published archived]`. `TRANSITIONS = { "draft" => %w[draft published archived], "published" => %w[published archived], "archived" => %w[archived] }`. `transition(from:, to:)` renvoie un `Result`, en `:invalid` si la transition est interdite. | `test/domain/entities/catalog/content_status_test.rb` |
| `app/domain/entities/catalog/level.rb` | `Entities::Catalog::Level` (Data) | `id, name, position, cycle` | couvert par le repository |
| `app/domain/entities/catalog/series.rb` | `Entities::Catalog::Series` (Data) | `id, name` | couvert par le repository |
| `app/domain/entities/catalog/material.rb` | `Entities::Catalog::Material` (Data) | `id, name, short_name, category, icon`. `CATEGORIES = %w[literature science other]`. | couvert par le repository |
| `app/domain/entities/catalog/course.rb` | `Entities::Catalog::Course` | `id, slug, name, subtitle, level_id, series_id, material_id, author_id, status, published_at, archived_at, content_html`. Validations : `name` présent (200 au plus), `level_id` et `material_id` présents. `publish(at:)` et `archive(at:)` passent par `ContentStatus`. `readable_by_non_team?` vaut `status == "published"`. **Une seule entité** pour la lecture et l'écriture (chantier `catalog-lecture-ecriture-incompatibles`). | `test/domain/entities/catalog/course_test.rb` |
| `app/domain/entities/catalog/essential.rb` | `Entities::Catalog::Essential` | `id, slug, course_id, name, subtitle, position, author_id, status, published_at, archived_at, content_html`. Mêmes règles de statut que `Course`. | `test/domain/entities/catalog/essential_test.rb` |
| `app/domain/entities/assessment/answer.rb` | `Entities::Assessment::Answer` (Data) | `id, position, content, correct` | couvert par `question_test` |
| `app/domain/entities/assessment/question.rb` | `Entities::Assessment::Question` | `id, position, content, explanation, question_type, answers`. `TYPES` et `STRUCTURE = { "true_false" => { total: 2..2, correct: 1 }, "single_choice" => { total: 2.., correct: 1 }, "multiple_correct_2" => { total: 3.., correct: 2 }, "multiple_correct_3" => { total: 4.., correct: 3 } }`. La validation les applique (repris de l'ancienne entité, AS-03). `multiple?` vaut vrai pour les types `multiple_*`. `correct_answer_ids` renvoie un `Set`. `correct?(selected_ids)` compare **l'égalité exacte des ensembles d'identifiants** (ADR-0054). | `test/domain/entities/assessment/question_test.rb` |
| `app/domain/entities/assessment/exercise.rb` | `Entities::Assessment::Exercise` | `id, slug, essential_id, title, description, kind, position, author_id, status, published_at, archived_at, questions`. Validations : `title` présent. Publier exige au moins une question valide. `questions_locked?(has_sessions:)` vaut `has_sessions` : les questions sont figées dès la première session. | `test/domain/entities/assessment/exercise_test.rb` |
| `app/domain/entities/assessment/exercise_session.rb` | `Entities::Assessment::ExerciseSession` | `id, public_id, student_id, exercise_id, status, questions_total, answered_count, correct_count, score_percent, started_at, completed_at`. `STATUSES = %w[in_progress completed abandoned]`. `progress_percent` vaut `answered_count * 100 / questions_total`. `complete(correct_count:, at:)` : `:invalid` si `answered_count < questions_total` ; `score_percent = (correct_count * 100.0 / questions_total).round`. | `test/domain/entities/assessment/exercise_session_test.rb` |
| `app/domain/entities/assessment/question_attempt.rb` | `Entities::Assessment::QuestionAttempt` (Data) | `session_id, question_id, selected_answer_ids, correct, created_at` | couvert par le repository |
| `app/domain/entities/assessment/badge_scale.rb` | `Entities::Assessment::BadgeScale` | `GOLD = 100`, `SILVER = 80`, `BRONZE = 50`, `PASS = 50`, `MASTERY = 70`. `level_for(score)` renvoie `"gold"`, `"silver"`, `"bronze"` ou `nil`. `RANK = { "bronze" => 1, "silver" => 2, "gold" => 3 }`. `better?(new_level, current_level)` exige un rang **strictement** supérieur. `passed?(score)`. **Valeurs reprises du code de l'ancienne application, à confirmer par l'ADR-0033.** | `test/domain/entities/assessment/badge_scale_test.rb` |
| `app/domain/entities/assessment/badge.rb` | `Entities::Assessment::Badge` (Data) | `student_id, exercise_id, session_id, level, score_percent, earned_at` | couvert par le repository |

### 0.5 Domaine — ports, et leurs adaptateurs d'infrastructure

**Forme d'un port.** Un port est un `module` dont chaque méthode lève `NotImplementedError, "#{self.class} must implement #<nom>"`. Le repository fait `include` du port et convertit chaque ligne `Orm::` en entité, par une méthode privée `map_to_entity`. **Aucun objet `Orm::` ne sort d'un repository.**

**Les dates.** Les méthodes qui dépendent du temps reçoivent `now:` ou `at:` en paramètre. Les use cases reçoivent une horloge `clock:` injectée, qui vaut `Time` par défaut.

| Port — Fichier | Repository / adaptateur — Fichier | Test (contrat + base) |
|---|---|---|
| `app/domain/ports/identity/user_repository_port.rb` | `app/infrastructure/repositories/identity/user_repository.rb` | `test/infrastructure/repositories/identity/user_repository_test.rb` |
| `app/domain/ports/identity/registration_repository_port.rb` | `app/infrastructure/repositories/identity/registration_repository.rb` | `test/infrastructure/repositories/identity/registration_repository_test.rb` |
| `app/domain/ports/identity/teacher_repository_port.rb` | `app/infrastructure/repositories/identity/teacher_repository.rb` | `test/infrastructure/repositories/identity/teacher_repository_test.rb` |
| `app/domain/ports/identity/user_session_repository_port.rb` | `app/infrastructure/repositories/identity/user_session_repository.rb` | `test/infrastructure/repositories/identity/user_session_repository_test.rb` |
| `app/domain/ports/identity/login_failure_repository_port.rb` | `app/infrastructure/repositories/identity/login_failure_repository.rb` | `test/infrastructure/repositories/identity/login_failure_repository_test.rb` |
| `app/domain/ports/identity/audit_log_port.rb` | `app/infrastructure/repositories/identity/audit_log_repository.rb` | `test/infrastructure/repositories/identity/audit_log_repository_test.rb` |
| `app/domain/ports/identity/second_factor_repository_port.rb` | `app/infrastructure/repositories/identity/second_factor_repository.rb` | `test/infrastructure/repositories/identity/second_factor_repository_test.rb` |
| `app/domain/ports/identity/pin_recovery_repository_port.rb` | `app/infrastructure/repositories/identity/pin_recovery_repository.rb` | `test/infrastructure/repositories/identity/pin_recovery_repository_test.rb` |
| `app/domain/ports/identity/team_invitation_repository_port.rb` | `app/infrastructure/repositories/identity/team_invitation_repository.rb` | `test/infrastructure/repositories/identity/team_invitation_repository_test.rb` |
| `app/domain/ports/identity/totp_port.rb` | `app/infrastructure/adapters/identity/rotp_totp.rb` | `test/infrastructure/adapters/identity/rotp_totp_test.rb` |
| `app/domain/ports/identity/secret_hasher_port.rb` | `app/infrastructure/adapters/identity/bcrypt_secret_hasher.rb` | `test/infrastructure/adapters/identity/bcrypt_secret_hasher_test.rb` |
| `app/domain/ports/school/drena_repository_port.rb` | `app/infrastructure/repositories/school/drena_repository.rb` | `test/infrastructure/repositories/school/drena_repository_test.rb` |
| `app/domain/ports/school/school_repository_port.rb` | `app/infrastructure/repositories/school/school_repository.rb` | `test/infrastructure/repositories/school/school_repository_test.rb` |
| `app/domain/ports/classroom/classroom_repository_port.rb` | `app/infrastructure/repositories/classroom/classroom_repository.rb` | `test/infrastructure/repositories/classroom/classroom_repository_test.rb` |
| `app/domain/ports/classroom/membership_repository_port.rb` | `app/infrastructure/repositories/classroom/membership_repository.rb` | `test/infrastructure/repositories/classroom/membership_repository_test.rb` |
| `app/domain/ports/classroom/teaching_repository_port.rb` | `app/infrastructure/repositories/classroom/teaching_repository.rb` | `test/infrastructure/repositories/classroom/teaching_repository_test.rb` |
| `app/domain/ports/classroom/assignment_repository_port.rb` | `app/infrastructure/repositories/classroom/assignment_repository.rb` | `test/infrastructure/repositories/classroom/assignment_repository_test.rb` — **100 % lignes et branches, trois types de ressource** |
| `app/domain/ports/catalog/referential_repository_port.rb` | `app/infrastructure/repositories/catalog/referential_repository.rb` | `test/infrastructure/repositories/catalog/referential_repository_test.rb` |
| `app/domain/ports/catalog/course_repository_port.rb` | `app/infrastructure/repositories/catalog/course_repository.rb` | `test/infrastructure/repositories/catalog/course_repository_test.rb` |
| `app/domain/ports/catalog/essential_repository_port.rb` | `app/infrastructure/repositories/catalog/essential_repository.rb` | `test/infrastructure/repositories/catalog/essential_repository_test.rb` |
| `app/domain/ports/assessment/exercise_repository_port.rb` | `app/infrastructure/repositories/assessment/exercise_repository.rb` | `test/infrastructure/repositories/assessment/exercise_repository_test.rb` |
| `app/domain/ports/assessment/exercise_session_repository_port.rb` | `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` |
| `app/domain/ports/assessment/badge_repository_port.rb` | `app/infrastructure/repositories/assessment/badge_repository.rb` | `test/infrastructure/repositories/assessment/badge_repository_test.rb` |

**Signatures gelées.** Toutes les méthodes prennent des arguments nommés. `→` indique le type de retour, et `nil` signifie « absent ».

```ruby
Ports::Identity::UserRepositoryPort
  find(id:)                              → Entities::Identity::User | nil
  find_by_public_id(public_id:)          → User | nil
  find_by_contact(contact:)              → User | nil
  contact_taken?(contact:)               → Boolean
  authenticate(contact:, pin:)           → User | nil        # bcrypt, temps constant même si le numéro est inconnu
  update_pin(user_id:, pin:)             → true
  actor_for(user_id:, second_factor_verified:) → Entities::Identity::Actor

Ports::Identity::RegistrationRepositoryPort    # chaque méthode est UNE transaction ; RecordNotUnique → :conflict
  register_student(user:, pin:, classroom_id:, joined_at:)   → Result(User) | Result.failure(:conflict, field: :contact)
  register_teacher(user:, pin:, school_id:, material_id:)    → Result(User) | failure(:conflict)
  register_team_member(user:, pin:, invitation_id:, at:)     → Result(User) | failure(:conflict)   # marque aussi l'invitation acceptée

Ports::Identity::TeacherRepositoryPort
  find_by_user_id(user_id:)              → { teacher_id:, primary_school_id:, material_id:, onboarded: } | nil
  mark_onboarded(teacher_id:, at:)       → true

Ports::Identity::UserSessionRepositoryPort
  create(user_id:, token_digest:, ip:, user_agent:, expires_at:, at:) → Entities::Identity::UserSession
  find_by_token_digest(token_digest:)    → UserSession | nil
  touch(id:, at:)                        → true
  mark_second_factor_verified(id:, at:)  → true
  destroy(id:)                           → true
  destroy_all_for(user_id:)              → Integer

Ports::Identity::LoginFailureRepositoryPort
  record(contact:, ip:, at:)             → true
  count_since(contact:, since:)          → Integer

Ports::Identity::AuditLogPort
  record(action:, actor_id:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil, at:) → true

Ports::Identity::SecondFactorRepositoryPort
  state_for(team_id:)                    → { secret:, enabled:, last_used_step: }
  store_pending_secret(team_id:, secret:) → true
  enable(team_id:, backup_code_digests:, at:) → true      # remplace les codes de secours existants
  record_used_step(team_id:, step:)      → Boolean        # faux si step <= last_used_step (rejeu)
  backup_code_digests(team_id:)          → [{ id:, digest: }]   # non utilisés seulement
  consume_backup_code(id:, at:)          → Boolean

Ports::Identity::PinRecoveryRepositoryPort
  issue(user_id:, issued_by_id:, code_digest:, expires_at:, at:) → true   # révoque le code actif précédent
  active_for(user_id:)                   → Entities::Identity::PinRecoveryCode (avec digest) | nil
  record_failure(id:)                    → Integer        # nouveau compteur
  consume(id:, at:)                      → true

Ports::Identity::TeamInvitationRepositoryPort
  create(invited_by_id:, contact:, last_name:, first_names:, token_digest:, expires_at:) → Entities::Identity::TeamInvitation
  pending_for_contact?(contact:, now:)   → Boolean
  find_by_token_digest(token_digest:)    → TeamInvitation | nil

Ports::Identity::TotpPort
  generate_secret                        → String
  provisioning_uri(secret:, label:)      → String
  verify(secret:, code:, now:)           → Integer | nil  # le pas temporel accepté, avec DRIFT_BEHIND

Ports::Identity::SecretHasherPort
  digest(secret:)                        → String
  match?(secret:, digest:)               → Boolean

Ports::School::DrenaRepositoryPort
  all_ordered                            → [Entities::School::Drena]
Ports::School::SchoolRepositoryPort
  find(id:)                              → Entities::School::School | nil
  in_drena(drena_id:)                    → [School]        # triés par nom
  belongs_to_drena?(school_id:, drena_id:) → Boolean

Ports::Classroom::ClassroomRepositoryPort
  find_by_public_id(public_id:)          → Entities::Classroom::Classroom | nil
  find_by_join_code(join_code:)          → Classroom | nil   # code déjà normalisé
  create(classroom:)                     → Result(Classroom) | failure(:conflict, field: :name | :join_code)
  name_taken?(school_id:, name:)         → Boolean
  ids_in_school(school_id:, public_ids:) → [Integer]          # filtre les public_ids hors école

Ports::Classroom::MembershipRepositoryPort
  primary_for(student_id:)               → Entities::Classroom::Membership | nil
  member?(student_id:, classroom_id:)    → Boolean

Ports::Classroom::TeachingRepositoryPort
  teaches?(teacher_id:, classroom_id:)   → Boolean
  teaches_student?(teacher_id:, student_id:) → Boolean
  replace_in_school(teacher_id:, school_id:, classroom_ids:) → true   # ne touche que les classes de school_id

Ports::Classroom::AssignmentRepositoryPort
  find(classroom_id:, assignable:)       → Entities::Classroom::Assignment | nil
  save(assignment:)                      → Assignment      # upsert sur (classroom, type, id) : réactive au lieu de lever
  resolve_assignable(type:, slug:)       → Entities::Classroom::Assignable | nil   # contenu publié seulement
  assigned_to_student?(student_id:, assignable:) → Boolean   # actif, via une adhésion de l'élève
  assigned_to_teacher?(teacher_id:, assignable:) → Boolean   # actif, dans une classe qu'il enseigne

Ports::Catalog::ReferentialRepositoryPort
  level_exists?(id:) · material_exists?(id:) · series_exists?(id:) → Boolean
  series_allowed?(level_id:, series_id:) → Boolean        # series_id nil ⇒ vrai

Ports::Catalog::CourseRepositoryPort
  find_by_slug(slug:)                    → Entities::Catalog::Course | nil   # tous statuts
  create(course:)                        → Course           # avec content_html → rich text
  update(course:)                        → Course
  name_taken?(name:, level_id:, material_id:, except_id: nil) → Boolean

Ports::Catalog::EssentialRepositoryPort
  find_by_slug(slug:)                    → Entities::Catalog::Essential | nil
  create(essential:)                     → Essential        # position = max + 1 dans le cours
  update(essential:)                     → Essential
  name_taken?(course_id:, name:, except_id: nil) → Boolean

Ports::Assessment::ExerciseRepositoryPort
  find_by_slug(slug:)                    → Entities::Assessment::Exercise (questions + réponses) | nil
  create(exercise:)                      → Exercise         # exercice + questions + réponses, UNE transaction
  update(exercise:, replace_questions:)  → Exercise         # replace_questions: supprime puis recrée, UNE transaction
  has_sessions?(exercise_id:)            → Boolean

Ports::Assessment::ExerciseSessionRepositoryPort
  find_by_public_id(public_id:)          → Entities::Assessment::ExerciseSession | nil
  in_progress_for(student_id:, exercise_id:) → ExerciseSession | nil
  start(student_id:, exercise_id:, questions_total:, at:) → ExerciseSession   # abandonne l'éventuelle session en cours, même transaction
  record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:) → :recorded | :duplicate
                                          # insert + incrément answered_count/correct_count en une transaction ; RecordNotUnique → :duplicate
  attempts(session_id:)                  → [Entities::Assessment::QuestionAttempt]
  complete(session_id:, score_percent:, at:) → true         # UPDATE … WHERE status = 'in_progress'

Ports::Assessment::BadgeRepositoryPort
  find(student_id:, exercise_id:)        → Entities::Assessment::Badge | nil
  save(badge:)                           → Badge            # upsert sur (student, exercise)
```

### 0.6 Domaine — policies, DTO et use cases du socle

**Policies** (ADR-0028). Chaque policy a une seule méthode publique, `allowed?(actor:, **contexte) → Boolean`. Ses ports éventuels sont injectés au constructeur. Un `actor` à `nil` (visiteur) renvoie `false`, sauf pour `JoinPolicy`.

| Fichier | Classe | Règle | Test |
|---|---|---|---|
| `app/domain/policies/identity/invite_team_policy.rb` | `Policies::Identity::InviteTeamPolicy` | `actor.team?` | `test/domain/policies/identity/invite_team_policy_test.rb` |
| `app/domain/policies/identity/assist_pin_recovery_policy.rb` | `Policies::Identity::AssistPinRecoveryPolicy.new(teaching:)` | `allowed?(actor:, target:)`. **Team** : `target.id != actor.user_id`. **Teacher** : la cible est un élève et `teaching.teaches_student?(teacher_id: actor.teacher_id, student_id:)`. Sinon, faux. | `test/domain/policies/identity/assist_pin_recovery_policy_test.rb` |
| `app/domain/policies/catalog/read_published_policy.rb` | `Policies::Catalog::ReadPublishedPolicy` | `allowed?(actor:, content:)`. Faux pour un visiteur. Vrai si `actor.team?` ou `content.status == "published"`. | `test/domain/policies/catalog/read_published_policy_test.rb` |
| `app/domain/policies/catalog/manage_content_policy.rb` | `Policies::Catalog::ManageContentPolicy` | `actor.team?` | `test/domain/policies/catalog/manage_content_policy_test.rb` |
| `app/domain/policies/assessment/reveal_answers_policy.rb` | `Policies::Assessment::RevealAnswersPolicy.new(assignments:)` | `allowed?(actor:, exercise:)`. `actor.team?`, ou bien `actor.teacher?` et `assignments.assigned_to_teacher?(… assignable: exercise)` | `test/domain/policies/assessment/reveal_answers_policy_test.rb` |
| `app/domain/policies/assessment/start_session_policy.rb` | `Policies::Assessment::StartSessionPolicy.new(assignments:)` | `actor.student?`, et `exercise.status == "published"`, et `assignments.assigned_to_student?(…)`. Assignation **directe** de l'exercice uniquement. | `test/domain/policies/assessment/start_session_policy_test.rb` |
| `app/domain/policies/assessment/play_session_policy.rb` | `Policies::Assessment::PlaySessionPolicy` | `actor.student?`, et `session.student_id == actor.student_id`, et `session.status == "in_progress"` | `test/domain/policies/assessment/play_session_policy_test.rb` |
| `app/domain/policies/assessment/read_session_policy.rb` | `Policies::Assessment::ReadSessionPolicy.new(teaching:)` | `team?`, ou l'élève propriétaire, ou `teacher?` avec `teaching.teaches_student?` | `test/domain/policies/assessment/read_session_policy_test.rb` |
| `app/domain/policies/classroom/join_policy.rb` | `Policies::Classroom::JoinPolicy` | `allowed?(actor:, classroom:)` vaut `actor.nil? && !classroom.nil?`. En V1, un compte connecté ne rejoint pas une classe. | `test/domain/policies/classroom/join_policy_test.rb` |
| `app/domain/policies/classroom/access_policy.rb` | `Policies::Classroom::AccessPolicy.new(memberships:, teaching:)` | `team?`, ou un élève membre, ou un enseignant qui y enseigne | `test/domain/policies/classroom/access_policy_test.rb` |
| `app/domain/policies/classroom/read_roster_policy.rb` | `Policies::Classroom::ReadRosterPolicy.new(teaching:)` | `team?`, ou un enseignant qui y enseigne. L'élève n'y a jamais droit. | `test/domain/policies/classroom/read_roster_policy_test.rb` |
| `app/domain/policies/classroom/teach_policy.rb` | `Policies::Classroom::TeachPolicy` | `allowed?(actor:, primary_school_id:)` vaut `actor.teacher? && !primary_school_id.nil?` | `test/domain/policies/classroom/teach_policy_test.rb` |
| `app/domain/policies/classroom/assign_policy.rb` | `Policies::Classroom::AssignPolicy.new(teaching:)` | `team?`, ou un enseignant qui enseigne la classe | `test/domain/policies/classroom/assign_policy_test.rb` |
| `app/domain/policies/school/manage_school_policy.rb` | `Policies::School::ManageSchoolPolicy` | `actor.team?` en V1. `school_admin` s'ajoutera en V2. | `test/domain/policies/school/manage_school_policy_test.rb` |

**DTO.** Ils vivent dans `app/domain/dtos/<ctx>/`, sous le namespace `Dtos::<Ctx>::…Dto`. Chaque DTO inclut `ActiveModel::Model`, `ActiveModel::Attributes` et `ActiveModel::Validations`. Il valide la **forme** : présence, format, longueur. Les règles métier restent dans l'entité ou le use case. Les messages passent par la locale.

| Fichier | Attributs · validations | Test |
|---|---|---|
| `app/domain/dtos/identity/credentials_dto.rb` | `contact, pin, ip, user_agent`. `contact` et `pin` présents. `contact` est normalisé par `Contact` à l'affectation. | `test/domain/dtos/identity/credentials_dto_test.rb` |
| `app/domain/dtos/identity/student_registration_dto.rb` | `last_name, first_names, gender, contact, pin, join_code`. Tous présents. `gender` dans `GENDERS`. `contact` au format `Contact`. `pin` au format `Pin`. **Aucun attribut `role`.** | `test/domain/dtos/identity/student_registration_dto_test.rb` |
| `app/domain/dtos/identity/teacher_registration_dto.rb` | `last_name, first_names, gender, contact, pin, drena_id, school_id, material_id`. Tous présents. | `test/domain/dtos/identity/teacher_registration_dto_test.rb` |
| `app/domain/dtos/identity/second_factor_code_dto.rb` | `code`. Présent. Soit 6 chiffres (TOTP), soit 10 caractères (code de secours). | `test/domain/dtos/identity/second_factor_code_dto_test.rb` |
| `app/domain/dtos/identity/pin_recovery_dto.rb` | `contact, code, new_pin, ip`. `code` fait 6 chiffres. `new_pin` au format `Pin`. | `test/domain/dtos/identity/pin_recovery_dto_test.rb` |
| `app/domain/dtos/identity/team_invitation_dto.rb` | `contact, last_name, first_names` | `test/domain/dtos/identity/team_invitation_dto_test.rb` |
| `app/domain/dtos/identity/team_invitation_acceptance_dto.rb` | `token, gender, pin` | `test/domain/dtos/identity/team_invitation_acceptance_dto_test.rb` |
| `app/domain/dtos/classroom/classroom_dto.rb` | `school_id, level_id, series_id, name`. `name` fait au plus 15 caractères. | `test/domain/dtos/classroom/classroom_dto_test.rb` |
| `app/domain/dtos/classroom/teaching_selection_dto.rb` | `classroom_public_ids` (Array). `validates :classroom_public_ids, length: { minimum: 1 }`, avec le message « Veuillez sélectionner au moins une classe. » | `test/domain/dtos/classroom/teaching_selection_dto_test.rb` |
| `app/domain/dtos/classroom/assignment_dto.rb` | `classroom_public_id, assignable_type, assignable_slug`. Le type appartient à `Assignable::TYPES`. | `test/domain/dtos/classroom/assignment_dto_test.rb` |
| `app/domain/dtos/catalog/course_dto.rb` | `name, subtitle, level_id, series_id, material_id, content_html, status` | `test/domain/dtos/catalog/course_dto_test.rb` |
| `app/domain/dtos/catalog/essential_dto.rb` | `course_slug, name, subtitle, content_html, status` | `test/domain/dtos/catalog/essential_dto_test.rb` |
| `app/domain/dtos/assessment/answer_dto.rb` | `content, correct` | couvert par `exercise_dto_test` |
| `app/domain/dtos/assessment/question_dto.rb` | `content, explanation, question_type, answers` (Array d'`AnswerDto`) | couvert par `exercise_dto_test` |
| `app/domain/dtos/assessment/exercise_dto.rb` | `essential_slug, title, description, kind, status, questions` (Array de `QuestionDto`). `ExerciseDto.from_params(hash)` construit l'arbre à partir de `questions_attributes`. | `test/domain/dtos/assessment/exercise_dto_test.rb` |
| `app/domain/dtos/assessment/attempt_dto.rb` | `session_public_id, question_id, answer_ids` (Array d'Integer, `compact`). Vide : erreur « Veuillez sélectionner au moins une réponse. » | `test/domain/dtos/assessment/attempt_dto_test.rb` |

**Use cases du socle** (`app/domain/use_cases/identity/`). Chaque use case a une seule méthode publique `call(...) → Result`. Ses ports, policies et son horloge `clock:` sont injectés au constructeur, et le domaine n'instancie **jamais** un repository. C'est le contrôleur qui les câble.

| Fichier | Comportement | Test |
|---|---|---|
| `app/domain/use_cases/identity/authenticate.rb` | `call(dto:)`. (1) Si le DTO est invalide : `:invalid`. (2) Si `login_failures.count_since(contact:, since: now - 1.minute) >= 5` : écrit `audit.record(action: "login_locked")` et renvoie `:locked`. Le PIN n'est **pas** vérifié. (3) `users.authenticate`. En cas d'échec : `login_failures.record`, `audit.record("login_failed")`, puis `:invalid`, avec un message unique. (4) En cas de succès : génère le jeton, crée la `UserSession` avec `expires_at` selon le rôle, puis renvoie `Result.success({ user:, token: })`. | `test/domain/use_cases/identity/authenticate_test.rb` |
| `app/domain/use_cases/identity/resolve_session.rb` | `call(token:)`. Cherche par digest. Absente ou expirée (`UserSession#expired?`) : `:expired`. Si l'expiration est dépassée, la ligne est détruite. Sinon, `touch` au-delà de `TOUCH_EVERY`, puis `Result.success(actor)`. | `test/domain/use_cases/identity/resolve_session_test.rb` |
| `app/domain/use_cases/identity/resolve_home.rb` | `call(actor:)` renvoie le symbole de `HomeDestination`. Les données viennent de `TeacherRepositoryPort` et de `MembershipRepositoryPort`. | `test/domain/use_cases/identity/resolve_home_test.rb` |
| `app/domain/use_cases/identity/sign_out.rb` | `call(token:)`. Détruit la session. Idempotent. | `test/domain/use_cases/identity/sign_out_test.rb` |
| `app/domain/use_cases/identity/start_second_factor_enrollment.rb` | `call(actor:)`. Réservé à la team non enrôlée. Génère et stocke un secret en attente, puis renvoie `provisioning_uri`. | `test/domain/use_cases/identity/start_second_factor_enrollment_test.rb` |
| `app/domain/use_cases/identity/confirm_second_factor_enrollment.rb` | `call(actor:, session_id:, dto:)`. Vérifie le code TOTP. En cas de succès : `enable` avec 10 codes de secours hachés, marque la session comme vérifiée, écrit l'audit `second_factor_enrolled`, puis renvoie les codes en clair **une seule fois**. | `test/domain/use_cases/identity/confirm_second_factor_enrollment_test.rb` |
| `app/domain/use_cases/identity/verify_second_factor.rb` | `call(actor:, session_id:, dto:)`. Accepte un code TOTP (avec `record_used_step`, qui refuse le rejeu) ou un code de secours consommé. En cas d'échec : audit `second_factor_failed` et `:invalid`. En cas de succès : `mark_second_factor_verified`. | `test/domain/use_cases/identity/verify_second_factor_test.rb` |
| `app/domain/use_cases/identity/issue_pin_recovery_code.rb` | `call(actor:, target_public_id:)`. Applique `AssistPinRecoveryPolicy`, génère le code et le stocke haché avec `TTL`. Écrit l'audit `pin_recovery_issued`, avec l'émetteur et la cible. Renvoie le code en clair et son expiration. Utilisé par les lots B8 et D4, avec le contrôleur de B8. | `test/domain/use_cases/identity/issue_pin_recovery_code_test.rb` |
| `app/domain/use_cases/identity/redeem_pin_recovery_code.rb` | `call(dto:)`. Utilisateur introuvable ou code inutilisable : `:invalid` (« Code invalide ou expiré. »). Code faux : `record_failure`, et `:invalid`. Code juste : `update_pin`, `consume`, `destroy_all_for(user_id)`, audit `pin_recovery_redeemed`. | `test/domain/use_cases/identity/redeem_pin_recovery_code_test.rb` |

**Use case partagé du contexte classroom.** Il est remonté au Lot 0 parce que D4, D5, D6 et D7 l'appellent tous.

| Fichier | Comportement | Test |
|---|---|---|
| `app/domain/use_cases/classroom/read_classroom.rb` | `call(actor:, classroom_public_id:)`. `classrooms.find_by_public_id` : absente → `:not_found`. `AccessPolicy` : refus → `:forbidden`. Renvoie `Result.success({ classroom:, show_roster: ReadRosterPolicy.allowed?(…), can_assign: AssignPolicy.allowed?(…) })`. | `test/domain/use_cases/classroom/read_classroom_test.rb` |

**Actions d'audit de la V1**, sous la forme de constantes dans `Ports::Identity::AuditLogPort::ACTIONS` :
`login_failed`, `login_locked`, `second_factor_failed`, `second_factor_enrolled`, `pin_recovery_issued`, `pin_recovery_redeemed`, `team_invitation_created`, `team_invitation_accepted`, `content_archived`, `classroom_created`.

### 0.7 Queries partagées, helpers partagés

Une query renvoie des `Data` typés, jamais une relation (ADR-0026). Chaque query propre à un écran appartient au lot de cet écran. Seules les deux queries et les deux helpers ci-dessous servent à plusieurs lots.

| Fichier | Contenu | Test |
|---|---|---|
| `app/infrastructure/queries/catalog/referential_options_query.rb` | `Queries::Catalog::ReferentialOptionsQuery#call` renvoie `Options = Data.define(:levels, :series_by_level, :materials)`, triés par position ou par nom. Sert à B2, D1 et D8. | `test/infrastructure/queries/catalog/referential_options_query_test.rb` |
| `app/infrastructure/queries/school/school_options_query.rb` | `Queries::School::SchoolOptionsQuery`. `drenas` renvoie `[Data(id, name)]`. `schools_grouped` renvoie `{ drena_name => [Data(id, name)] }`. Sert à D1 et D8. | `test/infrastructure/queries/school/school_options_query_test.rb` |
| `app/helpers/catalog/materials_helper.rb` | `material_tone(category)` : `literature` → `:info`, `science` → `:success`, `other` → `:neutral`, par les tons du Lot 0c. `material_badge(material)` rend `ui_badge(material.name, tone: material_tone(material.category), icon: material.icon)`. **Aucune déduction à partir du nom** (CA-26). | `test/helpers/catalog/materials_helper_test.rb` : renommer une matière ne change pas son ton |
| `app/helpers/assessment/badges_helper.rb` | `badge_label(level)` renvoie « Or », « Argent », « Bronze » ou « Non acquis » par `t()`. `badge_tone(level)` : gold → `:warning`, silver → `:neutral`, bronze → `:info`, `nil` → `:neutral`. | `test/helpers/assessment/badges_helper_test.rb` |

### 0.8 Seeds — référentiel ivoirien et DRENA (ADR-0034)

Tous les seeds sont idempotents (`find_or_create_by!` sur la clé naturelle) et se jouent dans tous les environnements, sauf `demo.rb`.

| Fichier | Contenu | Test |
|---|---|---|
| `db/seeds.rb` | Charge, dans l'ordre : `school.rb`, `catalog.rb`, `identity.rb`, puis `demo.rb` si `Rails.env.development?` | `test/db/seeds_test.rb` : deux passages, mêmes comptes |
| `db/seeds/school.rb` | 41 DRENA et leurs établissements, lus dans les deux fichiers de données des lignes suivantes. | (même test) |
| `db/seeds/data/drenas.yml` | Les 41 noms de `⟨ancienne⟩ ../.Business/content_pedagogics/Drenas.md` §2 : Abidjan 1 à 4, Aboisso, Adzopé, Agboville, Dabou, Grand-Bassam, Tiassalé, Bouaké 1, Bouaké 2, Daoukro, Dimbokro, Yamoussoukro, Bongouanou, Man, Danané, Duékoué, Guiglo, San-Pédro, Sassandra, Soubré, Daloa, Gagnoa, Divo, Issia, Sinfra, Korhogo, Boundiali, Ferkessédougou, Odienné, Minignan, Séguéla, Mankono, Touba, Abengourou, Bondoukou, Bouna, Katiola, Bouaflé. **À valider par le porteur.** | — |
| `db/seeds/data/schools.yml` | Converti des 41 fichiers `⟨ancienne⟩ ../.Business/content_pedagogics/DRENAS/schools_*.json`. `schoolsigle` devient `short_name`. `schooltype` devient `sector` (`public` → `public`, `privée` → `private`, `mixte` → `mixed`). `schoolstatus` devient `status`. | — |
| `db/seeds/catalog.rb` | **Niveaux** : 6ème (1, first), 5ème (2), 4ème (3), 3ème (4), 2nde (5, second), 1ère (6), Tle (7). **Séries** : A1, A2, C, D. **level_series** : 1ère et Tle × {A1, A2, C, D}, 2nde × {C}. **Matières** : lues dans le fichier de données de la ligne suivante. | (même test) |
| `db/seeds/data/materials.yml` | `name, short_name, category, icon`. Français (FR, literature, `language`), Anglais (ANG, literature, `language`), Espagnol (ESP, literature, `language`), Allemand (ALL, literature, `language`), Philosophie (PHILO, literature, `light-bulb`), Histoire-Géographie (HG, literature, `globe-europe-africa`), Mathématiques (MATHS, science, `calculator`), Physique-Chimie (PC, science, `beaker`), SVT (SVT, science, `bug-ant`), EDHC (EDHC, other, `scale`), EPS (EPS, other, `trophy`). **À valider par le porteur.** | — |
| `db/seeds/identity.rb` | Un compte `team` si aucun n'existe. Les valeurs viennent de `ENV.fetch("LNCLASS_TEAM_CONTACT")`, `LNCLASS_TEAM_LAST_NAME`, `LNCLASS_TEAM_FIRST_NAMES` et `LNCLASS_TEAM_PIN`. En production, une variable absente lève une erreur explicite. En développement, les valeurs par défaut sont `0700000000` et `1357`. Aucun PIN n'est écrit dans le dépôt pour la production (ADR-0038). | (même test) |
| `db/seeds/demo.rb` | Développement seulement. Crée un enseignant `0500000001`, configuré, en SVT, dans le premier établissement d'Abidjan 1, avec la classe « Tle D 1 ». Crée l'élève `0100000001`, membre principal. Crée un cours publié, une fiche, et un exercice de 2 questions assigné. Les PIN valent `2468`. | — |

### 0.9 Routes V1 complètes, socle d'authentification, shell branché

**Routes.** Chaque fichier de contexte est dessiné en entier ici, et aucun lot ne les modifie. Dans chaque contexte, les routes `new` sont déclarées **avant** les routes `:slug`.

| Fichier | Contenu |
|---|---|
| `config/routes.rb` | `root "homepage#index"`, `get "up" => "rails/health#show"`, puis `draw :identity`, `draw :school`, `draw :classroom`, `draw :catalog`, `draw :assessment`, `draw :communication` |
| `config/routes/identity.rb` | voir le bloc ci-dessous |
| `config/routes/school.rb` | voir le bloc ci-dessous |
| `config/routes/classroom.rb` | voir le bloc ci-dessous |
| `config/routes/catalog.rb` | voir le bloc ci-dessous |
| `config/routes/assessment.rb` | voir le bloc ci-dessous |
| `config/routes/communication.rb` | vide, avec le commentaire `# V6` |

```ruby
# identity
get  "login",  to: "identity/sessions#new", as: :new_session
resource :session, only: %i[create destroy], controller: "identity/sessions"          # session_path (DELETE = déconnexion, attendu par le shell 0c)
resource :second_factor, only: %i[new create], path: "second-factor", controller: "identity/second_factors"
resource :second_factor_enrollment, only: %i[new create], path: "second-factor/enrollment", controller: "identity/second_factor_enrollments"
resource :pin_recovery, only: %i[new create], path: "pin-recovery", controller: "identity/pin_recoveries"
get  "account/pending", to: "identity/pending_accounts#show", as: :pending_account
get  "student-signup", to: "identity/student_registrations#new",  as: :new_student_registration      # A1
post "student-signup", to: "identity/student_registrations#create", as: :student_registrations      # A1
get  "c/:join_code",   to: "identity/student_registrations#new",  as: :join_classroom               # A1
get  "teacher-signup", to: "identity/teacher_registrations#new",  as: :new_teacher_registration      # D1
post "teacher-signup", to: "identity/teacher_registrations#create", as: :teacher_registrations      # D1
get  "team/invitations/new", to: "identity/team_invitations#new", as: :new_team_invitation          # B7
post "team/invitations",     to: "identity/team_invitations#create", as: :team_invitations          # B7
get  "team/invitations/:token/accept", to: "identity/team_invitation_acceptances#new",  as: :accept_team_invitation   # B7
post "team/invitations/:token/accept", to: "identity/team_invitation_acceptances#create"                              # B7
get  "team/accounts", to: "identity/account_lookups#show", as: :team_account_lookup                # B8
post "accounts/:user_public_id/pin-recovery-codes", to: "identity/pin_recovery_codes#create", as: :account_pin_recovery_codes   # B8 (appelé aussi par D4)

# school
get "api/v1/schools", to: "school/api/schools#index", as: :api_v1_schools, defaults: { format: :json }   # D1

# classroom
get  "api/v1/classrooms/lookup", to: "classroom/api/join_code_lookups#show", as: :api_v1_classroom_lookup, defaults: { format: :json }  # A1
get  "students",            to: "classroom/student_homes#show",      as: :student_home        # A2
get  "students/classroom",  to: "classroom/student_classrooms#show", as: :student_classroom   # A3
get  "teachers",            to: "classroom/teacher_homes#show",      as: :teacher_home        # D3
get  "teachers/classrooms", to: "classroom/teaching_selections#edit", as: :teacher_classrooms # D2
put  "teachers/classrooms", to: "classroom/teaching_selections#update"                        # D2
get  "classrooms/new",      to: "classroom/classroom_creations#new", as: :new_classroom       # D8
post "classrooms",          to: "classroom/classroom_creations#create", as: :classrooms       # D8
get  "classrooms/:public_id", to: "classroom/classrooms#show", as: :classroom                 # D4
get  "classrooms/:classroom_public_id/courses/:course_slug", to: "classroom/classroom_courses#show", as: :classroom_course   # D5
get  "classrooms/:classroom_public_id/courses/:course_slug/essentials/:essential_slug", to: "classroom/classroom_essentials#show", as: :classroom_essential  # D6
post   "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#create", as: :classroom_assignments      # D5
delete "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#destroy"                                # D5
get  "courses/:course_slug/assignments", to: "classroom/course_assignments#index", as: :course_assignments               # D7

# catalog
get   "teams", to: "catalog/team_homes#show", as: :team_home                                   # B6
get   "courses/new",            to: "catalog/course_editions#new",  as: :new_course            # B2
post  "courses",                to: "catalog/course_editions#create"                           # B2
get   "courses/:slug/edit",     to: "catalog/course_editions#edit", as: :edit_course           # B2
patch "courses/:slug",          to: "catalog/course_editions#update"                           # B2
patch "courses/:slug/archive",  to: "catalog/course_editions#archive", as: :archive_course     # B2
get   "courses/:course_slug/essentials/new", to: "catalog/essential_editions#new", as: :new_course_essential          # B4
post  "courses/:course_slug/essentials",     to: "catalog/essential_editions#create", as: :course_essentials          # B4
get   "courses/:course_slug/essentials/:slug/edit", to: "catalog/essential_editions#edit", as: :edit_course_essential # B4
patch "courses/:course_slug/essentials/:slug",      to: "catalog/essential_editions#update"                           # B4
patch "courses/:course_slug/essentials/:slug/archive", to: "catalog/essential_editions#archive", as: :archive_course_essential  # B4
get   "courses",       to: "catalog/courses#index", as: :courses                               # B1
get   "courses/:slug", to: "catalog/courses#show",  as: :course                                # B1
get   "courses/:course_slug/essentials/:slug", to: "catalog/essentials#show", as: :course_essential   # B3

# assessment
get   "courses/:course_slug/essentials/:essential_slug/exercises/new", to: "assessment/exercise_editions#new", as: :new_essential_exercise   # B5
post  "courses/:course_slug/essentials/:essential_slug/exercises",     to: "assessment/exercise_editions#create", as: :essential_exercises  # B5
get   "exercises/:slug/edit",    to: "assessment/exercise_editions#edit", as: :edit_exercise   # B5
patch "exercises/:slug",         to: "assessment/exercise_editions#update"                     # B5
patch "exercises/:slug/archive", to: "assessment/exercise_editions#archive", as: :archive_exercise   # B5
get   "exercises/:slug", to: "assessment/exercises#show", as: :exercise                        # C1
post  "exercises/:exercise_slug/sessions", to: "assessment/exercise_sessions#create", as: :exercise_sessions   # C2
get   "sessions/:public_id", to: "assessment/exercise_sessions#show", as: :exercise_session                   # C2
post  "sessions/:public_id/attempts", to: "assessment/question_attempts#create", as: :exercise_session_attempts  # C2
post  "sessions/:public_id/completion", to: "assessment/session_completions#create", as: :exercise_session_completion  # C3
get   "sessions/:public_id/result", to: "assessment/session_results#show", as: :exercise_session_result         # C3
```

Le test `test/routing/v1_routes_test.rb` vérifie deux choses :
- chaque nom de route attendu par `NavigationHelper::DESTINATIONS` existe pour les rôles student, teacher et team, sauf `schools_path`, `team_dashboard_path` et `profile_path` (inactifs en V1) ;
- `/courses/new` n'est pas capté par `courses#show`.

**Socle delivery.**

| Fichier | Contenu | Test |
|---|---|---|
| `app/controllers/application_controller.rb` | `include Authentication`, `include ResultRendering`. Le `allow_browser` de V0 est conservé. | — |
| `app/controllers/concerns/authentication.rb` | **Cookie** `cookies.signed[:session_token]` : `httponly`, `same_site: :lax`, `secure` hors développement et test. **`start_session(user, token)`** : `reset_session`, puis dépose le cookie. **`require_authentication`** (`before_action` par défaut) : `UseCases::Identity::ResolveSession`. Expirée ou absente : redirection vers `new_session_path`. **Si `actor.team?` et que le second facteur n'est pas vérifié** : redirection vers `new_second_factor_path`, ou `new_second_factor_enrollment_path` si la team n'est pas enrôlée, sauf pour ces contrôleurs eux-mêmes et `sessions#destroy`. **Macros** `allow_unauthenticated_access(only:)` et `allow_roles(*roles)` : un rôle hors liste reçoit 403. `current_actor` est exposé en `helper_method`. Ce concern est le **seul** endroit qui teste le rôle (ID-16). **`redirect_to_home`** : `ResolveHome`, puis symbole → route (`student_home`, `pending_account`, `teacher_classrooms`, `teacher_home`, `new_second_factor`, `team_home`). | `test/controllers/concerns/authentication_test.rb` : expiration absolue et d'inactivité, cookie falsifié, team non vérifiée bloquée sur `/teams` (TR-cadre-5), 403 pour un rôle hors liste |
| `app/controllers/concerns/result_rendering.rb` | `render_failure(result, form: nil)`. `:forbidden` → 403 avec `errors/forbidden` en HTML, `{ error: }` en JSON, toast en Turbo Stream. `:not_found` → 404 avec `errors/not_found`. `:invalid` et `:conflict` → nouveau rendu de `form` en 422. `:locked` → 429. `:expired` → redirection vers la connexion. | `test/controllers/concerns/result_rendering_test.rb` |
| `app/controllers/authenticated_controller.rb` | `AuthenticatedController < ApplicationController`, avec `layout "shell"` et `helper_method :shell_user`. `shell_user` construit `NavigationHelper::ShellUser.new(name: current_actor.display_name, role: current_actor.role)`. Tous les contrôleurs connectés des lots en héritent. | couvert par les tests des lots |
| `app/controllers/homepage_controller.rb` | `allow_unauthenticated_access`. Un visiteur connecté est envoyé vers `redirect_to_home` (TR-02). Le contenu de la landing appartient à A4. | `test/controllers/homepage_redirection_test.rb` |
| `app/controllers/identity/sessions_controller.rb` | `new`, `create`, `destroy`. `rate_limit to: 10, within: 1.minute, only: :create, by: -> { request.remote_ip }, with: -> { render_failure(Result.failure(:locked)) }`. `create` : `Authenticate`, puis `start_session`, toast « Connexion réussie ! », puis `redirect_to_home`. En cas d'échec, le formulaire est réaffiché en 422 avec le message unique et le PIN vide. `destroy` : `SignOut`, `reset_session`, suppression du cookie, puis redirection vers `/` avec « Déconnexion réussie ! ». | `test/controllers/identity/sessions_controller_test.rb` : TR-cadre-2, rotation de l'identifiant de session, 429 par adresse, normalisation `225` |
| `app/controllers/identity/second_factors_controller.rb` | `new`, `create`. `rate_limit to: 5, within: 1.minute, by: -> { session_token_digest }`. | `test/controllers/identity/second_factors_controller_test.rb` |
| `app/controllers/identity/second_factor_enrollments_controller.rb` | `new` : QR code en SVG via `RQRCode`, puis le secret en texte pour la saisie manuelle. `create` : confirmation, puis rendu direct de `backup_codes`, **sans redirection** : les codes ne passent ni par le flash ni par la session. | `test/controllers/identity/second_factor_enrollments_controller_test.rb` |
| `app/controllers/identity/pin_recoveries_controller.rb` | `allow_unauthenticated_access`. `rate_limit to: 5, within: 1.minute, by: ip`. `create` : `RedeemPinRecoveryCode`. En cas de succès, redirection vers la connexion avec « Votre nouveau PIN est enregistré. Connectez-vous. » | `test/controllers/identity/pin_recoveries_controller_test.rb` |
| `app/controllers/identity/pending_accounts_controller.rb` | `show` : écran de sortie, élève sans classe ou enseignant sans école. **Ne redirige jamais**, même si le compte est complet : un simple lien « Aller à mon accueil » y figure. | `test/controllers/identity/pending_accounts_controller_test.rb` : aucune boucle (ID-13) |
| `app/views/identity/sessions/new.html.erb` | Deux colonnes, reprises de `⟨ancienne⟩ views/identity/sessions/new.html.erb`. Contact en `telephone_field`, `maxlength` 14 pour accepter l'indicatif, placeholder « 07 00 00 00 00 ». PIN en `password_field`, `inputmode="numeric"`, `autocomplete="current-password"`. Lien « PIN oublié ? » vers `new_pin_recovery_path`. | (tests contrôleur) |
| `app/views/identity/second_factors/new.html.erb` | Champ code, lien « Utiliser un code de secours » (le même champ accepte les deux formats) | — |
| `app/views/identity/second_factor_enrollments/new.html.erb` | QR, secret, champ code | — |
| `app/views/identity/second_factor_enrollments/backup_codes.html.erb` | 10 codes, avertissement « affichés une seule fois », bouton « J'ai noté mes codes » vers `team_home_path` | — |
| `app/views/identity/pin_recoveries/new.html.erb` | Numéro, code à 6 chiffres, nouveau PIN, confirmation | — |
| `app/views/identity/pending_accounts/show.html.erb` | `ui_empty_state` selon le cas, bouton Déconnexion | — |
| `app/views/errors/forbidden.html.erb` | « Accès interdit. », lien vers l'accueil | — |
| `app/views/errors/not_found.html.erb` | « Page introuvable. » | — |
| `config/locales/fr.yml` | Clés **communes** : `errors.contact.format`, `errors.pin.*`, `errors.codes.{forbidden,not_found,invalid,conflict,locked,expired}`, `activemodel.attributes.dtos/*` (libellés de champ : Nom, Prénom(s), Genre, Numéro de contact, PIN…), `content_status.{draft,published,archived}` (« Brouillon — visible uniquement par l'équipe », « Publié », « Archivé »), `badges.{gold,silver,bronze,none}`, `materials.categories.*`, `genders.*` | `test/i18n/locale_files_test.rb` : tout fichier de `config/locales/` est sous `fr:`, aucune clé en double entre fichiers, et les termes « Habilité », « Habiletés » et « Notions clés » sont absents (F-32) |
| `config/locales/identity/sessions.fr.yml` | Écran de connexion, toasts de connexion et de déconnexion | — |
| `config/locales/identity/second_factors.fr.yml` | Second facteur et enrôlement | — |
| `config/locales/identity/pin_recoveries.fr.yml` | Récupération du PIN | — |
| `config/locales/identity/pending_accounts.fr.yml` | Écrans de sortie | — |
| `config/locales/errors/pages.fr.yml` | Pages 403 et 404 | — |

**Terme de la fiche (F-32).** Le plan retient **« Fiche »** au singulier et **« Fiches »** au pluriel, conformément au glossaire (« Fiche essentielle »), sous réserve de l'UDR-0007. Si l'UDR-0007 tranche autrement, seules les valeurs de locale changent, jamais les clés.

### 0.10 Support de test et garde-fous d'architecture

| Fichier | Contenu | Test |
|---|---|---|
| `test/test_helper.rb` | Charge `test/support/**/*.rb`, `parallelize(workers: :number_of_processors)`, inclut les fabriques et `AuthenticationHelper` dans `ActiveSupport::TestCase` et `ActionDispatch::IntegrationTest`. `setup { Rails.cache.clear }`. | — |
| `test/application_system_test_case.rb` | `driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]`, variante mobile `[390, 844]` par `with_mobile_viewport`, inclut `SystemAuthenticationHelper` | — |
| `test/support/factories/identity.rb` | `create_user(role:, contact: sequence, pin: "2468", last_name:, first_names:, gender:)`, `create_student(classroom: nil, primary: true)`, `create_teacher(school:, material:, onboarded: true, classrooms: [])`, `create_team_member(otp_enabled: true)` (renvoie aussi le secret), `create_team_invitation(...)`, `create_pin_recovery_code(user:, issued_by:, code: "123456")` | — |
| `test/support/factories/school.rb` | `create_drena(name:)`, `create_school(drena:, name:)` | — |
| `test/support/factories/classroom.rb` | `create_classroom(school:, level:, series: nil, name:, join_code: nil)`, `create_assignment(classroom:, assignable:, status: "active", by:)` | — |
| `test/support/factories/catalog.rb` | `create_level`, `create_series`, `create_material(category:, icon:)`, `create_course(status: "published", …)`, `create_essential(course:, status: "published")` | — |
| `test/support/factories/assessment.rb` | `create_exercise(essential:, status: "published", questions: 2)` (1 Vrai/Faux et 1 choix unique par défaut), `create_session(student:, exercise:, status:)`, `create_attempt(session:, question:, correct:)`, `create_badge(...)` | — |
| `test/support/authentication_helper.rb` | `sign_in_as(user, pin: "2468")` en test d'intégration. Pour une team, il saisit le TOTP courant à partir du secret de la fabrique. `sign_out`. | — |
| `test/support/system_authentication_helper.rb` | Même chose, en remplissant les formulaires réels | — |
| `test/support/caching_helper.rb` | `with_fragment_caching { … }` : active `perform_caching` et un `memory_store` neuf, puis restaure | — |

**Garde-fous d'architecture.**

| Test | Ce qu'il vérifie |
|---|---|
| `test/architecture/domain_purity_test.rb` | Aucun fichier de `app/domain/` ne contient `ActiveRecord`, `ApplicationRecord`, `Orm::` ni `Repositories::` (chantier `dette-contrats-ports-et-injection`). |
| `test/architecture/port_contracts_test.rb` | Pour chaque module de `app/domain/ports/**` : chaque méthode lève `NotImplementedError` quand elle est appelée sur un objet vide qui inclut le port. Il existe exactement un implémenteur dans `app/infrastructure/`. Cet implémenteur définit chaque méthode avec les **mêmes paramètres** (`Method#parameters`). |
| `test/architecture/no_arbitrary_css_test.rb` | Aucune vue de `app/views/` ne contient une classe `[…]` ni une couleur `#hex` (UDR-0005). |
| `test/architecture/no_third_party_cdn_test.rb` | Aucune vue ni aucun layout ne référence `cdn.`, `unpkg`, `jsdelivr` ni `googleapis` (TR-41, ADR-0049). |

---
## Lots verticaux — règles communes

Chaque lot vertical :

- part de `feature/boucle-pedagogique`, **après** le merge du Lot 0. Sa branche s'appelle `feature/boucle-pedagogique-lot-<id>`, et il travaille dans son propre worktree, avec sa propre base ;
- reçoit le **brief standard** de [`boucle-de-travail.md`](../refonte-application/boucle-de-travail.md) §5 : fichiers autorisés, tests rouges d'abord, sortie `bin/ci` ;
- **ne modifie aucun fichier du Lot 0**. Cela vaut pour les ports, les entités, les policies, les DTO, les repositories, les routes, les fabriques, `fr.yml`, le layout et les composants. Un besoin de changement de contrat **arrête le lot** : l'agent le signale à l'orchestrateur, qui décide ;
- câble ses dépendances dans le contrôleur (`UseCases::X.new(port: Repositories::…new, policy: Policies::…new(…))`). Le domaine ne voit jamais un repository ;
- construit ses écrans avec les composants `ui_*` du Lot 0c (`ui_page_header`, `ui_card`, `ui_button`, `ui_field`, `ui_badge`, `ui_empty_state`, `ui_toast`/`turbo_stream_toast`…). Il reproduit **la structure et le parcours** des écrans de l'ancienne application cités, pas leur CSS ;
- écrit ses textes dans **sa** locale `config/locales/<ctx>/<écran>.fr.yml`, accessibles par `t(".clé")` ;
- met l'en-tête HITL de 3 lignes sur chaque fichier créé dans `app/` ;
- écrit son UDR sous le numéro réservé. Le lot ne touche pas au README des UDR ;
- vise 100 % de couverture, lignes et branches, sur ses fichiers, sans `:nocov:`.

**Où lire l'inventaire.** Les fiches d'inventaire sont rangées par contexte :

| Contexte | Fichiers |
|---|---|
| Identity | `inventaire/identity-communication.md` · `inventaire/complements-identity-communication.md` |
| Classroom et School | `inventaire/classroom-school.md` · `inventaire/complements-school-classroom.md` |
| Catalog | `inventaire/catalog.md` · `inventaire/complements-catalog.md` |
| Assessment | `inventaire/assessment.md` · `inventaire/complements-assessment.md` |
| Transverse | `inventaire/transverse.md` · `inventaire/complements-transverse.md` · `inventaire/ui-design-system.md` |
| Sécurité | [`securite.md`](../refonte-application/securite.md), par numéro |

---

## Lot A1 — Inscription élève par code de classe

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/identity/register_student.rb`
    - `JoinPolicy` et le DTO sont appliqués d'abord.
    - Le code est normalisé par `JoinCode.normalize`, puis la classe est cherchée. Si elle est absente : `:invalid` sur `join_code`.
    - Le PIN passe `Pin.valid_for?`, et le numéro passe `users.contact_taken?`.
    - L'inscription se fait par `registrations.register_student`, en une transaction. L'adhésion est `primary` avec `joined_at`.
    - Le rôle est **imposé** à `student`.
  - `app/infrastructure/queries/classroom/join_code_preview_query.rb`
    - Renvoie `Data(classroom_name, school_name)` ou `nil`. Rien d'autre : ni identifiant, ni niveau, ni enseignant.
  - `app/controllers/identity/student_registrations_controller.rb`
    - `allow_unauthenticated_access`. `rate_limit to: 5, within: 1.minute, only: :create`.
    - `new` répond sur `/student-signup` et sur `/c/:join_code`. Code inconnu : redirection vers `new_student_registration_path` avec « Code de classe invalide. ».
    - `create` : `start_session`, puis `student_home_path` avec « Bienvenue sur Lnclass ! ».
    - Un visiteur déjà connecté est envoyé vers `redirect_to_home`.
  - `app/controllers/classroom/api/join_code_lookups_controller.rb`
    - `allow_unauthenticated_access`. `rate_limit to: 10, within: 1.minute, by: ip`.
    - 400 si le code est vide, 404 s'il est inconnu, sinon 200 avec `{ classroom_name, school_name }`.
  - `app/views/identity/student_registrations/new.html.erb`
  - `app/views/identity/student_registrations/_form.html.erb`
    - Champs Nom, Prénom(s), genre en radios, numéro, PIN (`password`, 4 chiffres, `inputmode numeric`) et code de classe.
  - `app/views/identity/student_registrations/_classroom_preview.html.erb`
    - Bandeau « Classe — Établissement ».
  - `app/javascript/controllers/identity/join_code_preview_controller.js`
    - Appelle l'API après 5 caractères saisis et affiche le bandeau ou « Code de classe invalide ».
  - `config/locales/identity/student_registrations.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/identity/register_student_test.rb`
  - `test/infrastructure/queries/classroom/join_code_preview_query_test.rb`
  - `test/controllers/identity/student_registrations_controller_test.rb`
    - TR-cadre-1 (paramètre `role=team` ignoré), PIN vide, PIN = 4 derniers chiffres, numéro pris → 422, `/c/<inconnu>`, atomicité.
  - `test/controllers/classroom/api/join_code_lookups_controller_test.rb`
    - Clés JSON exactes, 400, 404, 429.
- **Done quand**   : un visiteur ouvre `/c/KFM37`, s'inscrit et arrive connecté sur `/students` avec le toast. Les critères ID-01, ID-02, ID-07, CL-06, CL-07 et CL-08 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/students/registrations/new.html.erb`
  - `⟨ancienne⟩ javascript/controllers/classrooms_controller.js`, pour le comportement du lookup
  - captures `docs/design/captures/original/student-signup--desktop.png` et `student-signup--mobile.png`
- **Fiches d'inventaire** : ID-01, ID-02, ID-07, ID-08 (partie écartée), CL-06, CL-07, CL-08. Sécurité n° 5.
- **Non-régression** :
  - la cascade école + niveau → classe n'existe pas ;
  - le PIN n'est jamais dérivé du numéro ;
  - la création n'est jamais partielle ;
  - l'API ne renvoie jamais plus que le nom de la classe et celui de l'établissement, et elle est limitée en débit.
- **UDR**          : UDR-0009 — Inscription élève

---

## Lot A2 — Accueil élève

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_home_query.rb`
    - Renvoie `Data(school_name, level_name, classroom_name, classmates_count, exercises:, recent_sessions:)`.
    - `exercises` contient les exercices **assignés actifs** à la classe principale **et publiés**, avec pour chacun `slug, title, material, badge_level, best_score_percent` (maximum de `score_percent` sur les sessions `completed`), `completed_count` et `in_progress_public_id`.
    - `recent_sessions` contient les 10 dernières sessions `completed`.
  - `app/controllers/classroom/student_homes_controller.rb`
    - Hérite d'`AuthenticatedController`, avec `allow_roles :student`. Sans classe principale : redirection vers `pending_account_path`, un seul saut.
  - `app/views/classroom/student_homes/show.html.erb`
    - Sections dans l'ordre de `NavigationHelper::HOME_SECTIONS[:student]` : à faire, classe, cours.
  - `app/views/classroom/student_homes/_classroom_card.html.erb`
  - `app/views/classroom/student_homes/_assigned_exercise.html.erb`
    - Matière par `material_badge`, badge par `badge_label`, meilleur score, nombre de tentatives, bouton « Commencer » ou « Reprendre ».
  - `app/views/classroom/student_homes/_recent_activity.html.erb`
  - `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_home_query_test.rb`
    - Exercice retiré de la classe, archivé ou brouillon : absent. Meilleur score. Compteurs. Classe principale seulement.
  - `test/controllers/classroom/student_homes_controller_test.rb`
    - 200. Sans classe : une redirection vers l'écran de sortie. Un enseignant reçoit 403.
- **Done quand**   : un élève connecté voit ses exercices assignés et leur progression. Les critères CL-23, TR-04 et AS-36 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/students/feed/index.html.erb`
  - `⟨ancienne⟩ views/students/feed/content/_feed_header.html.erb`, `_classroom.html.erb`, `_exercises.html.erb`, `_activities.html.erb`, `_empty_state.html.erb`
  - `⟨ancienne⟩ views/components/_exercise_card.html.erb` et `_exercise_badge.html.erb`
- **Fiches d'inventaire** : TR-04, CL-23, AS-36, TR-02 (élève sans classe).
- **Non-régression** :
  - pas d'accueil sans test système : le test est au Lot E ;
  - pas de boucle de redirection pour l'élève sans classe ;
  - pas d'exercice non publié listé.
- **UDR**          : UDR-0010 — Accueil élève

---

## Lot A3 — Ma classe (élève)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_classroom_query.rb`
    - Renvoie `Data(classroom_name, level_name, series_name, school_name, courses:)`.
    - `courses` contient les cours assignés **actifs et publiés**, avec `slug, name, subtitle, material, essentials_count` (fiches publiées).
    - **Ni code, ni liste nominative.**
  - `app/controllers/classroom/student_classrooms_controller.rb`
    - `allow_roles :student`.
  - `app/views/classroom/student_classrooms/show.html.erb`
  - `app/views/classroom/student_classrooms/_assigned_course.html.erb`
  - `config/locales/classroom/student_classrooms.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_classroom_query_test.rb`
  - `test/controllers/classroom/student_classrooms_controller_test.rb`
    - Le HTML ne contient ni le code ni le nom d'un autre élève.
- **Done quand**   : les critères CL-22 et CL-10 (accès élève) sont verts.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/students/classroom/show.html.erb`, `⟨ancienne⟩ views/students/feed/content/_courses.html.erb`
- **Fiches d'inventaire** : CL-22, CL-10 (volet élève).
- **Non-régression** : aucun cours retiré ou archivé affiché.
- **UDR**          : UDR-0011 — Ma classe

---

## Lot A4 — Landing (contenu V1)

- **Couche**       : ui
- **Fichiers**     :
  - `app/views/homepage/index.html.erb`
    - Fichier existant du V0, modifié. Deux entrées, « Je suis élève » et « Je suis enseignant », qui ouvrent chacune un `ui_modal`.
  - `app/views/homepage/_role_modal.html.erb`
    - Liens « Se connecter » vers `new_session_path`, et « Créer un compte » vers `new_student_registration_path` ou `new_teacher_registration_path`.
  - `config/locales/homepage/index.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/controllers/homepage_controller_test.rb`
    - Fichier existant, étendu. Les deux entrées et leurs liens sont présents. Chaque `href` de la page est reconnu par le routeur (`Rails.application.routes.recognize_path`).
- **Done quand**   : le critère TR-01 est vert, et aucun lien de la landing ne pointe vers une chaîne littérale.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/homepage/index.html.erb`
  - `⟨ancienne⟩ javascript/controllers/homepage_student_modal_controller.js` et `homepage_teacher_modal_controller.js`
  - captures `original/accueil--desktop.png`, `accueil--mobile.png`, `accueil-modale-eleve--desktop.png`, `accueil-modale-eleve--mobile.png`, `accueil-modale-enseignant--desktop.png` et `accueil-modale-enseignant--mobile.png`
  - Les tokens restent ceux de la landing V0.
- **Fiches d'inventaire** : TR-01, TR-03 (le lien « Espace Etabl. » n'est **pas** repris : V2).
- **Non-régression** : aucun lien relatif vers une route inexistante (TR-03).
- **UDR**          : UDR-0012 — Landing, modales de rôle

---

## Lot B1 — Catalogue et lecture d'un cours

- **Couche**       : domaine (use case) + infrastructure (queries) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/catalog/read_course.rb`
    - `courses.find_by_slug`, puis `ReadPublishedPolicy`.
    - Un refus pour un non-équipe devient **`:not_found`** : un brouillon n'existe pas pour lui.
  - `app/infrastructure/queries/catalog/course_catalog_query.rb`
    - Renvoie `[Data(slug, name, subtitle, level_name, series_name, material, status)]`.
    - Publiés seulement, sauf pour l'équipe. Tri par matière, niveau, nom.
  - `app/infrastructure/queries/catalog/course_detail_query.rb`
    - Pour un cours : les fiches (publiées, ou toutes pour l'équipe) avec `slug, name, subtitle, exercises_count`, puis le fil d'Ariane.
  - `app/controllers/catalog/courses_controller.rb`
    - `index`, `show`, pour tous les rôles connectés.
  - `app/views/catalog/courses/index.html.erb`
    - Grille de cartes. Bouton « Nouveau cours » pour l'équipe seulement, vers `new_course_path`.
  - `app/views/catalog/courses/show.html.erb`
    - Fil d'Ariane, badges niveau, série et matière, contenu riche dans `data-controller="math"`, section « Fiches ».
  - `app/views/catalog/courses/_course_card.html.erb`
  - `app/views/catalog/courses/_essential_row.html.erb`
  - `app/views/catalog/courses/_role_actions.html.erb`
    - Pour l'équipe : un `ui_dropdown` « Modifier » vers `edit_course_path`, « Archiver » vers `archive_course_path` (PATCH) et « Nouvelle fiche » vers `new_course_essential_path`.
    - Pour l'enseignant : « Assigner à mes classes » vers `course_assignments_path` (CA-27, point d'entrée).
  - `config/locales/catalog/courses.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/catalog/read_course_test.rb`
  - `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
  - `test/infrastructure/queries/catalog/course_detail_query_test.rb`
  - `test/controllers/catalog/courses_controller_test.rb`
    - Un brouillon ouvert par un élève ou un enseignant renvoie 404. Le bouton « Nouveau cours » n'apparaît que pour l'équipe. Le lien « Assigner à mes classes » n'apparaît que pour l'enseignant.
- **Done quand**   : les critères CA-01, CA-04, CA-10, CA-26 et TR-41 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/catalog/courses/index.html.erb`, `show.html.erb` et `_course.html.erb`
  - `⟨ancienne⟩ views/components/courses/_course_card.html.erb`
  - `⟨ancienne⟩ javascript/controllers/math_controller.js`
  - captures `teams/Lnclass - Les cours (23.09.2026 16_14).png` et `teams/Lnclass - Génétique Et évolution (23.09.2026 16_14).png`
- **Fiches d'inventaire** : CA-01, CA-04, CA-10, CA-26, CA-27 (point d'entrée), TR-41.
- **Non-régression** :
  - un brouillon n'est jamais lisible par URL directe ;
  - la couleur d'une matière vient de sa catégorie, jamais de son nom ;
  - aucun KaTeX servi par un CDN.
- **UDR**          : UDR-0013 — Catalogue et page cours

---

## Lot B2 — Gestion des cours (équipe)

- **Couche**       : domaine (use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/catalog/create_course.rb`
    - Enchaîne `ManageContentPolicy`, le DTO, `ReferentialRepositoryPort` (niveau, matière, `series_allowed?`), puis `name_taken?`.
    - Le statut initial est celui choisi. `published_at` est posé si l'on publie. `author_id` vaut `actor.user_id`.
  - `app/domain/use_cases/catalog/update_course.rb`
    - La transition de statut passe par `ContentStatus`.
  - `app/domain/use_cases/catalog/archive_course.rb`
    - `archive(at:)` et audit `content_archived`. Aucune écriture sur les fiches ni sur les assignations.
  - `app/controllers/catalog/course_editions_controller.rb`
    - `allow_roles :team`. `new`, `create`, `edit`, `update`, `archive`.
  - `app/views/catalog/course_editions/new.html.erb`
  - `app/views/catalog/course_editions/edit.html.erb`
  - `app/views/catalog/course_editions/_form.html.erb`
    - Nom, sous-titre, niveau, série (filtrée par niveau côté serveur, avec `ReferentialOptionsQuery`), matière, statut avec libellés, et contenu `rich_text_area`.
    - Le statut n'offre que les transitions permises.
  - `config/locales/catalog/course_editions.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/catalog/create_course_test.rb`
  - `test/domain/use_cases/catalog/update_course_test.rb`
  - `test/domain/use_cases/catalog/archive_course_test.rb`
  - `test/controllers/catalog/course_editions_controller_test.rb`
    - Un élève ou un enseignant reçoit 403.
  - `test/integration/catalog/course_lifecycle_test.rb`
    - Créer, lire, modifier, publier, puis archiver, par le même agrégat (chantier `catalog-lecture-ecriture-incompatibles`). Le cours archivé garde ses fiches et ses assignations.
- **Done quand**   : les critères CA-05, CA-06 et CA-07 sont verts, et l'équipe crée un cours depuis le catalogue.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/courses/new.html.erb`, `edit.html.erb` et `_form.html.erb`
- **Fiches d'inventaire** : CA-05, CA-06, CA-07. Contradiction C-19 (feuille de route §4).
- **Non-régression** :
  - l'écran de création a un point d'entrée ;
  - le nom n'est pas passé en `titleize` ;
  - il n'y a pas deux familles d'entités ;
  - l'archivage ne détruit rien en cascade ;
  - le libellé « Brouillon » dit la vérité : visible par l'équipe.
- **UDR**          : UDR-0014 — Formulaire cours

---

## Lot B3 — Fiche : lecture et progression de l'élève

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/catalog/read_essential.rb`
    - `ReadPublishedPolicy` s'applique sur la fiche **et** sur son cours. Un refus renvoie `:not_found`.
  - `app/infrastructure/queries/catalog/essential_detail_query.rb`
    - Renvoie les exercices publiés, ou tous pour l'équipe. Pour un élève, chaque exercice porte `assigned_to_my_classroom`, `badge_level`, `best_score_percent` et `in_progress_public_id`.
  - `app/controllers/catalog/essentials_controller.rb`
    - `show`.
  - `app/views/catalog/essentials/show.html.erb`
    - Contenu riche avec KaTeX. Liste des exercices. Menu d'équipe « Modifier », « Archiver » et « Nouvel exercice » vers `new_essential_exercise_path`.
  - `app/views/catalog/essentials/_exercise_progress.html.erb`
    - Un exercice non assigné à la classe de l'élève s'affiche grisé, avec « Pas encore assigné par ton enseignant », sans bouton.
  - `config/locales/catalog/essentials.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/catalog/read_essential_test.rb`
  - `test/infrastructure/queries/catalog/essential_detail_query_test.rb`
  - `test/controllers/catalog/essentials_controller_test.rb`
- **Done quand**   : les critères CA-11 et AS-37 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/catalog/essentials/show.html.erb` et `_essential.html.erb`
  - captures `teams/Lnclass - Habilité _ Brassage Génétique Par La Méiose (23.09.2026 16_15).png` et `teams/Lnclass - Anomalies De La Méiose (23.09.2026 16_15).png`
  - Le mot « Habilité » des captures n'est **pas** repris (F-32).
- **Fiches d'inventaire** : CA-10, CA-11, AS-37.
- **Non-régression** : aucun exercice non publié listé à un élève.
- **UDR**          : UDR-0015 — Page fiche

---

## Lot B4 — Gestion des fiches (équipe)

- **Couche**       : domaine (use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/catalog/create_essential.rb`
    - Enchaîne `ManageContentPolicy`, le cours existant, puis `name_taken?` dans le cours.
  - `app/domain/use_cases/catalog/update_essential.rb`
  - `app/domain/use_cases/catalog/archive_essential.rb`
  - `app/controllers/catalog/essential_editions_controller.rb`
    - `allow_roles :team`.
  - `app/views/catalog/essential_editions/new.html.erb`
  - `app/views/catalog/essential_editions/edit.html.erb`
  - `app/views/catalog/essential_editions/_form.html.erb`
  - `config/locales/catalog/essential_editions.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/catalog/create_essential_test.rb`
  - `test/domain/use_cases/catalog/update_essential_test.rb`
  - `test/domain/use_cases/catalog/archive_essential_test.rb`
  - `test/controllers/catalog/essential_editions_controller_test.rb`
    - Un enseignant ou un élève reçoit 403 : l'ancienne application ouvrait la création à tout compte connecté.
- **Done quand**   : les critères CA-12, CA-13 et CA-14 sont verts.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/essentials/new.html.erb`, `edit.html.erb` et `_form.html.erb`
- **Fiches d'inventaire** : CA-12, CA-13, CA-14.
- **Non-régression** : la création n'est pas ouverte à tout compte connecté, et l'archivage ne détruit rien en cascade.
- **UDR**          : UDR-0016 — Formulaire fiche

---

## Lot B5 — Gestion des exercices (équipe)

- **Couche**       : domaine (use cases) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/use_cases/assessment/create_exercise.rb`
    - Enchaîne `ManageContentPolicy`, `ExerciseDto`, puis la construction de l'entité `Exercise` avec ses `Question` et `Answer`.
    - Les règles `Question::STRUCTURE` s'appliquent. La publication exige au moins une question.
    - `exercises.create` : une seule transaction.
  - `app/domain/use_cases/assessment/update_exercise.rb`
    - Si `has_sessions?`, toute modification de question renvoie `:invalid`, avec le détail `questions_locked`.
  - `app/domain/use_cases/assessment/archive_exercise.rb`
    - Audit `content_archived`.
  - `app/controllers/assessment/exercise_editions_controller.rb`
    - `allow_roles :team`. Il transforme `questions_attributes` avec `ExerciseDto.from_params`.
  - `app/views/assessment/exercise_editions/new.html.erb`
  - `app/views/assessment/exercise_editions/edit.html.erb`
  - `app/views/assessment/exercise_editions/_form.html.erb`
    - Titre, description, type (fixation ou évaluation), statut, puis les questions.
    - Si les questions sont verrouillées, un bandeau l'explique et les champs sont en lecture seule.
  - `app/views/assessment/exercise_editions/_question_fields.html.erb`
    - Contenu, explication, type, réponses.
  - `app/views/assessment/exercise_editions/_answer_fields.html.erb`
    - Contenu et case « Bonne réponse ».
  - `app/javascript/controllers/assessment/nested_form_controller.js`
    - « + Ajouter une question », « + Ajouter une réponse », « Retirer ».
    - Il clone des `<template>` rendus par le serveur et remplace l'index `NEW_RECORD` par un horodatage.
  - `config/locales/assessment/exercise_editions.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/assessment/create_exercise_test.rb`
    - Les quatre types de question, en cas valide et invalide. Transaction. Titre sans `titleize`.
  - `test/domain/use_cases/assessment/update_exercise_test.rb`
  - `test/domain/use_cases/assessment/archive_exercise_test.rb`
  - `test/controllers/assessment/exercise_editions_controller_test.rb`
    - TR-cadre-6 : l'archivage conserve sessions, tentatives et badges. Un non-équipe reçoit 403.
  - `test/system/assessment/exercise_form_test.rb`
    - Ajouter 2 questions et 5 réponses sans rechargement, enregistrer, et relire l'exercice avec ses questions.
- **Done quand**   : l'équipe crée un exercice de 2 questions qui est relu identique. Les critères AS-03, AS-04 et AS-05 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercises/new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_question_fields.html.erb` et `_answer_fields.html.erb`
  - Le contrôleur Stimulus `nested-form` **n'existait pas** : il est à construire.
- **Fiches d'inventaire** : AS-03, AS-04, AS-05. Complément assessment §3 (C-08 à C-11).
- **Non-régression** :
  - « + Ajouter une question » n'est pas inerte ;
  - les questions sont bien persistées ;
  - le titre n'est pas passé en `titleize` ;
  - l'archivage ne détruit ni les sessions, ni les tentatives, ni les badges.
- **UDR**          : UDR-0017 — Formulaire exercice

---

## Lot B6 — Accueil équipe (minimal)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/catalog/team_home_query.rb`
    - Renvoie `Data(drenas_count, schools_count, levels: [Data(name, series_names)], recent_courses: [5], recent_exercises: [5])`.
    - Les listes récentes sont triées par `updated_at`, tous statuts confondus.
  - `app/controllers/catalog/team_homes_controller.rb`
    - `allow_roles :team`.
  - `app/views/catalog/team_homes/show.html.erb`
    - Sections dans l'ordre de `HOME_SECTIONS[:team]` : régions, niveaux, activité.
  - `app/views/catalog/team_homes/_shortcuts.html.erb`
    - « Nouveau cours » vers `new_course_path`, « Nouvelle classe » vers `new_classroom_path`, « Inviter un membre » vers `new_team_invitation_path` et « Débloquer un compte » vers `team_account_lookup_path`.
  - `app/views/catalog/team_homes/_recent_content.html.erb`
  - `config/locales/catalog/team_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/queries/catalog/team_home_query_test.rb`
  - `test/controllers/catalog/team_homes_controller_test.rb`
- **Done quand**   : le critère TR-09 est vert.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teams/feed/index.html.erb`
  - `⟨ancienne⟩ views/teams/feed/content/_feed_header.html.erb`, `_drenas.html.erb`, `_levels.html.erb` et `_activities.html.erb`
  - captures `teams/Team-feed.png` et `teams/Team - DRENA.png`
  - `teams/Lnclass - Tableau de Bord Team.png` est en V4 et sert seulement de référence visuelle.
- **Fiches d'inventaire** : TR-09. TR-10 est hors périmètre (V4).
- **Non-régression** : l'écran lit la vraie table des cours, pas une constante `Orm` disparue. Le test système est au Lot E.
- **UDR**          : UDR-0018 — Accueil équipe

---

## Lot B7 — Invitation d'un membre de l'équipe (F-16)

- **Couche**       : domaine (use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/identity/invite_team_member.rb`
    - `InviteTeamPolicy`. Le numéro est normalisé, puis refusé s'il appartient déjà à un compte ou s'il a une invitation en cours (`:conflict`).
    - Génère le jeton, stocke son digest avec `TeamInvitation::TTL`, écrit l'audit `team_invitation_created`.
    - Renvoie l'URL d'acceptation en clair, une seule fois.
  - `app/domain/use_cases/identity/accept_team_invitation.rb`
    - Cherche par le digest du jeton et vérifie `acceptable?`. Sinon, renvoie `:expired`.
    - Contrôle le PIN, puis appelle `registrations.register_team_member`, qui crée l'utilisateur team et marque l'invitation acceptée.
    - Écrit l'audit `team_invitation_accepted`.
    - Le compte créé n'a **pas** de second facteur : il l'enrôle à sa première connexion.
  - `app/controllers/identity/team_invitations_controller.rb`
    - `allow_roles :team`. `create` rend directement la vue `created`, avec le lien : pas de redirection, pas de flash.
  - `app/controllers/identity/team_invitation_acceptances_controller.rb`
    - `allow_unauthenticated_access`, `rate_limit to: 5, within: 1.minute`.
  - `app/views/identity/team_invitations/new.html.erb`
  - `app/views/identity/team_invitations/created.html.erb`
    - Le lien s'affiche une fois, avec un bouton « Copier ».
  - `app/views/identity/team_invitation_acceptances/new.html.erb`
    - Nom et Prénom(s) pré-remplis en lecture seule, genre, PIN et confirmation.
  - `config/locales/identity/team_invitations.fr.yml`
  - `config/locales/identity/team_invitation_acceptances.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/identity/invite_team_member_test.rb`
  - `test/domain/use_cases/identity/accept_team_invitation_test.rb`
  - `test/controllers/identity/team_invitations_controller_test.rb`
  - `test/controllers/identity/team_invitation_acceptances_controller_test.rb`
    - Lien expiré, lien déjà utilisé, et `/team-signup` qui renvoie 404.
- **Done quand**   : le critère F-16 est vert, et un compte invité enrôle son TOTP puis arrive sur `/teams`.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teams/registrations/new.html.erb` sert de référence visuelle pour la page d'acceptation seulement : la route publique n'est pas reprise.
  - captures `original/team-signup--desktop.png`, `original/team-signup--mobile.png` et `teams/screencapture-localhost-3000-team-signup-2026-09-23-16_30_25.png`
- **Fiches d'inventaire** : ID-04 (écartée, remplacée), F-16.
- **Non-régression** : aucune route publique ne crée un compte team.
- **UDR**          : UDR-0019 — Invitation équipe

---

## Lot B8 — Débloquer un compte (récupération assistée, côté émission)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/identity/account_lookup_query.rb`
    - Recherche par numéro **exact** après normalisation. Renvoie `Data(public_id, full_name, role, classroom_name)` ou `nil`.
    - Pas de recherche partielle : ce n'est pas un annuaire, qui reste en V2.
  - `app/controllers/identity/account_lookups_controller.rb`
    - `allow_roles :team`. `show` avec `?contact=`.
  - `app/controllers/identity/pin_recovery_codes_controller.rb`
    - `allow_roles :team, :teacher`. `rate_limit to: 10, within: 1.minute, by: current_actor.user_id`.
    - `create` appelle `UseCases::Identity::IssuePinRecoveryCode`, puis rend `show` directement, avec le code et son heure d'expiration. Pas de redirection, pas de flash.
    - En cas de refus : 403.
  - `app/views/identity/account_lookups/show.html.erb`
  - `app/views/identity/pin_recovery_codes/show.html.erb`
    - Code en grands chiffres, avec « valable jusqu'à HH:MM » et la consigne à transmettre oralement.
  - `config/locales/identity/account_lookups.fr.yml`
  - `config/locales/identity/pin_recovery_codes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/queries/identity/account_lookup_query_test.rb`
  - `test/controllers/identity/account_lookups_controller_test.rb`
  - `test/controllers/identity/pin_recovery_codes_controller_test.rb`
    - Un enseignant sur un élève de sa classe obtient 200. Sur un élève d'une autre classe : 403. Un élève : 403. Une team sur son propre compte : 403. Le code n'apparaît ni dans le flash ni dans le journal (`filter_parameters`).
- **Done quand**   : le critère ID-15 (émission) est vert.
- **Écrans de l'ancienne application** : aucun, la fonction était absente. On suit UDR-0005 et UDR-0006.
- **Fiches d'inventaire** : ID-15. ADR-0032.
- **Non-régression** : un PIN perdu ne signifie plus un compte perdu.
- **UDR**          : UDR-0020 — Débloquer un compte

---

## Lot C1 — Détail d'un exercice

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/assessment/read_exercise.rb`
    - `ReadPublishedPolicy`, dont le refus renvoie `:not_found`.
    - Puis `RevealAnswersPolicy`, qui produit `reveal_answers: true/false`.
    - Renvoie l'exercice. **Si `reveal_answers` est faux, l'entité est reconstruite sans le champ `correct` de ses réponses** : la vue ne peut rien fuiter, même par erreur.
  - `app/infrastructure/queries/assessment/exercise_progress_query.rb`
    - Pour un élève : `badge_level`, `best_score_percent`, `completed_count`, `in_progress_public_id`, `startable`. `startable` est calculé par `StartSessionPolicy` et passé par le contrôleur.
  - `app/controllers/assessment/exercises_controller.rb`
    - `show`.
  - `app/views/assessment/exercises/show.html.erb`
    - Titre, description, nombre de questions, matière.
    - Pour l'élève : progression, puis « Commencer » (POST `exercise_sessions_path`) ou « Reprendre » (`exercise_session_path`) avec « Recommencer ».
    - Pour l'équipe : « Modifier » et « Archiver ».
  - `app/views/assessment/exercises/_questions_preview.html.erb`
    - Questions dans `data-controller="math"`. La marque de bonne réponse n'est rendue que si `reveal_answers` est vrai.
    - **Aucun `cache`** dans ce partial ni dans la vue.
  - `app/views/assessment/exercises/_student_progress.html.erb`
  - `config/locales/assessment/exercises.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/assessment/read_exercise_test.rb`
  - `test/infrastructure/queries/assessment/exercise_progress_query_test.rb`
  - `test/controllers/assessment/exercises_controller_test.rb`
  - `test/integration/assessment/answer_leak_test.rb`
    - TR-cadre-3. Sous `with_fragment_caching`, l'enseignant de la classe affiche l'exercice, puis l'élève l'affiche. Le HTML de l'élève ne contient ni la marque de bonne réponse ni l'identifiant d'une réponse correcte.
- **Done quand**   : les critères AS-02 et AS-39 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercises/show.html.erb`, `_questions_list.html.erb` et `_exercise.html.erb`
  - `⟨ancienne⟩ views/components/_question_card.html.erb`
- **Fiches d'inventaire** : AS-02, AS-39. Sécurité n° 29.
- **Non-régression** : aucune bonne réponse n'est servie par un cache partagé entre les rôles.
- **UDR**          : UDR-0021 — Page exercice

---

## Lot C2 — Jouer une session (démarrer, reprendre, répondre, correction immédiate)

- **Couche**       : domaine (use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/assessment/start_exercise_session.rb`
    - `StartSessionPolicy`. L'exercice doit avoir au moins une question.
    - `sessions.start` abandonne l'éventuelle session en cours, dans la même transaction, puis fixe `questions_total`.
  - `app/domain/use_cases/assessment/submit_question_attempt.rb`
    - Enchaîne `PlaySessionPolicy`, `AttemptDto`, puis vérifie que la question appartient à l'exercice et que les réponses appartiennent à la question. Sinon : `:invalid`.
    - `Question#correct?`, puis `sessions.record_attempt`.
    - Si le résultat est `:duplicate`, le use case renvoie `Result.failure(:conflict)` et rien n'est écrit.
  - `app/infrastructure/queries/assessment/session_play_query.rb`
    - Renvoie `Data(session_public_id, exercise_title, answered_count, questions_total, next_question:, last_feedback:)`.
    - `next_question` est la première question sans tentative, par position. Ses réponses sont **sans** `correct` et mélangées par `Random.new(session_id ^ question_id)`, un ordre stable pour la session.
    - `last_feedback` contient la question qui vient d'être répondue, avec `correct`, ses bonnes réponses et son explication. Le propriétaire a le droit de les voir après avoir répondu.
  - `app/controllers/assessment/exercise_sessions_controller.rb`
    - `allow_roles :student`. `create` redirige vers `show`. `show` : si toutes les questions sont répondues, il affiche le bouton « Voir mon résultat », qui poste vers `exercise_session_completion_path`.
  - `app/controllers/assessment/question_attempts_controller.rb`
    - `allow_roles :student`. `create` :
      - succès → Turbo Stream qui remplace le cadre de la question par la correction, puis par la suite ;
      - `:invalid` → 422 dans le cadre, avec le message ;
      - `:conflict` → redirection vers la session avec « Question déjà répondue. ».
  - `app/views/assessment/exercise_sessions/show.html.erb`
    - Barre de progression, puis `turbo_frame_tag "question"`.
  - `app/views/assessment/exercise_sessions/_question_card.html.erb`
    - Radios `answer_ids[]` limitées à une valeur pour les types `true_false` et `single_choice`. Cases à cocher avec « Plusieurs choix possibles » pour `multiple_*`. KaTeX.
  - `app/views/assessment/exercise_sessions/_feedback_card.html.erb`
    - « Bonne réponse » ou « Mauvaise réponse », les bonnes réponses, l'explication, puis « Question suivante » ou « Voir mon résultat ».
  - `app/views/assessment/exercise_sessions/_progress_bar.html.erb`
  - `app/views/assessment/question_attempts/create.turbo_stream.erb`
  - `config/locales/assessment/exercise_sessions.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/assessment/start_exercise_session_test.rb`
  - `test/domain/use_cases/assessment/submit_question_attempt_test.rb`
    - Égalité exacte des ensembles, sans crédit partiel. Réponse d'une autre question. Doublon.
  - `test/infrastructure/queries/assessment/session_play_query_test.rb`
    - Ordre stable. Aucun `correct` dans `next_question`.
  - `test/controllers/assessment/exercise_sessions_controller_test.rb`
    - Exercice non assigné : 403. Brouillon : 404. Reprise. « Recommencer » abandonne la session précédente.
  - `test/controllers/assessment/question_attempts_controller_test.rb`
    - Réponse vide en Turbo : 422 avec le message, pas de 500. Session d'un autre élève : 403.
  - `test/integration/assessment/double_submission_test.rb`
    - Deux soumissions de la même question laissent une seule tentative, et `answered_count` vaut 1 (sécurité n° 30).
- **Done quand**   : les critères AS-07, AS-08, AS-09 et AS-10 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercise_sessions/show.html.erb`, `_question_card.html.erb`, `_feedback_card.html.erb` et `update.turbo_stream.erb`
- **Fiches d'inventaire** : AS-07, AS-08, AS-09, AS-10. Complément assessment §3 et §4 (E-01 à E-25). Sécurité n° 30.
- **Non-régression** :
  - on ne peut pas soumettre à nouveau une question après avoir vu le corrigé ;
  - un doublon n'est jamais compté ;
  - une réponse vide ne produit jamais de 500.
- **UDR**          : UDR-0022 — Session d'exercice

---

## Lot C3 — Clôture, résultat et badge

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/use_cases/assessment/complete_exercise_session.rb`
    - Commence par `PlaySessionPolicy`. Une session déjà terminée renvoie `Result.success`, de façon idempotente, et le contrôleur affiche le résultat.
    - Les étapes suivantes :
      1. Si toutes les questions n'ont pas de réponse, `ExerciseSession#complete` renvoie `:invalid`.
      2. `correct_count` est recalculé à partir des tentatives : c'est la source de vérité.
      3. `BadgeScale.level_for(score)`. Si `better?` que le badge existant, `badges.save`.
      4. `sessions.complete`.
    - Les étapes 3 et 4 se font dans une seule transaction, par le repository de session.
  - `app/infrastructure/queries/assessment/session_result_query.rb`
    - Renvoie `Data(exercise, score_percent, correct_count, questions_total, badge_level, earned_now, passed, perfect, review:)`.
    - `review` contient, pour chaque question, la réponse choisie, les bonnes réponses et l'explication.
  - `app/controllers/assessment/session_completions_controller.rb`
    - `allow_roles :student`. `create` : succès → `exercise_session_result_path`. `:invalid` → retour à la session, sur la question manquante.
  - `app/controllers/assessment/session_results_controller.rb`
    - `show`. Il appelle `ReadSessionResult` (fichier suivant), puis la query. Un refus donne 403 avec « Accès interdit. ».
  - `app/domain/use_cases/assessment/read_session_result.rb`
    - `sessions.find_by_public_id` : absente → `:not_found`. Puis `ReadSessionPolicy` : refus → `:forbidden`. La session doit être `completed`, sinon `:invalid`, et le contrôleur renvoie vers la session.
  - `app/views/assessment/session_results/show.html.erb`
    - Au-dessus du seuil : « Félicitations ! » avec `data-controller="assessment--confetti"` pendant 3 s. En dessous : « Courage ! ».
    - Affiche la note n/total, le pourcentage, puis le badge ou « Non acquis ».
    - « Recommencer » si le score est inférieur à 100, en POST vers `exercise_sessions_path`.
    - Retour vers la fiche.
  - `app/views/assessment/session_results/_question_review.html.erb`
  - `app/views/assessment/session_results/_badge.html.erb`
  - `app/javascript/controllers/assessment/confetti_controller.js`
    - Animation en CSS et en JS local, sans bibliothèque externe. Elle est désactivée si `prefers-reduced-motion`.
  - `config/locales/assessment/session_results.fr.yml`
    - Reprend les messages d'encouragement du fichier `gamification.fr.yml` des locales de l'ancienne application.
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/assessment/complete_exercise_session_test.rb`
    - Barème aux bornes 49, 50, 79, 80, 99, 100. Remplacement strictement supérieur seulement. Clôture prématurée.
  - `test/domain/use_cases/assessment/read_session_result_test.rb`
  - `test/infrastructure/queries/assessment/session_result_query_test.rb`
  - `test/controllers/assessment/session_completions_controller_test.rb`
  - `test/controllers/assessment/session_results_controller_test.rb`
    - Autre élève : 403 avec « Accès interdit. ». Enseignant de la classe : 200. Équipe : 200.
- **Done quand**   : les critères AS-11, AS-12 et AS-13 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercise_sessions/result.html.erb` et `finish.turbo_stream.erb`
  - `⟨ancienne⟩ views/components/_exercise_badge.html.erb`
  - `⟨ancienne⟩ javascript/controllers/confetti_controller.js`
- **Fiches d'inventaire** : AS-11, AS-12, AS-13. ADR-0033 et ADR-0054.
- **Non-régression** :
  - le badge gagné est bien affiché ;
  - le résultat n'est pas réduit au seul pourcentage : il montre aussi la note et le badge ;
  - « Diamant » n'existe pas.
- **UDR**          : UDR-0023 — Résultat de session

---

## Lot D1 — Inscription enseignant et établissements d'une DRENA

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/use_cases/identity/register_teacher.rb`
    - Enchaîne le DTO, `schools.belongs_to_drena?`, `ReferentialRepositoryPort.material_exists?`, `Pin.valid_for?` et `contact_taken?`.
    - Puis `registrations.register_teacher`, en une transaction. `teacher_schools.primary` vaut vrai et `onboarded_at` reste `nil`.
    - Le rôle est imposé à `teacher`.
  - `app/infrastructure/queries/school/schools_by_drena_query.rb`
    - Renvoie `[Data(id, name)]` trié par nom, statut `active` seulement.
  - `app/controllers/identity/teacher_registrations_controller.rb`
    - `allow_unauthenticated_access`. `rate_limit to: 5, within: 1.minute, only: :create`.
    - `create` : `start_session`, puis `teacher_classrooms_path` avec « Bienvenue ! Sélectionnez vos classes pour commencer. ».
  - `app/controllers/school/api/schools_controller.rb`
    - `allow_unauthenticated_access`. `rate_limit to: 30, within: 1.minute, by: ip`. `drena_id` absent : 400.
  - `app/views/identity/teacher_registrations/new.html.erb`
  - `app/views/identity/teacher_registrations/_form.html.erb`
    - Nom, Prénom(s), genre, numéro, PIN, DRENA (filtre non persisté), établissement (liste rechargée) et matière.
    - Sans JS, un bouton « Afficher les établissements » soumet le formulaire en GET avec `drena_id` : c'est une amélioration progressive.
  - `app/javascript/controllers/school/schools_by_drena_controller.js`
  - `config/locales/identity/teacher_registrations.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/identity/register_teacher_test.rb`
    - École hors de la DRENA, rôle forcé, atomicité.
  - `test/infrastructure/queries/school/schools_by_drena_query_test.rb`
  - `test/controllers/identity/teacher_registrations_controller_test.rb`
    - TR-cadre-1, variante `role=team`.
  - `test/controllers/school/api/schools_controller_test.rb`
    - 400, tri, 429.
- **Done quand**   : les critères ID-03, ID-08 (DRENA vers établissements), SC-26 et SC-27 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/registrations/new.html.erb`
  - `⟨ancienne⟩ javascript/controllers/schools_controller.js`
  - captures `original/teacher-signup--desktop.png`, `original/teacher-signup--mobile.png`, `Teachers/screencapture-localhost-3000-teacher-signup-2026-09-23-16_36_39.png` et `Teachers/screencapture-localhost-3000-teacher-signup-2026-09-23-16_37_18.png`
- **Fiches d'inventaire** : ID-03, ID-08, SC-26, SC-27, TR-17 (formulaire « Prepa BAC » écarté).
- **Non-régression** : l'endpoint public est limité en débit.
- **UDR**          : UDR-0024 — Inscription enseignant

---

## Lot D2 — Déclarer ses classes (onboarding persisté)

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/use_cases/classroom/declare_teaching.rb`
    - Enchaîne `TeachPolicy` et `TeachingSelectionDto`.
    - `classrooms.ids_in_school(school_id: primary, public_ids:)` filtre les classes hors école. Si la liste filtrée est vide : `:invalid`.
    - Puis `teaching.replace_in_school`, et `teachers.mark_onboarded` si ce n'est pas déjà fait.
  - `app/infrastructure/queries/classroom/teaching_selection_query.rb`
    - Renvoie les classes de l'école principale, groupées par niveau et triées par position, puis par nom. Chacune porte `checked`.
  - `app/controllers/classroom/teaching_selections_controller.rb`
    - `allow_roles :teacher`. `edit` et `update`. Sans école principale : redirection vers `pending_account_path`.
    - Le bouton dit « Terminer la configuration » si le compte n'est pas configuré, sinon « Enregistrer ».
  - `app/views/classroom/teaching_selections/edit.html.erb`
    - « Quelles classes enseignez-vous ? », avec un compteur.
  - `app/views/classroom/teaching_selections/_level_group.html.erb`
    - « Tout cocher » par niveau.
  - `app/javascript/controllers/classroom/teaching_selection_controller.js`
  - `config/locales/classroom/teaching_selections.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/classroom/declare_teaching_test.rb`
    - Sélection vide. Classe d'une autre école ignorée. Remplacement limité à l'école principale.
  - `test/infrastructure/queries/classroom/teaching_selection_query_test.rb`
  - `test/controllers/classroom/teaching_selections_controller_test.rb`
  - `test/system/classroom/teaching_selection_test.rb`
    - « Tout cocher » et le compteur.
- **Done quand**   : les critères CL-09 et TR-08 (remplacé) sont verts, et un enseignant configuré n'est plus renvoyé sur cette page à sa connexion.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/classrooms/index.html.erb` et `_classroom_group.html.erb`
  - `⟨ancienne⟩ javascript/controllers/classroom_selection_controller.js` et `checkable_controller.js`
  - `⟨ancienne⟩ views/teachers/dashboard/setup.html.erb` sert de contre-exemple : c'est TR-08, écarté.
- **Fiches d'inventaire** : CL-09, TR-08, TR-02 (enseignant sans école).
- **Non-régression** :
  - le remplacement n'efface pas les classes des autres écoles ;
  - l'onboarding n'est pas déduit de `classrooms.empty?` ;
  - il n'y a pas de boucle de redirection.
- **UDR**          : UDR-0025 — Déclaration des classes

---

## Lot D3 — Accueil enseignant

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/teacher_home_query.rb`
    - Renvoie `Data(school_name, material_name, classrooms: [Data(public_id, name, level_name, students_count, assigned_exercises_count)])`.
  - `app/controllers/classroom/teacher_homes_controller.rb`
    - `allow_roles :teacher`. Si le compte n'est pas configuré : `redirect_to_home`, qui mène à la sélection.
  - `app/views/classroom/teacher_homes/show.html.erb`
    - Sections de `HOME_SECTIONS[:teacher]`. La section « activité » affiche un `ui_empty_state` « Bientôt » : c'est V3, sans lien mort.
  - `app/views/classroom/teacher_homes/_classroom_card.html.erb`
    - Lien vers `classroom_path`.
  - `config/locales/classroom/teacher_homes.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/infrastructure/queries/classroom/teacher_home_query_test.rb`
  - `test/controllers/classroom/teacher_homes_controller_test.rb`
- **Done quand**   : le critère TR-05 est vert.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/feed/index.html.erb`
  - `⟨ancienne⟩ views/teachers/feed/content/_feed_header.html.erb`, `_classrooms.html.erb` et `_levels.html.erb`
  - `_examen_dashboard.html.erb` est écarté (TR-06).
- **Fiches d'inventaire** : TR-05, TR-06 (écarté), TR-07 (écarté).
- **Non-régression** : aucun montant « Prepa » affiché ; l'accueil est couvert par un test système au Lot E.
- **UDR**          : UDR-0026 — Accueil enseignant

---

## Lot D4 — Page d'une classe (enseignant, équipe)

- **Couche**       : domaine (use case) + infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - Le use case `UseCases::Classroom::ReadClassroom` est au **Lot 0** (0.6), car D4, D5, D6 et D7 l'utilisent tous.
  - `app/infrastructure/queries/classroom/classroom_overview_query.rb`
    - Renvoie l'en-tête : nom, niveau, série, établissement, `JoinCode.display`, effectif.
    - Puis les cours assignés actifs et publiés, avec leur lien `classroom_course_path`.
    - Puis la liste des élèves (`public_id, full_name, contact`), **seulement si `show_roster`** : la query n'est pas appelée sinon.
  - `app/controllers/classroom/classrooms_controller.rb`
    - `allow_roles :teacher, :team`. Un élève est envoyé vers `student_classroom_path`.
  - `app/views/classroom/classrooms/show.html.erb`
  - `app/views/classroom/classrooms/_header.html.erb`
    - Code en majuscules et bouton « Copier ».
  - `app/views/classroom/classrooms/_assigned_courses.html.erb`
  - `app/views/classroom/classrooms/_roster.html.erb`
    - Une ligne par élève, avec le bouton « Générer un code de récupération », en POST vers `account_pin_recovery_codes_path(user_public_id)` (contrôleur du Lot B8).
  - `app/javascript/controllers/classroom/join_code_copy_controller.js`
  - `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : Lot 0. **Aucune dépendance de code à B8** : le formulaire vise une route du Lot 0. Le parcours complet est prouvé au Lot E.
- **Test associé** :
  - `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
  - `test/controllers/classroom/classrooms_controller_test.rb`
    - La page répond 200 avec un exercice assigné. Code en majuscules.
  - `test/integration/classroom/foreign_teacher_access_test.rb`
    - TR-cadre-4 : 403, et le corps de la réponse ne contient ni le code ni un nom d'élève.
- **Done quand**   : les critères CL-10 et CL-04 (affichage) sont verts, avec TR-cadre-4.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/classrooms/show.html.erb`, `_student_row.html.erb` et `_course_assigned.html.erb`
  - `⟨ancienne⟩ views/classroom/classrooms/show.html.erb` et `_student.html.erb`
  - `⟨ancienne⟩ javascript/controllers/clipboard_controller.js`
  - capture `teams/Lnclass - Classe _ 6ème 1.png`
- **Fiches d'inventaire** : CL-10, CL-04, ID-15 (émission par l'enseignant).
- **Non-régression** :
  - la fiche de classe ne casse plus dès le premier exercice assigné ;
  - le code s'affiche toujours en majuscules ;
  - aucune donnée n'est servie à un enseignant hors de la classe.
- **UDR**          : UDR-0027 — Page classe

---

## Lot D5 — Assignation, et cours dans la classe

- **Couche**       : domaine (use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/classroom/assign_resource.rb`
    - Enchaîne `AssignmentDto`, la classe, `AssignPolicy`, puis `assignments.resolve_assignable`. Contenu absent ou non publié : `:not_found`.
    - Puis `find`, et soit `Assignment#reactivate`, soit une nouvelle assignation, et enfin `save`.
    - `assigned_by_id` vaut `actor.user_id` : un utilisateur, jamais un profil.
    - Déjà actif : succès idempotent, avec le détail `already: true` et le message « Exercice déjà assigné. ».
  - `app/domain/use_cases/classroom/unassign_resource.rb`
    - `archive` : la ligne n'est jamais supprimée.
  - `app/infrastructure/queries/classroom/classroom_course_query.rb`
    - Renvoie la classe, le cours, et ses fiches publiées avec `assigned` pour chacune et pour le cours.
  - `app/controllers/classroom/assignments_controller.rb`
    - `allow_roles :teacher, :team`.
    - `create` et `destroy` répondent **toujours en Turbo Stream** : `update.turbo_stream.erb` remplace le bouton et ajoute un toast. Jamais de 204.
    - En HTML, sans Turbo : redirection vers la page d'origine.
  - `app/controllers/classroom/classroom_courses_controller.rb`
    - `show`. Il appelle `UseCases::Classroom::ReadClassroom` (Lot 0), puis la query.
  - `app/views/classroom/assignments/_toggle.html.erb`
    - Bouton « Assigner », ou « Assigné » en vert avec l'action « Retirer ».
    - `id` vaut `dom_id_for(classroom, assignable)`, soit `"assignment_#{classroom.public_id}_#{type}_#{slug}"`.
    - Le partial est réutilisé par D6 et D7.
  - `app/views/classroom/assignments/update.turbo_stream.erb`
  - `app/views/classroom/classroom_courses/show.html.erb`
    - Fiches du cours, avec une bascule par fiche et une pour le cours.
  - `config/locales/classroom/assignments.fr.yml`
    - « %{name} ajouté à %{classroom}. », « %{name} retiré de %{classroom}. », « Exercice déjà assigné. » et « Exercice retiré de la classe. ».
  - `config/locales/classroom/classroom_courses.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/classroom/assign_resource_test.rb`
    - Assigner, réassigner une ressource archivée (réactivation), déjà actif, contenu non publié, classe non enseignée.
  - `test/domain/use_cases/classroom/unassign_resource_test.rb`
  - `test/infrastructure/queries/classroom/classroom_course_query_test.rb`
  - `test/controllers/classroom/assignments_controller_test.rb`
    - Le type de contenu est `text/vnd.turbo-stream.html` et le bouton est remplacé. Autre classe : 403. Les trois types de ressource.
  - `test/controllers/classroom/classroom_courses_controller_test.rb`
- **Done quand**   : les critères CL-11, CL-16, CL-17, CL-20, AS-18 et AS-19 sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/classrooms/course.html.erb`
  - `⟨ancienne⟩ views/classroom/classrooms/_classroom_essential.html.erb` et `_classroom_exercise.html.erb`
- **Fiches d'inventaire** : CL-11, CL-16, CL-17, CL-20, AS-18, AS-19. Chantier `classroom-assignment-belongs-to-casses`.
- **Non-régression** :
  - pas de `RecordNotUnique` à la réassignation ;
  - pas de réponse 204 qui laisse le bouton inchangé ;
  - `assigned_by_id` n'est jamais un identifiant de profil.
- **UDR**          : UDR-0028 — Cours dans la classe et bascule d'assignation

---

## Lot D6 — Fiche dans la classe

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/classroom_essential_query.rb`
    - Renvoie la classe, la fiche, et ses exercices publiés avec `assigned` et `questions_count`.
  - `app/controllers/classroom/classroom_essentials_controller.rb`
    - `show`, via `ReadClassroom`.
  - `app/views/classroom/classroom_essentials/show.html.erb`
    - Rend la bascule de D5 pour chaque exercice.
  - `config/locales/classroom/classroom_essentials.fr.yml`
- **Dépend de**    : Lot 0 et **Lot D5** (partial `_toggle` et contrôleur d'assignation)
- **Test associé** :
  - `test/infrastructure/queries/classroom/classroom_essential_query_test.rb`
  - `test/controllers/classroom/classroom_essentials_controller_test.rb`
- **Done quand**   : les critères CL-12 et AS-20 sont verts.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teachers/classrooms/essential.html.erb`
- **Fiches d'inventaire** : CL-12, AS-20.
- **Non-régression** : aucun exercice non publié n'est proposé à l'assignation.
- **UDR**          : UDR-0029 — Fiche dans la classe

---

## Lot D7 — Assigner un cours depuis sa page (CA-27)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/course_assignment_targets_query.rb`
    - Renvoie les classes enseignées par l'enseignant connecté, avec `assigned` pour ce cours.
  - `app/controllers/classroom/course_assignments_controller.rb`
    - `allow_roles :teacher`. `index`. Un cours non publié renvoie 404.
  - `app/views/classroom/course_assignments/index.html.erb`
    - Une ligne par classe, avec la bascule de D5.
  - `config/locales/classroom/course_assignments.fr.yml`
- **Dépend de**    : Lot 0 et **Lot D5**
- **Test associé** :
  - `test/infrastructure/queries/classroom/course_assignment_targets_query_test.rb`
  - `test/controllers/classroom/course_assignments_controller_test.rb`
- **Done quand**   : le critère CA-27 est vert : depuis la page cours (lien du Lot B1), l'enseignant assigne le cours à une classe.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/courses/show.html.erb`, dans la partie qui assignait le cours et dont le bouton était inatteignable.
- **Fiches d'inventaire** : CA-27.
- **Non-régression** : le bouton n'est plus inatteignable (`@teacher_classrooms` n'était jamais affecté).
- **UDR**          : UDR-0030 — Assigner un cours

---

## Lot D8 — Créer une classe (équipe)

- **Couche**       : domaine (use case) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/classroom/create_classroom.rb`
    - Enchaîne `ManageSchoolPolicy`, le DTO, l'école existante, le niveau, `series_allowed?` et `name_taken?`.
    - Puis `JoinCode.generate` et `classrooms.create`. En cas de `:conflict` sur `join_code`, le use case régénère le code, jusqu'à **5 essais**, puis renvoie `:conflict`.
    - Écrit l'audit `classroom_created`.
  - `app/controllers/classroom/classroom_creations_controller.rb`
    - `allow_roles :team`. En cas de succès : `classroom_path` (page du Lot D4), avec le toast « Classe créée. Code : KFM37 ».
  - `app/views/classroom/classroom_creations/new.html.erb`
  - `app/views/classroom/classroom_creations/_form.html.erb`
    - Établissement : `select` groupé par DRENA, grâce à `SchoolOptionsQuery#schools_grouped`, sans JS.
    - Niveau, série et nom.
  - `config/locales/classroom/classroom_creations.fr.yml`
- **Dépend de**    : Lot 0
- **Test associé** :
  - `test/domain/use_cases/classroom/create_classroom_test.rb`
    - Doublon de nom, série incompatible, collision de code avec nouvel essai, non-équipe.
  - `test/controllers/classroom/classroom_creations_controller_test.rb`
- **Done quand**   : les critères CL-01 et CL-04 (génération) sont verts.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/classroom/classrooms/new.html.erb` et `_form.html.erb`
  - captures `teams/team-school-id-school.png` et `teams/Lnclass - Configuration Plateforme.png`, cette dernière en référence visuelle
- **Fiches d'inventaire** : CL-01, CL-04, SC-03.
- **Non-régression** :
  - aucun slug n'est passé à `find_by_id` ;
  - le code ne dépasse pas la colonne ;
  - un rôle non autorisé reçoit 403, pas 500.
- **UDR**          : UDR-0031 — Création de classe

---

## Lot E — Preuve bout en bout

- **Couche**       : tests système (Chrome headless) + recette
- **Fichiers**     :
  - `test/system/boucle_pedagogique_test.rb`
    - Le chemin nominal du PRD §3, sur une base vierge avec seed.
    - L'équipe se connecte avec son TOTP, crée un cours, une fiche et un exercice de 2 questions, les publie, puis crée une classe et relève le code.
    - L'enseignant s'inscrit, déclare sa classe, ouvre la classe, le cours et la fiche, puis assigne l'exercice.
    - L'élève ouvre `/c/<code>`, s'inscrit, voit l'exercice sur son accueil, répond aux 2 questions, et voit « Félicitations ! » et le badge « Or ».
    - L'enseignant ouvre le résultat de l'élève.
    - Le parcours est rejoué en viewport mobile pour la partie élève.
  - `test/system/role_homes_test.rb`
    - Pour chaque rôle, une connexion réelle, puis l'accueil qui s'ouvre sans erreur, et chaque destination active de la navigation ouverte (chantier `queries-constantes-orm-disparues`).
  - `test/system/error_paths_test.rb`
    - Joué **par un rôle distinct de l'auteur** : code de classe invalide, réponse vide, enseignant hors de la classe, PIN oublié puis code émis par l'enseignant puis nouveau PIN, team sans second facteur.
- **Dépend de**    : tous les lots (0, A1 à A4, B1 à B8, C1 à C3, D1 à D8)
- **Test associé** : les trois fichiers ci-dessus. `bin/ci` complet.
- **Done quand**   :
  - les trois tests système sont verts en local et en CI ;
  - la recette est faite sur `Staging` par un rôle distinct (parcours nominal et un chemin d'erreur), et son compte rendu est dans `journal.md` ;
  - toutes les portes de sortie ci-dessous sont cochées.
- **Fiches d'inventaire** : TR-04, TR-05, TR-09 (tests système), et les critères de porte V1 du PRD cadre §5.

---
## Vérification de collision

> Deux lots ne listent jamais le même fichier. Pour le vérifier, la commande de [`plan-lots`](../../../.claude/skills/plan-lots/SKILL.md) doit renvoyer **une sortie vide**, sur tout ce qui précède cette section :
>
> ```bash
> awk '/^## Vérification de collision/{exit} 1' docs/chantiers/boucle-pedagogique/plan.md \
>   | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
> ```
>
> Vérifiée à la rédaction : sortie vide.

**Fichiers qui auraient été partagés entre plusieurs lots, et que le Lot 0 a donc repris**

| Fichier ou famille | Lots qui en ont besoin | Propriétaire |
|---|---|---|
| `config/routes.rb` et `config/routes/{identity,school,classroom,catalog,assessment,communication}.rb` | tous : 4 lots dans `catalog`, 8 dans `classroom` | **Lot 0**, avec toutes les routes V1 dessinées |
| `app/controllers/application_controller.rb`, `app/controllers/authenticated_controller.rb`, `app/controllers/concerns/*` | tous | **Lot 0** |
| `app/javascript/controllers/index.js` (enregistrement Stimulus) | A1, B5, C3, D1, D2, D4 | **Lot 0** (chargement par motif : plus aucun manifeste à éditer) |
| `app/javascript/controllers/math_controller.js` (KaTeX) | B1, B3, C1, C2, C3 | **Lot 0** |
| Tous les ports, toutes les entités, toutes les policies, tous les DTO, `Result` | tous | **Lot 0** |
| Tous les repositories et adaptateurs | par exemple `AssignmentRepository` : A2, A3, B3, C1, C2, D4, D5, D6, D7 | **Lot 0** |
| `app/domain/use_cases/classroom/read_classroom.rb` | D4, D5, D6, D7 | **Lot 0** |
| `app/domain/use_cases/identity/issue_pin_recovery_code.rb` | B8, D4 (via le contrôleur de B8) | **Lot 0** |
| `app/infrastructure/queries/catalog/referential_options_query.rb` | B2, D1, D8 | **Lot 0** |
| `app/infrastructure/queries/school/school_options_query.rb` | D1, D8 | **Lot 0** |
| `app/helpers/catalog/materials_helper.rb` (CA-26) | A2, A3, B1, B3, C1, D3 | **Lot 0** |
| `app/helpers/assessment/badges_helper.rb` | A2, B3, C1, C3 | **Lot 0** |
| `config/locales/fr.yml` (clés communes) | tous | **Lot 0** |
| `test/test_helper.rb`, `test/application_system_test_case.rb`, `test/support/**` | tous | **Lot 0** |
| `test/support/factories/<ctx>.rb` | plusieurs lots par contexte | **Lot 0**, fabriques **complètes**. Un lot écrit ses assemblages particuliers dans son propre test. |
| `db/migrate/*`, `db/schema.rb`, `db/seeds.rb`, `db/seeds/**` | tous | **Lot 0** |
| `app/views/classroom/assignments/_toggle.html.erb` | D5, D6, D7 | **D5**. D6 et D7 en dépendent, et passent donc en vague 2. |
| `app/views/homepage/index.html.erb` et `test/controllers/homepage_controller_test.rb` (fichiers V0) | A4 (contenu), Lot 0 (redirection) | **A4**. La redirection du Lot 0 est testée dans `test/controllers/homepage_redirection_test.rb`. |
| `app/assets/stylesheets/application.tailwind.css` (Lot 0c) | Lot 0 (import KaTeX) | **Lot 0c**. Le Lot 0 n'y ajoute qu'une ligne, après le merge de 0c. |
| `docs/decisions/udr/README.md` | chaque lot, pour son UDR | **Orchestrateur**, au merge de chaque lot |
| `docs/chantiers/boucle-pedagogique/journal.md` | tous | **Orchestrateur**, qui reporte les dérapages signalés par chaque lot |

## Vagues de dispatch

```
Vague 0 : Lot 0c (design)                                  → déjà lancé, autre agent
Vague 1 : Lot 0                                            → 1 agent (orchestrateur), séquentiel 0.1 → 0.10
Vague 2 : A1 ‖ A2 ‖ A3 ‖ A4 ‖ B1 ‖ B2 ‖ B3 ‖ B4 ‖ B5 ‖ B6 ‖ B7 ‖ B8
          ‖ C1 ‖ C2 ‖ C3 ‖ D1 ‖ D2 ‖ D3 ‖ D4 ‖ D5 ‖ D8     → 21 agents, worktrees isolés
Vague 3 : D6 ‖ D7 (dépendent de D5)                         → 2 agents
Vague 4 : Lot E (dépend de tous)                            → 1 agent, rôle distinct des auteurs
```

Chaque lot parallèle travaille dans son propre worktree, créé depuis la branche de chantier **une fois le Lot 0 mergé** :

```bash
git worktree add ../lnclass-boucle-pedagogique-lot-a1 -b feature/boucle-pedagogique-lot-a1 feature/boucle-pedagogique
```

**Ordre de merge dans `feature/boucle-pedagogique`.** Les lots se mergent dans l'ordre où ils finissent. Les fichiers sont disjoints, donc il n'y a jamais de conflit textuel. D5 doit être mergé avant que D6 et D7 ne partent. Après chaque merge, l'orchestrateur lance `bin/ci` sur la branche de chantier : un lot qui casse la branche est retiré, pas corrigé sur place.

**Si l'orchestrateur doit limiter le parallélisme**, la vague 2 se découpe sans changer le graphe :
- **d'abord le chemin critique** du parcours bout en bout : B2, B4, B5, D8, D1, D2, D4, D5, A1, A2, C1, C2, C3 ;
- **ensuite le reste** : A3, A4, B1, B3, B6, B7, B8, D3.

## Traçabilité — feature V1 → lot

Source : [feuille de route §6](../refonte-application/feuille-de-route.md#6-traçabilité--chaque-feature-de-lexistant-a-une-vague), colonne « Vague » = V1. Les critères correspondants sont dans le [PRD §4](prd.md#4-critères-dacceptation).

| ID | Feature | Lot(s) |
|---|---|---|
| ID-01 | S'inscrire comme élève | A1 |
| ID-02 | S'inscrire par `/c/<code>` | A1 |
| ID-03 | S'inscrire comme enseignant | D1 |
| ID-04 | *(écartée)* Remplacée par le seed et l'invitation (F-16) | 0 (seed), B7 |
| ID-07 | Vérifier un code en direct | A1 |
| ID-08 | DRENA → établissements (la cascade vers les classes est écartée) | D1 |
| ID-12 | Se connecter | 0 |
| ID-13 | Être dirigé vers son espace | 0 |
| ID-14 | Se déconnecter | 0 |
| ID-15 | Récupérer un PIN oublié | 0 (use cases, saisie du code), B8 (émission par l'équipe), D4 (émission par l'enseignant) |
| ID-16 | Restreindre chaque espace à son rôle | 0 |
| ID-28 | Normaliser et valider le numéro | 0 |
| ID-29 | Identifiant public | 0 |
| F-07 | TOTP équipe | 0 |
| CO-09 | Toasts | 0c (composant), 0 (branchement du flash) |
| SC-01 | DRENA (seed, lecture) | 0 |
| SC-03 | Établissements (seed) | 0 |
| SC-26 | API des établissements d'une DRENA | D1 |
| SC-27 | Rattachement à l'école à l'inscription | D1 |
| CL-01 | Créer une classe (équipe) | D8 |
| CL-04 | Générer et afficher le code | 0 (`JoinCode`), D8 (génération), D4 (affichage) |
| CL-06 | Rejoindre par `/c/<code>` | A1 |
| CL-07 | S'inscrire avec un code | A1 |
| CL-08 | API de vérification (la liste des classes est écartée) | A1 |
| CL-09 | Déclarer ses classes | D2 |
| CL-10 | Fiche d'une classe | D4 (enseignant, équipe), A3 (volet élève) |
| CL-11 | Cours dans la classe | D5 |
| CL-12 | Fiche dans la classe | D6 |
| CL-16 | Assigner / retirer un cours | D5 |
| CL-17 | Assigner / retirer une fiche | D5 |
| CL-20 | Assigner / retirer un exercice | D5 (bascule), D6 (écran) |
| CL-22 | Ma classe (élève) | A3 |
| CL-23 | Accueil élève | A2 |
| CA-01 | Catalogue publié | B1 |
| CA-04 | Consulter un cours | B1 |
| CA-05 | Créer un cours | B2 |
| CA-06 | Modifier un cours | B2 |
| CA-07 | Archiver un cours | B2 |
| CA-10 | Fiches d'un cours | B1 |
| CA-11 | Fiche et progression | B3 |
| CA-12 | Créer une fiche | B4 |
| CA-13 | Modifier une fiche | B4 |
| CA-14 | Archiver une fiche | B4 |
| CA-16 | Niveaux (seed) | 0 |
| CA-20 | Matières (seed) | 0 |
| CA-26 | Icône et couleur de la matière | 0 (helper), B1 (écran de référence) |
| CA-27 | Assigner un cours depuis sa page | B1 (lien), D7 (écran) |
| AS-02 | Détail d'un exercice | C1 |
| AS-03 | Créer un exercice | B5 |
| AS-04 | Modifier un exercice | B5 |
| AS-05 | Archiver un exercice | B5 |
| AS-07 | Démarrer une session | C2 |
| AS-08 | Reprendre | C2 |
| AS-09 | Répondre une fois | C2 |
| AS-10 | Correction immédiate | C2 |
| AS-11 | Badge à la clôture | C3 |
| AS-12 | Résultat | C3 |
| AS-13 | Recommencer | C3 (bouton), C2 (création de la nouvelle session) |
| AS-18 | Assigner un exercice | D5 |
| AS-19 | Retirer un exercice | D5 |
| AS-20 | Exercices d'une fiche dans une classe | D6 |
| AS-36 | Exercices sur l'accueil élève | A2 |
| AS-37 | Progression sur la fiche | B3 |
| AS-39 | Aperçu des questions sans fuite | C1 |
| TR-01 | Landing | A4 |
| TR-02 | Redirection par rôle | 0 |
| TR-04 | Accueil élève | A2, E (test système) |
| TR-05 | Accueil enseignant | D3, E (test système) |
| TR-08 | *(écartée)* Remplacée par l'onboarding persisté | 0 (`teachers.onboarded_at`, `HomeDestination`), D2 |
| TR-09 | Accueil équipe | B6, E (test système) |
| TR-27 | Navigation par rôle | 0c, 0 (routes nommées) |
| TR-40 | Français par clés | 0 (configuration, test de locale), tous (locale par écran) |
| TR-41 | KaTeX dans le bundle | 0 |
| chantier `queries-constantes-orm-disparues` | Accueils vivants | E |
| chantier `catalog-lecture-ecriture-incompatibles` | Un seul agrégat de cours | 0 (entité et repository), B2 (test de cycle de vie) |
| chantier `classroom-assignment-belongs-to-casses` | Repository d'assignation à 100 % | 0 (repository et test), D5 (usage) |
| chantier `classroom-code-adhesion-trop-long` | Longueur de colonne = longueur du code | 0 |
| chantier `dette-contrats-ports-et-injection` | Contrats de port, domaine sans repository | 0 |
| PRD cadre §5, 6 critères | Porte V1 | 0 (n° 2, n° 5), A1 et D1 (n° 1), C1 (n° 3), D4 (n° 4), B5 (n° 6), E (rejeu système) |

## Décisions que ce plan suppose

Chaque décision ci-dessous doit figurer dans l'ADR ou l'UDR cité **avant le Lot 0**. Si l'ADR tranche autrement, l'orchestrateur ajuste le Lot 0 avant de le coder : aucun lot vertical n'est touché, puisque les valeurs sont des constantes du domaine.

| Décision supposée | Où elle doit figurer |
|---|---|
| `Result` à trois champs `value / error / details`, avec six codes d'erreur fermés | ADR-0026 |
| Policies en `Policies::<Ctx>::…Policy#allowed?(actor:, …)`, ports injectés au constructeur. Un brouillon refusé devient `:not_found`, pas `:forbidden`. | ADR-0028 |
| `public_id` en base58 de 16 caractères. Slugs globaux uniques sur les cours, fiches et exercices, jamais régénérés. | ADR-0029 |
| `teacher_schools.primary`, avec un index partiel unique. La déclaration des classes ne remplace que celles de l'école principale. | ADR-0030 |
| TOTP à 30 s, une période de tolérance en arrière, anti-rejeu par `otp_last_used_step`. 10 codes de secours hachés. Secret chiffré par Active Record Encryption. | ADR-0031 |
| Code de récupération à 6 chiffres, valable 15 min, 5 essais. Émis par l'enseignant de l'élève ou par l'équipe, jamais sur son propre compte. Toutes les sessions sont fermées au changement. | ADR-0032 |
| Barème : or = 100, argent ≥ 80, bronze ≥ 50. Réussite 50, maîtrise 70. Remplacement **strictement** supérieur, pas d'historique des badges. `answered_count` (avancement) et `score_percent` (score) sont distincts. | ADR-0033 |
| Seed de 41 DRENA et des établissements, repris des fichiers `.Business` de l'ancien dépôt. Séries A1, A2, C, D. 2nde reliée à C seulement. 11 matières. | ADR-0034 |
| Transitions draft → published → archived. Pas de retour à draft, pas de désarchivage en V1. | ADR-0035 |
| FK en `restrict` partout, sauf `user_sessions`. Questions figées dès la première session. | ADR-0036 et ADR-0054 |
| Deux champs de 60 et 90 caractères, normalisation des espaces seulement | ADR-0037 |
| Invitation valable 72 h, par lien à jeton affiché une fois. Le numéro n'a ni compte ni invitation en cours. | ADR-0038 |
| `assignable_type` en vocabulaire de domaine (`course`, `essential`, `exercise`), sans association polymorphe `Orm`. La réassignation réactive la ligne. **L'élève ne démarre qu'un exercice assigné directement.** | ADR-0048 |
| Session en base avec un jeton haché dans un cookie signé. Durée absolue de 30 j (student, teacher) ou 12 h (team). Inactivité de 7 j ou 1 h. Verrouillage à 5 échecs par numéro et par minute. `rate_limit` à 10 par adresse et par minute. PIN différent des 4 derniers chiffres du numéro. | ADR-0050 (et ADR-0025 pour le PIN) |
| Statuts de session `in_progress / completed / abandoned`. Une seule session en cours par élève et par exercice (index partiel). Clôture par une action explicite. Ordre des réponses stable par session. | ADR-0054 |
| Chargement Stimulus par motif (`esbuild-rails`) et KaTeX dans le bundle | ADR-0051 (budget) et UDR-0005 |
| Couleur de matière par catégorie, icône en colonne `materials.icon` | UDR-0005 (CA-26) |
| Terme d'interface « Fiche » | UDR-0007 |
| L'élève ne voit pas le code de sa classe en V1 | UDR-0006 et UDR-0027 |

## Risques

| Risque | Parade |
|---|---|
| Le Lot 0 est gros : environ 340 chemins, tests compris. Tout le parallélisme l'attend. | Il est découpé en 10 sous-étapes, chacune commitée et verte. Les repositories sont mécaniques et spécifiés signature par signature. Le Lot 0c est déjà en cours en parallèle. |
| Le Lot 0c n'est pas encore mergé, et son `ui_subject_badge(name)` déduit la couleur du **nom** de la matière (défaut CA-26). Signalé à team-lead le 2026-09-25. | Le Lot 0 fournit son propre helper par catégorie. Aucun lot n'appelle `ui_subject_badge`. |
| Les ADR 0026 à 0054 ne sont pas encore écrits. Une valeur tranchée autrement que dans ce plan changerait le Lot 0. | Les valeurs sont isolées en constantes nommées du domaine. La règle « décisions `Accepté` avant le Lot 0 » est rappelée par `plan-lots`. |
| Les clés Active Record Encryption, nécessaires à `encrypts :otp_secret`, sont absentes des credentials. | L'orchestrateur les génère (`bin/rails db:encryption:init`) et les ajoute aux credentials au Lot 0.1. Le porteur fournit la clé maître de production. |
| 21 agents en parallèle provoquent des temps de CI et une file de merge longs. | Le chemin critique passe en premier (voir « Vagues de dispatch »). Chaque merge est suivi de `bin/ci` sur la branche de chantier. |
| Le rendu KaTeX et l'éditeur Trix alourdissent le bundle (ADR-0051). | Le test de bundle du Lot 0 mesure la taille gzip. KaTeX n'est chargé que par le contrôleur `math`, par import dynamique si le budget l'exige. |
| Les données des DRENA et des établissements, issues de fichiers métier non validés, pourraient se retrouver en production. | Le seed de production est bloqué tant que le porteur n'a pas validé les deux listes (question ouverte du memo). |

## Portes de sortie

Recopiées telles quelles depuis [`workflows/feature.md`](../../workflows/feature.md) :

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, indexé dans `decisions/adr/README.md`
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, indexée dans `decisions/udr/README.md`
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

Porte **de vague**, issue de la [feuille de route §5 V1](../refonte-application/feuille-de-route.md#v1--boucle-pédagogique) :

- [ ] Les critères du PRD cadre §5 sont verts.
- [ ] Le parcours bout en bout passe en navigateur réel (Lot E).
- [ ] La recette sur `Staging` est faite par un rôle distinct.

## Challenger empirique

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Son mandat change selon le cycle : bugfix → il rejoue les étapes de reproduction du memo dans l'app ; refactoring → il vérifie que **rien** n'a changé pour l'utilisateur, et il lui est interdit de commenter le style ; optimisation → il **relance lui-même le bench** et doit obtenir le gain annoncé, sinon la PR ne passe pas.

**Mandat pour cette feature.**

1. Le challenger rejoue le chemin nominal du [PRD §3](prd.md#3-parcours-utilisateur) dans l'application, en trois navigateurs ou profils distincts : équipe, enseignant, élève. Le parcours élève se fait aussi sur un téléphone Android ou en émulation 390 px.
2. Il rejoue au moins ces chemins d'erreur :
   - le 6e échec de connexion ;
   - une réponse vide ;
   - une double soumission ;
   - un enseignant hors de sa classe ;
   - un brouillon ouvert par son URL ;
   - un PIN oublié.
3. Il vérifie le HTML servi à l'élève avec les outils du navigateur : aucune bonne réponse n'y figure.
4. Il consigne dans `journal.md` ce qu'il a fait et ce qu'il a observé.
