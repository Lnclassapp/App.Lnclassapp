# Plan d'exécution — Boucle pédagogique (V1)

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot). Règles de collision : [`boucle-de-travail.md`](../refonte-application/boucle-de-travail.md) §6.
> Specs : [`prd.md`](prd.md). Cadrage : [`memo.md`](memo.md). Décisions : ADR-0026 à ADR-0054 et UDR-0007, **acceptés le 2026-09-25 et mergés dans `Develop` (32fb626)**. Ce plan s'aligne sur eux ; les rares écarts sont listés dans « Décisions que ce plan suppose ».

**Conventions de lecture de ce plan**

- **Un chemin du nouveau dépôt n'apparaît qu'une fois** avant la section « Vérification de collision ». C'est ce qui rend la commande de vérification probante. Les autres mentions d'un fichier passent par le nom de sa classe (`Shared::Result`, `Ports::Classroom::AssignmentRepositoryPort`…).
- Un fichier qui existe déjà dans `Develop` (V0, Lot 0c) est marqué **(modifié)** ; un fichier retiré, **(supprimé)**. Tous les autres sont créés.
- Les écrans et le code de l'**ancienne application** (lecture seule, `/home/kamkara/LnclassHQ/Lnclassapp/LnclassHQ/Lnclassapp`) sont notés `⟨ancienne⟩ views/…`, `⟨ancienne⟩ javascript/…` ou `⟨ancienne⟩ domain/…`. Ces chemins sont relatifs à son répertoire `app/`. On les **lit** pour reproduire les parcours, la mise en page et les règles. On ne recopie jamais leur code.
- Les fichiers `.Business/content_pedagogics/` de l'ancienne application (`DRENAS/`, `tle_d/`, `data/`) sont des **exemples d'import** et des **données de développement et de test** (ADR-0039 §6), jamais des seeds de production.
- Les fiches d'inventaire sont dans [`refonte-application/inventaire/`](../refonte-application/inventaire/). On les cherche par leur ID (`grep -n "CL-09" inventaire/*.md`).
- Le design est **mixte** :
  - **les écrans et les parcours** viennent de l'ancienne application ;
  - **les tokens** viennent de la nouvelle landing (UDR-0005) ;
  - **les composants** `ui_*` et **le shell** `layout "shell"` viennent du Lot 0c (UDR-0006), déjà dans `Develop`.
- Aucun lot n'écrit de classe CSS arbitraire (`[…]`) ni de couleur `#hex` dans une vue : `DesignTokensTest` (V0) le refuse.
- Le vocabulaire d'interface suit l'**UDR-0007** : « Fiche essentielle », « Exercice », « Session », « Tentative », « Proposition », badges Bronze, Argent, Or et Diamant.
- **Tout CRUD passe par Hotwire** (règle du porteur, UDR-0006 §7, brief standard §5). La règle est détaillée dans « Lots verticaux — règles communes » ; chaque lot à écran la décline dans son champ **Hotwire**.
- Chaque lot écrit **l'UDR de ses écrans** sous le numéro réservé, dans `docs/decisions/udr/`. L'**orchestrateur** l'indexe dans le README des UDR au merge : c'est le seul à écrire dans ce fichier.

## Graphe

```
V0 + Lot 0c (design) ── déjà dans Develop (32fb626)
  │
  ├─ Vague 1 ─ Lot 0a  schéma · Orm · routes V1 · fabriques          ┐ en parallèle,
  │            Lot 0b  domaine pur : Result, entités, ports, policies ┘ fichiers disjoints
  │
  ├─ Vague 2 ─ Lot 0d  authentification · TOTP · shell branché        ◄── 0a, 0b
  │            Lot 0e  repositories · moteur d'import · front partagé ◄── 0a, 0b
  │                    └─ étape e4 (écran des imports, seeds, gardes)  ◄── 0d mergé
  │
  ├─ Vague 3 : 30 lots, en sous-vagues de 8 au plus (3a → 3d) ──────────────────────────┐
  │                                                                                     │
  │  R — Référentiel (équipe)   S — DRENA, établissements      I — Import de contenu    │
  │  ├─► R1 niveaux             ├─► S1 DRENA : gestion         ├─► I1 cours (arbre)     │
  │  ├─► R2 séries, couples     ├─► S2 établissements          ├─► I2 fiches ess.       │
  │  └─► R3 matières            │       + génération classes   └─► I3 exercices         │
  │                             └─► S3 import établissements                            │
  │                                                                                     │
  │  A — Élève         B — Contenu & équipe          C — Évaluation                     │
  │  ├─► A1 adhésion   ├─► B1 catalogue + cours      ├─► C1 détail exercice             │
  │  ├─► A2 accueil    ├─► B2 gestion cours          ├─► C2 session + clôture           │
  │  ├─► A3 ma classe  ├─► B3 fiche ess. + progression└─► C3 résultat + badge           │
  │  └─► A4 landing    ├─► B4 gestion fiches ess.                                       │
  │                    ├─► B5 gestion exercices      D — Enseignant & classe            │
  │                    ├─► B6 accueil équipe         ├─► D1 inscription ens.            │
  │                    ├─► B7 invitation équipe      ├─► D2 déclarer ses classes        │
  │                    └─► B8 débloquer un compte    ├─► D3 accueil ens.                │
  │                                                  ├─► D4 page classe                 │
  │                                                  ├─► D5 assignation ────────────────┼─┐
  │                                                  └─► D8 créer une classe            │ │
  ├─────────────────────────────────────────────────────────────────────────────────────┘ │
  │                                                                                       │
  ├─ Vague 4 : D6 fiche ess. dans la classe  ◄── D5                                       │
  │            D7 assigner depuis le cours   ◄── D5 ──────────────────────────────────────┘
  │
  └─ Vague 5 : Lot E — preuve bout en bout (Chrome headless) ◄── tous les lots
```

**37 lots** : quatre sous-lots de socle (0a, 0b, 0d, 0e), 32 lots verticaux, puis le Lot E. Le nom « 0c » est déjà pris par le lot de design ; le socle saute donc cette lettre. Les lots verticaux dépendent des quatre sous-lots mergés, et de rien d'autre, sauf D6 et D7, qui dépendent de D5 : ils réutilisent son partial de bascule d'assignation.

**Pourquoi B (publication) ne dépend pas de R (référentiel).**
- B a besoin de niveaux, de séries et de matières **en base**, pas des écrans qui les créent. Ses tests les créent avec les fabriques de 0a. En développement, le seed du référentiel les fournit (ADR-0034).
- Les écrans R ne sont nécessaires qu'au parcours réel, donc au Lot E, qui dépend de tout.
- B et R partent donc dans la même vague 3 (sous-vagues 3a et 3b). Le même raisonnement vaut pour S (établissements) face à D (enseignant), et pour I (import) face à B.

### Pourquoi le socle est plus gros que « des routes vides »

Sept familles de fichiers seraient partagées par plusieurs lots verticaux. Le socle les écrit une fois pour toutes, et les lots n'y touchent plus.

1. **Les routes.**
   - Plusieurs lots écrivent dans un même contexte : 7 dans `classroom`, 16 dans l'espace équipe. Un fichier de routes vide par contexte les mettrait en collision.
   - 0a dessine **toutes** les routes V1. Une route qui pointe vers un contrôleur pas encore écrit ne casse rien tant qu'on ne l'appelle pas.
   - La navigation du Lot 0c exige des noms de route **gelés** : `student_home_path`, `student_classroom_path`, `teacher_home_path`, `teacher_classrooms_path`, `team_home_path`, `courses_path`, `session_path`. 0a les crée tous. Il crée aussi `schools_path`, dont le contrôleur est livré par S2 : **l'entrée « Établissements » de l'équipe devient donc active en V1** (amendement de l'UDR-0006). `team_dashboard_path` (V4) et `profile_path` (V2) restent inactives.
2. **Les repositories.** Un même port sert plusieurs lots. Par exemple, `AssignmentRepositoryPort` sert A2, C2, D5 et D6, et `ClassroomRepositoryPort#insert_generated` sert S2, S3 et les seeds. Chaque repository est donc écrit au socle, avec son test. Les lots n'écrivent que leurs **use cases**, leurs **queries** (une par écran), leurs contrôleurs et leurs vues.
3. **Les fabriques de test.** Deux lots d'un même contexte se disputeraient `test/support/factories/<ctx>.rb`. 0a les écrit **complètes**, pour toutes les tables. Un lot qui a besoin d'un assemblage particulier l'écrit dans son propre fichier de test.
4. **Le moteur d'import en masse.** Quatre types d'import partagent le téléversement, le rapport, le job, la validation complète avant écriture, l'écriture par lots avec rejeu élément par élément et l'écran de suivi (ADR-0039). 0e écrit ce moteur. Chaque lot d'import (S3, I1, I2, I3) n'apporte que son **adaptateur** : son use case importeur, son job, son schéma JSON, son aide à l'écran et son test de performance.
5. **La génération des classes** (`Entities::Classroom::DefaultClassroomPlan`, ADR-0030). Elle sert à la création unitaire (S2), à l'import (S3) et aux seeds : elle est dans 0b.
6. **Les briques Hotwire communes** : le frame `modal` et `#toasts` (Lot 0c, déjà là), le rafraîchissement par morphing (0e), le panneau de statut d'un contenu (0e), et les assertions de test système `assert_no_page_reload` et `open_in_modal` (0d).
7. **L'éditeur de texte riche** (décision du porteur du 2026-09-25, amendement de l'ADR-0051). Action Text et Trix servent aux formulaires de cours (B2) et de fiches essentielles (B4), et les imports I1 et I2 écrivent dans le même rich text. Le socle livre donc le framework, la table, `has_rich_text` (0a), l'assainissement du HTML importé (0e, e1) et le contrôleur `rich-text-editor`, qui charge Trix à la demande (0e, e3).

Les contrôleurs Stimulus sont chargés **par motif de fichier** (`esbuild-rails`, 0e). Il n'y a donc plus de manifeste à éditer. Un lot qui dépose `app/javascript/controllers/<ctx>/<nom>_controller.js` est enregistré sous l'identifiant `<ctx>--<nom>`.

---

## Lot 0 — Socle, en quatre sous-lots

| Sous-lot | Contenu | Dépend de | En parallèle avec | Worktree · branche |
|---|---|---|---|---|
| **0a** | Dépendances, 32 migrations (Action Text compris), schéma, modèles `Orm::`, routes V1 complètes, fabriques, configuration de test | V0 et 0c (dans `Develop`) | 0b | `lnclass-lot-0a` · `feature/boucle-pedagogique-lot-0a` |
| **0b** | Domaine pur : `Shared::Result`, entités, objets-valeurs, **tous les ports**, policies, DTO du socle | V0 | 0a | `lnclass-lot-0b` · `feature/boucle-pedagogique-lot-0b` |
| **0d** | Transaction, 9 repositories `identity`, use cases d'authentification et de second facteur, contrôleurs et écrans de connexion, `Teams::BaseController`, shell branché, helpers de test | départ : 0a mergé ; merge : 0a **et** 0b | 0e | `lnclass-lot-0d` · `feature/boucle-pedagogique-lot-0d` |
| **0e** | 18 autres repositories, moteur d'import, front partagé, puis (e4) écran des imports, seeds et gardes d'architecture | départ : 0a mergé ; merge : 0a **et** 0b ; **e4 attend le merge de 0d** | 0d (étapes e1 à e3) | `lnclass-lot-0e` · `feature/boucle-pedagogique-lot-0e` |

**Dépendances réelles.**

| Sous-lot | Peut partir quand | Peut être mergé quand | Pourquoi |
|---|---|---|---|
| 0a | tout de suite | quand il est vert | ne lit aucun fichier d'un autre sous-lot |
| 0b | tout de suite | quand il est vert | Ruby pur : n'ouvre ni la base ni `Orm::` |
| 0d | 0a mergé | 0a **et** 0b mergés | ses repositories lisent `Orm::` (0a) et incluent les ports (0b). Les signatures des ports sont **gelées dans ce plan** (0b.3) : 0d peut les coder avant le merge de 0b, mais ses tests ne passent qu'après, une fois sa branche rebasée. |
| 0e (e1 à e3) | 0a mergé | 0a **et** 0b mergés | même raison que 0d ; le moteur (e2) appelle `ImportKind`, `ImportReport` et `TransactionPort#attempt`, figés dans 0b.2 et 0b.3 |
| 0e (e4) | 0d mergé | 0a, 0b et 0d mergés | `Teams::ImportsController` hérite de `Teams::BaseController` (0d) ; son test système se connecte par l'authentification de 0d |

**Correspondance avec la numérotation 0.1 à 0.11** de la version précédente de ce plan (`efee7fd`), citée dans des échanges antérieurs :

| Ancienne étape | Sous-lot actuel |
|---|---|
| 0.1 Dépendances · 0.2 Migrations · 0.3 `Orm::` | 0a.1 · 0a.2 · 0a.3 |
| 0.4 Domaine · 0.6 Policies, DTO | 0b.1 à 0b.5 (les use cases d'authentification sont passés dans 0d.2) |
| 0.5 Ports **et repositories** | ports : 0b.3 ; repositories : 0d.1 (`identity`, transaction) et e1 (les 18 autres) |
| 0.7 Moteur d'import | e2, e4 |
| 0.8 Queries et helpers partagés | e3 |
| 0.9 Seeds | e4 |
| 0.10 Routes, authentification, shell | routes : 0a.4 ; authentification, second facteur, shell branché, `Teams::BaseController` : 0d |
| 0.11 Support de test, garde-fous | fabriques : 0a.5 ; assertions Turbo : 0d.4 ; garde-fous d'architecture : e4 |

Les routes et les fabriques sont dans 0a, et non dans un sous-lot plus tardif : elles ne dépendent que du schéma, et tous les autres sous-lots en ont besoin pour leurs tests.

**Règles propres au socle.**
- Les quatre sous-lots ont des fichiers **disjoints** : la vérification de collision en fin de plan le prouve.
- Les ports sont écrits en entier par 0b. Leurs signatures sont **gelées dès ce plan**, et leur code au merge de 0b : 0d, 0e et les lots verticaux les implémentent ou les appellent, sans les modifier. Un besoin de changement arrête le sous-lot et remonte à l'orchestrateur.
- Chaque sous-lot fait un commit par sous-étape (`feat(<ctx>): …`), garde `bin/ci` vert à chaque merge, et respecte le brief standard.
- Les lots verticaux partent **après le merge des quatre sous-lots**.

---

## Lot 0a — Schéma, ORM, routes, fabriques

- **Couche**       : infrastructure (schéma, `Orm::`) + delivery (routes) + support de test
- **Fichiers**     : les chemins des tableaux 0a.1 à 0a.5, exhaustifs.
- **Dépend de**    : V0 et Lot 0c, déjà dans `Develop` (32fb626). Aucune dépendance à 0b.
- **Test associé** : colonne « Test » des tableaux 0a.1 à 0a.5.
- **Done quand**   :
  - `bin/rails db:drop db:prepare` passe sur une base vide, et `bin/rails db:migrate:redo STEP=32` aussi ;
  - le test de contraintes du schéma (0a.2) et le test des routes (0a.4) sont verts ;
  - chaque fabrique crée sa ligne, et `create_team_member(second_factor: true)` écrit un secret chiffré (`encrypts`) ;
  - `grep -rn friendly_id app config Gemfile db` ne renvoie rien ;
  - `bin/ci` est vert.
- **UDR**          : aucune (aucun écran).

### 0a.1 Dépendances et configuration

| Fichier | Contenu | Test |
|---|---|---|
| `Gemfile` · `Gemfile.lock` (modifiés) | Décommenter `bcrypt ~> 3.1.7`. Ajouter `rotp ~> 6.3` et `rqrcode ~> 2.2` (ADR-0031), `json_schemer ~> 2.3` (ADR-0039). **Retirer `friendly_id`** : slugs et `public_id` passent par nos concerns (ADR-0029). `mission_control-jobs`, `aws-sdk-s3` et `rails-i18n` sont déjà là (V0). | `bin/bundler-audit` vert |
| `config/initializers/friendly_id.rb` (supprimé) | — | `grep` du Done quand |
| `package.json` · `yarn.lock` (modifiés) | Ajouter `katex`, **`trix` et `@rails/actiontext`** (éditeur riche, retour du porteur du 2026-09-25), et `esbuild-rails` (dev). Le script `build` devient `node esbuild.config.mjs`. | `yarn build` vert |
| `esbuild.config.mjs` | Reprend **toutes** les options du script V0 (`bundle`, `minify`, `splitting`, `format: "esm"`, `chunkNames`, cibles chrome111, safari16.4, firefox128, `sourcemap`, `outdir: app/assets/builds`, `publicPath: /assets`), plus le plugin `rails()` d'`esbuild-rails` (imports par motif). Second point d'entrée : `katex/dist/katex.min.css` → `app/assets/builds/katex.css`, polices en loader `file`. Troisième : `trix/dist/trix.css` → `app/assets/builds/trix.css`. Ni KaTeX, ni Trix, ni `@rails/actiontext` ne figurent **jamais** dans le point d'entrée commun (ADR-0051 et son amendement du 2026-09-25) : ils forment des morceaux (`chunks`) chargés par import dynamique. | étape « Assets: Budget » de `bin/ci` : 60 Ko gzip de JS, 30 Ko de CSS |
| `config/application.rb` (modifié) | Ajouter `require "action_text/engine"` : V0 avait retiré Action Text du chargement de `rails/all`. Le commentaire d'en-tête dit désormais que Trix est chargé à la demande, hors du point d'entrée commun. | couvert par le test de schéma de 0a.2 (table présente) |
| `config/environments/test.rb` (modifié) | `cache_store = :memory_store` (nécessaire à `rate_limit`, ADR-0050). Clés Active Record Encryption **de test** posées en clair (`active_record.encryption.primary_key`, `deterministic_key`, `key_derivation_salt`) : la CI n'a pas de clé maître. | couvert par la fabrique `create_team_member` |
| `config/credentials.yml.enc` (modifié, **par l'orchestrateur**) | `bin/rails db:encryption:init`, puis les trois clés sous `active_record_encryption`, pour le développement et la production. Le porteur n'a rien à fournir. | — |

### 0a.2 Migrations

Horodatage `20260925100001` → `20260925100032`, dans cet ordre : une table n'est créée qu'après celles que ses clés étrangères visent. **Règles communes** (ADR-0027, ADR-0029, ADR-0036) :

- clés primaires `bigint` ; `timestamps null: false` sauf mention contraire ;
- toute FK a sa contrainte en base, en `on_delete: :restrict`. `:cascade` n'est permis que pour la liste fermée de l'ADR-0036 : `sessions`, `login_attempts`, `totp_credentials`, `backup_codes` et `pin_recovery_codes` vers `users` ;
- énumérations en `string` avec contrainte `CHECK`, jamais en `integer` ;
- `public_id` : `string(14) null: false`, index unique, `SecureRandom.base58(14)` (ADR-0029), sur `users`, `drenas`, `schools`, `classrooms`, `classroom_assignments`, `exercises`, `exercise_sessions`, `knowledge_gaps`, `import_reports` ;
- slug : `string null: false`, index unique global, dérivé du nom par `parameterize`, suffixé `-2`, `-3`… en cas de collision, **figé à la création** (ADR-0029), sur `drenas`, `levels`, `series`, `materials`, `courses`, `essentials` ;
- toute personne est référencée par `users.id`, jamais par un profil.

**`db/migrate/20260925100001_create_users.rb`** — `users` (ADR-0037, ADR-0038, ADR-0050)
- `public_id` ; `last_name` string(50) non null ; `first_name` string(80) non null.
- `contact` string(10), **nullable** (anonymisation), index unique partiel `WHERE contact IS NOT NULL`, `CHECK (contact ~ '^0[157][0-9]{8}$')`.
- `gender` string, non null, `CHECK IN ('male','female')`.
- `role` string, non null, `CHECK IN ('student','teacher','school_admin','team')`, index.
- `team_role` string, nullable, `CHECK IN ('admin','content','field')`, et `CHECK ((role = 'team') = (team_role IS NOT NULL))`.
- `pin_digest` string, non null (`has_secure_password :pin`).
- `anonymized_at` datetime, nullable.

**`db/migrate/20260925100002_create_drenas.rb`** — `drenas` (ADR-0034)
- `public_id` ; `name` string(80) non null, unique ; `slug` **figé** : c'est la cible des imports d'établissements (ADR-0039).

**`db/migrate/20260925100003_create_schools.rb`** — `schools` (ADR-0030)
- `public_id` ; `drena_id` FK non null, index ; `name` string(150) non null ; `sigle` string(20) nullable.
- `status` string non null défaut `'active'`, `CHECK IN ('draft','active','inactive')`.
- `school_type` string non null, `CHECK IN ('public','private','mixed')` (libellés Public, Privé, Mixte).
- `cycle` string non null défaut `'both'`, `CHECK IN ('first','both')`.
- Unique `(drena_id, name)` : dernier rempart ; la clé de doublon de l'import est normalisée par le domaine (ADR-0039).

**`db/migrate/20260925100004_create_levels.rb`** — `levels` (ADR-0034)
- `name` string(20) non null, unique ; `slug` ; `position` integer non null, unique ; `cycle` string non null `CHECK IN ('first','second')`. **Aucune colonne `code`** : le slug figé sert de code (`6eme`, `5eme`, `4eme`, `3eme`, `2nde`, `1ere`, `tle`).

**`db/migrate/20260925100005_create_series.rb`** — `series`
- `name` string(10) non null, unique ; `slug` (`a`, `a1`, `a2`, `c`, `d`).

**`db/migrate/20260925100006_create_level_series.rb`** — `level_series`
- `level_id` et `series_id` FK non null ; unique `(level_id, series_id)`, index `series_id` ; `created_at` non null.

**`db/migrate/20260925100007_create_materials.rb`** — `materials` (ADR-0034, CA-26)
- `name` string(40) non null, unique ; `shortname` string(10) non null, unique ; `slug` ; `category` string non null `CHECK IN ('literature','science','other')`. Pas de colonne d'icône : la catégorie porte l'icône et la couleur (`ui_subject_badge`).

**`db/migrate/20260925100008_create_teacher_profiles.rb`** — `teacher_profiles` (ADR-0027, ADR-0030)
- `user_id` FK non null, **unique** ; `material_id` FK non null ; `onboarding_completed_at` datetime, nullable.

**`db/migrate/20260925100009_create_teacher_schools.rb`** — `teacher_schools` (ADR-0030, tel quel)
- `teacher_id` FK **`users`** non null ; `school_id` FK non null ; `primary` boolean non null défaut `false` ; `created_at` non null.
- Unique `(teacher_id, school_id)` ; unique partiel `(teacher_id) WHERE "primary"`, nommé `index_teacher_schools_one_primary`.

**`db/migrate/20260925100010_create_sessions.rb`** — `sessions` (ADR-0050)
- `user_id` FK non null, `on_delete: :cascade`, index ; `token_digest` string(64) non null, unique ; `ip_address` string(45) ; `user_agent` string(255) ; `created_at` et `last_seen_at` non null ; `second_factor_verified_at` nullable. Pas d'`updated_at`.

**`db/migrate/20260925100011_create_login_attempts.rb`** — `login_attempts` (ADR-0050)
- `contact` string(20) non null (normalisé si possible, brut sinon) ; `user_id` FK nullable, `cascade` ; `ip_address` string(45) ; `succeeded` boolean non null ; `kind` string non null `CHECK IN ('pin','second_factor')` ; `created_at` non null. Index `(contact, created_at)`.

**`db/migrate/20260925100012_create_audit_events.rb`** — `audit_events` (ADR-0050)
- `actor_id` FK `users` nullable ; `action` string(60) non null ; `subject_type` string(40) et `subject_id` bigint nullables ; `metadata` jsonb non null défaut `{}` ; `ip_address` string(45) ; `created_at` non null. Index `(subject_type, subject_id)` et `(actor_id, created_at)`.

**`db/migrate/20260925100013_create_totp_credentials.rb`** — `totp_credentials` (ADR-0031)
- `user_id` FK non null, unique, `cascade` ; `secret` text non null (chiffré par `encrypts`) ; `confirmed_at` nullable ; `last_used_step` bigint nullable.

**`db/migrate/20260925100014_create_backup_codes.rb`** — `backup_codes` (ADR-0031)
- `user_id` FK non null, `cascade` ; `code_digest` string(64) non null (HMAC-SHA256) ; `used_at` nullable ; `created_at` non null. Index `(user_id) WHERE used_at IS NULL`.

**`db/migrate/20260925100015_create_pin_recovery_codes.rb`** — `pin_recovery_codes` (ADR-0032)
- `user_id` FK non null, `cascade` ; `issued_by_id` FK `users` non null ; `code_digest` string(64) non null ; `expires_at` non null ; `failed_attempts` integer non null défaut 0 ; `used_at` et `revoked_at` nullables ; `created_at` non null. Index unique partiel `(user_id) WHERE used_at IS NULL AND revoked_at IS NULL`.

**`db/migrate/20260925100016_create_invitations.rb`** — `invitations` (ADR-0038, partagée avec l'ADR-0044)
- `kind` string non null `CHECK IN ('team','school_staff')` ; `contact` string(10) non null ; `team_role` string nullable ; `school_id` FK nullable ; `position` string nullable ; `invited_by_id` FK `users` nullable (invitation d'amorçage) ; `token_digest` string(64) non null, unique ; `expires_at` non null ; `accepted_at`, `accepted_user_id` (FK `users`), `revoked_at` nullables.
- `CHECK (kind <> 'team' OR team_role IS NOT NULL)`. Index unique partiel `(kind, contact) WHERE accepted_at IS NULL AND revoked_at IS NULL`.

**`db/migrate/20260925100017_create_classrooms.rb`** — `classrooms` (ADR-0041)
- `public_id` ; `school_id` et `level_id` FK non null ; `series_id` FK nullable ; `name` string(15) non null.
- `school_year` string(9) non null, `CHECK (school_year ~ '^[0-9]{4}-[0-9]{4}$' AND right(school_year, 4)::int = left(school_year, 4)::int + 1)`.
- `status` string non null défaut `'active'` `CHECK IN ('active','archived')` ; `archived_at` nullable ; `CHECK ((status = 'archived') = (archived_at IS NOT NULL))`.
- `join_code` string(5) **nullable**, `CHECK (join_code ~ '^[a-hj-np-z]{3}[2-9]{2}$')`, unique partiel `WHERE join_code IS NOT NULL` ; `join_code_rotated_at` nullable. La longueur de la colonne égale celle du code généré : ce test de schéma ferme le chantier `classroom-code-adhesion-trop-long`.
- `max_students` integer non null défaut 80, `CHECK (max_students BETWEEN 1 AND 150)`.
- Unique `(school_id, school_year, name)`.

**`db/migrate/20260925100018_create_classroom_students.rb`** — `classroom_students` (ADR-0040, tel quel)
- `classroom_id` FK non null ; `student_id` FK `users` non null ; `primary` boolean non null défaut `false` ; `joined_at` non null ; `left_at` nullable.
- Unique `(classroom_id, student_id)` ; unique partiel `(student_id) WHERE "primary" AND left_at IS NULL`, nommé `index_classroom_students_one_active_primary`.

**`db/migrate/20260925100019_create_teacher_classrooms.rb`** — `teacher_classrooms` (ADR-0030)
- `teacher_id` FK `users` non null ; `classroom_id` FK non null ; `created_at` non null. Unique `(teacher_id, classroom_id)`, index `classroom_id`.

**`db/migrate/20260925100020_create_courses.rb`** — `courses` (ADR-0035)
- `slug` ; `name` string(200) non null ; `subtitle` string(150) ; **pas de colonne `content`** : le contenu est un rich text Action Text (`has_rich_text :content`, table `action_text_rich_texts`, migration 32) ; `level_id` et `material_id` FK non null ; `series_id` FK nullable ; `author_id` FK `users` non null.
- `status` string non null défaut `'draft'` `CHECK IN ('draft','published','archived')` ; `published_at` et `archived_at` nullables ; index `status`.
- Unique `(level_id, material_id, series_id, name) NULLS NOT DISTINCT`.

**`db/migrate/20260925100021_create_essentials.rb`** — `essentials`
- `course_id` FK non null ; `slug` ; `name` string(150) non null ; `subtitle` string(150) ; **pas de colonne `content`** (rich text, comme `courses`) ; `position` integer non null ; `author_id` FK `users` non null ; `status`, `published_at`, `archived_at` comme `courses`.
- Unique `(course_id, name)` et `(course_id, position)`.

**`db/migrate/20260925100022_create_exercises.rb`** — `exercises` (ADR-0054)
- `public_id` ; `essential_id` FK non null ; `title` string(200) non null ; `description` text ; `exercise_type` string non null défaut `'fixation'` `CHECK IN ('fixation','evaluation')` ; `position` integer non null ; `author_id` FK `users` non null ; `status`, `published_at`, `archived_at`.
- Unique `(essential_id, position)`, index `(essential_id, status)`.

**`db/migrate/20260925100023_create_questions.rb`** — `questions`
- `exercise_id` FK non null ; `position` integer non null ; `content` text non null ; `explanation` text ; `question_type` string non null `CHECK IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3')`. Unique `(exercise_id, position)`.

**`db/migrate/20260925100024_create_answers.rb`** — `answers` (les « propositions » de l'UDR-0007)
- `question_id` FK non null ; `position` integer non null ; `content` string(500) non null ; `correct` boolean non null. Unique `(question_id, position)`.

**`db/migrate/20260925100025_create_classroom_assignments.rb`** — `classroom_assignments` (ADR-0048, tel quel)
- `public_id` ; `classroom_id` FK non null ; `assignable_type` string non null `CHECK IN ('Course','Essential','Exercise')` ; `assignable_id` bigint non null ; `assigned_by_id` FK `users` non null ; `status` `CHECK IN ('active','archived')` défaut `'active'` ; `assigned_at` non null ; `archived_at` et `archived_by_id` (FK `users`) nullables.
- `CHECK ((status = 'archived') = (archived_at IS NOT NULL))` ; unique partiel `(classroom_id, assignable_type, assignable_id) WHERE status = 'active'`, nommé `index_classroom_assignments_one_active` ; index `(assignable_type, assignable_id)`.

**`db/migrate/20260925100026_create_exercise_sessions.rb`** — `exercise_sessions` (ADR-0033, ADR-0043, ADR-0048, ADR-0054)
- `public_id` ; `student_id` FK `users` non null ; `exercise_id` FK non null.
- `status` string non null défaut `'started'` `CHECK IN ('started','completed','abandoned')`.
- `question_count` integer non null `CHECK > 0`, figé au démarrage ; `answered_count` et `correct_count` integer non null défaut 0.
- `progress_percent` integer non null défaut 0 `CHECK BETWEEN 0 AND 100` ; `score_percent` integer nullable `CHECK BETWEEN 0 AND 100`, posé **uniquement** à la clôture ; `CHECK (status <> 'completed' OR score_percent IS NOT NULL)`.
- `kind` string non null défaut `'standard'` `CHECK IN ('standard','remediation')` ; `knowledge_gap_id` bigint nullable (FK ajoutée en 29) ; `CHECK ((kind = 'remediation') = (knowledge_gap_id IS NOT NULL))`.
- `classroom_assignment_id` FK nullable ; `started_at` non null ; `completed_at` nullable.
- Unique partiel `(student_id, exercise_id) WHERE status = 'started'` ; index `(student_id, completed_at)`.

**`db/migrate/20260925100027_create_question_attempts.rb`** — `question_attempts` (ADR-0054)
- `exercise_session_id` et `question_id` FK non null ; `selected_answer_ids` bigint[] non null `CHECK (cardinality(selected_answer_ids) > 0)` ; `correct` boolean non null ; `answered_at` non null. **Aucun timestamp** : la ligne est immuable.
- **Unique `(exercise_session_id, question_id)`** (sécurité n° 30).

**`db/migrate/20260925100028_create_exercise_badges.rb`** — `exercise_badges` (ADR-0033)
- `student_id` FK `users` ; `exercise_id` FK ; `exercise_session_id` FK ; `level` `CHECK IN ('bronze','silver','gold','diamond')` ; `awarded_at` ; tous non null. Unique `(student_id, exercise_id)`.

**`db/migrate/20260925100029_create_knowledge_gaps.rb`** — `knowledge_gaps` (ADR-0043, tel quel)
- `public_id` ; `student_id` FK `users` non null ; `essential_id` FK non null ; `source_session_id` FK `exercise_sessions` non null ; `status` `CHECK IN ('pending','remediated','self_corrected')` défaut `'pending'` ; `failed_sessions_count` integer non null défaut 1 ; `resolved_at` et `resolved_by_session_id` (FK `exercise_sessions`) nullables.
- Unique partiel `(student_id, essential_id) WHERE status = 'pending'`.
- Puis `add_foreign_key :exercise_sessions, :knowledge_gaps`.

**`db/migrate/20260925100030_create_import_reports.rb`** — `import_reports` (ADR-0039, tel quel, sauf le nom d'une colonne)
- `public_id` ; `kind` string non null `CHECK IN ('schools','course_tree','essentials','exercises')`.
- `status` string non null défaut `'queued'` `CHECK IN ('queued','validating','importing','completed','rejected','failed')`.
- `checksum_sha256` string(64) non null ; `format_version` integer nullable (connu après lecture de l'enveloppe). Le fichier est une pièce jointe Active Storage `source` (bucket, ADR-0047).
- `total_count`, `imported_count`, `skipped_count`, `error_count`, `processed_count` : integer non null défaut 0. `CHECK (status <> 'completed' OR total_count = imported_count + skipped_count + error_count)`.
- `details` jsonb non null défaut `{}` : classes générées, niveaux et séries sautés (ADR-0030).
- **`import_errors`** jsonb non null défaut `[]` : `[{ path:, code:, message: }]`, 1 000 entrées au plus. L'ADR-0039 nomme cette colonne `errors`, que `ActiveModel` réserve (`record.errors`) : erratum.
- `imported_by_id` FK `users` non null ; `started_at` et `finished_at` nullables ; timestamps.
- **Unique partiel `(kind) WHERE status IN ('queued','validating','importing')`**, nommé `index_import_reports_one_running_per_kind` : un second import du même type donne `:conflict`. Index `(kind, created_at)`. **Aucun index unique sur le checksum** : réimporter un fichier est permis, ses éléments déjà écrits sont comptés en doublons.

**`db/migrate/20260925100031_drop_friendly_id_slugs.rb`** — supprime la table `friendly_id_slugs` créée en V0 ; `down` la recrée à l'identique.

**`db/migrate/20260925100032_create_action_text_tables.rb`** — `action_text_rich_texts` (retour du porteur du 2026-09-25, amendement de l'ADR-0051), recréée à l'identique de la migration d'Action Text 8.1 que V0 avait supprimée (`20260925000004_drop_action_text_tables`) : `name` string non null, `body` text, `record_type` string non null, `record_id` bigint non null, timestamps ; unique `(record_type, record_id, name)`. Pas de clé étrangère : l'association est polymorphe, et un cours ou une fiche n'est jamais supprimé, seulement archivé (ADR-0036). Seuls `Orm::Course` et `Orm::Essential` y écrivent, sous le nom `content`.

| Fichier | Contenu | Test |
|---|---|---|
| `db/schema.rb` (modifié) | Régénéré après les 32 migrations | `test/db/schema_constraints_test.rb` (ci-dessous) |

Ce test couvre :
- la longueur de `join_code`, égale à `Entities::Classroom::JoinCode::LENGTH` ;
- chaque index unique et chaque index partiel ci-dessus, et chaque `CHECK` d'énumération (une valeur hors liste lève `ActiveRecord::StatementInvalid`) ;
- l'absence de `on_delete: :cascade` hors de la liste de l'ADR-0036 ;
- l'absence de colonne `updated_at` sur `question_attempts`, et de colonne `code` sur `levels` et `series` ;
- l'absence de table `friendly_id_slugs`, la présence de `action_text_rich_texts` et l'absence de colonne `content` sur `courses` et `essentials`.

### 0a.3 Modèles `Orm::`

Tous les modèles sont dans `app/infrastructure/orm/`. Chacun :
- hérite d'`ApplicationRecord` et déclare `self.table_name` ;
- déclare ses associations avec `class_name: "Orm::…"` et `inverse_of`, et **jamais** `dependent: :destroy` ni `:delete_all` vers la production des élèves (`dependent: :restrict_with_error`, ADR-0036) ;
- porte les validations de **cohérence de schéma**, jamais de règle métier ;
- ne contient **aucun callback métier**. Exceptions : `public_id` et slug.

**Tests.** Les modèles n'ont pas de test propre : les tests de repository (0d, 0e) les couvrent. Seuls les deux concerns et `Orm::User` ont un test.

| Fichier | Particularités |
|---|---|
| `app/infrastructure/orm/has_public_id.rb` | Concern de l'ADR-0029, tel quel : `before_validation(on: :create)`, `validates length: { is: 14 }`, `to_param` |
| `app/infrastructure/orm/has_frozen_slug.rb` | `has_frozen_slug from: :name`. À la création seulement : `parameterize`, puis `-2`, `-3`… tant que le slug existe. `to_param` renvoie le slug. Aucune régénération à la mise à jour. |
| `app/infrastructure/orm/user.rb` | `HasPublicId`, `has_secure_password :pin`, `has_one :teacher_profile, :totp_credential`, `filter_attributes` sur `pin_digest` |
| `app/infrastructure/orm/drena.rb` | `HasPublicId`, `HasFrozenSlug`, `has_many :schools` |
| `app/infrastructure/orm/school.rb` | `HasPublicId`, `belongs_to :drena`, `has_many :classrooms` |
| `app/infrastructure/orm/level.rb` | `HasFrozenSlug`, `has_many :level_series` |
| `app/infrastructure/orm/series.rb` | classe `Orm::Series`, `HasFrozenSlug` |
| `app/infrastructure/orm/level_series.rb` | classe `Orm::LevelSeries`, `self.table_name = "level_series"` |
| `app/infrastructure/orm/material.rb` | `HasFrozenSlug` |
| `app/infrastructure/orm/teacher_profile.rb` | `belongs_to :user, :material` |
| `app/infrastructure/orm/teacher_school.rb` | `belongs_to :teacher, class_name: "Orm::User"`, `belongs_to :school` |
| `app/infrastructure/orm/session.rb` | `belongs_to :user` |
| `app/infrastructure/orm/login_attempt.rb` | `belongs_to :user, optional: true` |
| `app/infrastructure/orm/audit_event.rb` | `belongs_to :actor, optional: true` ; `readonly?` vrai après création |
| `app/infrastructure/orm/totp_credential.rb` | `belongs_to :user`, `encrypts :secret` |
| `app/infrastructure/orm/backup_code.rb` | `belongs_to :user` |
| `app/infrastructure/orm/pin_recovery_code.rb` | `belongs_to :user`, `belongs_to :issued_by` |
| `app/infrastructure/orm/invitation.rb` | `belongs_to :invited_by, optional: true`, `belongs_to :school, optional: true` |
| `app/infrastructure/orm/classroom.rb` | `HasPublicId`, `belongs_to :school, :level`, `belongs_to :series, optional: true`. **Aucune** association polymorphe vers les ressources assignées : c'est la cause du chantier `classroom-assignment-belongs-to-casses`. |
| `app/infrastructure/orm/classroom_student.rb` | `belongs_to :classroom`, `belongs_to :student, class_name: "Orm::User"` |
| `app/infrastructure/orm/teacher_classroom.rb` | `belongs_to :teacher, class_name: "Orm::User"`, `belongs_to :classroom` |
| `app/infrastructure/orm/classroom_assignment.rb` | `HasPublicId`, `belongs_to :classroom`, `belongs_to :assigned_by, class_name: "Orm::User"`. `assignable_type` et `assignable_id` sont de simples colonnes. |
| `app/infrastructure/orm/course.rb` | `HasFrozenSlug`, `has_many :essentials`, **`has_rich_text :content`** (Action Text). |
| `app/infrastructure/orm/essential.rb` | `HasFrozenSlug` (sur le nom du cours puis celui de la fiche), `has_many :exercises`, **`has_rich_text :content`** |
| `app/infrastructure/orm/exercise.rb` | `HasPublicId`, `has_many :questions, -> { order(:position) }` |
| `app/infrastructure/orm/question.rb` | `has_many :answers, -> { order(:position) }` |
| `app/infrastructure/orm/answer.rb` | `belongs_to :question` |
| `app/infrastructure/orm/exercise_session.rb` | `HasPublicId`, `has_many :question_attempts` |
| `app/infrastructure/orm/question_attempt.rb` | `readonly?` vrai si `persisted?` |
| `app/infrastructure/orm/exercise_badge.rb` | `belongs_to :exercise_session` |
| `app/infrastructure/orm/knowledge_gap.rb` | `HasPublicId` |
| `app/infrastructure/orm/import_report.rb` | `HasPublicId`, `has_one_attached :source` |

| Fichier | Test |
|---|---|
| (concerns et `Orm::User` ci-dessus) | `test/infrastructure/orm/has_public_id_test.rb` · `test/infrastructure/orm/has_frozen_slug_test.rb` (renommer ne change pas le slug ; collision → `-2`) · `test/infrastructure/orm/user_test.rb` (PIN absent d'`inspect`) |

### 0a.4 Routes V1

Chaque fichier est dessiné en entier ici ; aucun lot ne les modifie. Dans chaque ressource, `new` précède `:slug`. Aucun `:id` numérique (ADR-0029).

| Fichier | Contenu |
|---|---|
| `config/routes.rb` (modifié) | Garde `root`, `/up`, `draw(:design)` et le montage de Mission Control sous `namespace :teams` (V0). Ajoute `draw :identity`, `:school`, `:classroom`, `:catalog`, `:assessment`, `:communication`, `:teams`. |
| `config/routes/identity.rb` · `config/routes/school.rb` · `config/routes/classroom.rb` · `config/routes/catalog.rb` · `config/routes/assessment.rb` · `config/routes/teams.rb` | voir le bloc ci-dessous |
| `config/routes/communication.rb` | vide, avec le commentaire `# V6` |

```ruby
# identity
get  "login", to: "identity/sessions#new", as: :new_session
resource :session, only: %i[create destroy], controller: "identity/sessions"          # session_path (gelé : DELETE = « Se déconnecter »)
namespace :identity do
  resource :second_factor, only: %i[new create], path: "second-factor"               # new_identity_second_factor_path (ADR-0031)
  resource :second_factor_enrollment, only: %i[new create], path: "second-factor/enrollment"
  resource :pin_reset, only: %i[new create], path: "pin-reset"                        # new_identity_pin_reset_path (ADR-0032)
end
get  "account/pending", to: "identity/pending_accounts#show", as: :pending_account
get  "teacher-signup",  to: "identity/teacher_registrations#new",    as: :new_teacher_registration   # D1
post "teacher-signup",  to: "identity/teacher_registrations#create", as: :teacher_registrations       # D1
get  "invitations/:token", to: "identity/invitations#show",   as: :invitation                        # B7 (ADR-0038)
post "invitations/:token", to: "identity/invitations#accept", as: :accept_invitation                 # B7
post "accounts/:user_public_id/pin-recovery-codes", to: "identity/pin_recovery_codes#create",
     as: :account_pin_recovery_codes                                                                  # B8 (appelé aussi depuis D4)

# school
get "drenas/:drena_public_id/schools", to: "school/drena_schools#index", as: :drena_schools           # D1 : HTML (frame) et JSON (SC-26)

# classroom
get  "join",    to: "classroom/join_codes#new",    as: :new_join_code                                 # A1
post "join",    to: "classroom/join_codes#create", as: :join_codes                                    # A1 (redirige vers /c/:code)
get  "c/:code", to: "classroom/joins#new",    as: :join_classroom                                     # A1 (ADR-0040)
post "c/:code", to: "classroom/joins#create"                                                          # A1
get  "students",           to: "classroom/student_homes#show",      as: :student_home                 # A2 (gelé)
get  "students/classroom", to: "classroom/student_classrooms#show", as: :student_classroom            # A3 (gelé)
get  "teachers",           to: "classroom/teacher_homes#show",      as: :teacher_home                 # D3 (gelé)
get  "teachers/classrooms", to: "classroom/teaching_selections#index", as: :teacher_classrooms        # D2 (gelé)
post   "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#create", as: :classroom_teaching   # D2
delete "teachers/classrooms/:classroom_public_id/teaching", to: "classroom/teachings#destroy"                          # D2
post "teachers/onboarding", to: "classroom/teacher_onboardings#create", as: :teacher_onboarding       # D2
get  "classrooms/:public_id", to: "classroom/classrooms#show", as: :classroom                         # D4
get  "classrooms/:classroom_public_id/courses/:course_slug", to: "classroom/classroom_courses#show", as: :classroom_course    # D5
get  "classrooms/:classroom_public_id/courses/:course_slug/essentials/:essential_slug",
     to: "classroom/classroom_essentials#show", as: :classroom_essential                              # D6
post  "classrooms/:classroom_public_id/assignments", to: "classroom/assignments#create", as: :classroom_assignments    # D5
patch "assignments/:public_id/archive", to: "classroom/assignments#archive", as: :archive_assignment                  # D5
get  "courses/:course_slug/assignments", to: "classroom/course_assignments#index", as: :course_assignments             # D7

# catalog
get "courses",       to: "catalog/courses#index", as: :courses                                         # B1 (gelé)
get "courses/:slug", to: "catalog/courses#show",  as: :course                                          # B1
get "courses/:course_slug/essentials/:slug", to: "catalog/essentials#show", as: :course_essential      # B3

# assessment
get  "exercises/:public_id", to: "assessment/exercises#show", as: :exercise                            # C1
post "exercises/:exercise_public_id/sessions", to: "assessment/exercise_sessions#create", as: :exercise_sessions   # C2
get  "sessions/:public_id", to: "assessment/exercise_sessions#show", as: :exercise_session                        # C2
post "sessions/:public_id/attempts", to: "assessment/question_attempts#create", as: :exercise_session_attempts   # C2
get  "sessions/:public_id/result", to: "assessment/session_results#show", as: :exercise_session_result           # C3
# Pas de route de clôture : la dernière réponse clôt la session (ADR-0054).

# teams — tout contrôleur hérite de Teams::BaseController (second facteur exigé)
get "teams", to: "teams/homes#show", as: :team_home                                                     # B6 (gelé)
scope "teams", module: "teams" do                          # noms sans préfixe, attendus par la navigation 0c
  resources :drenas,    param: :public_id, except: :show                                                # S1
  resources :schools,   param: :public_id do                                                            # S2 → schools_path, ACTIF
    member { patch :deactivate }
    resources :classrooms, only: %i[new create], controller: "school_classrooms"                        # D8
  end
  resources :levels,    param: :slug, except: :show                                                     # R1
  resources :series,    param: :slug, except: :show                                                     # R2 → series_index_path
  resources :level_series, only: %i[create destroy], path: "levels/:level_slug/series",
            param: :series_slug                                                                          # R2
  resources :materials, param: :slug, except: :show                                                     # R3
end
namespace :teams do
  resources :courses, only: %i[new create edit update], param: :slug do                                 # B2
    member { patch :publish; patch :archive }
    resources :essentials, only: %i[new create], param: :slug                                           # B4
  end
  resources :essentials, only: %i[edit update], param: :slug do                                         # B4
    member { patch :publish; patch :archive }
    resources :exercises, only: %i[new create]                                                          # B5
  end
  resources :exercises, only: %i[edit update], param: :public_id do                                     # B5
    member { patch :publish; patch :archive }
  end
  resources :imports, only: %i[index new create show], param: :public_id                                # 0e
  resources :invitations, only: %i[new create]                                                          # B7
  resource  :account_lookup, only: :show, path: "accounts"                                              # B8
  post "members/:user_public_id/second-factor-reset", to: "second_factor_resets#create",
       as: :member_second_factor_reset                                                                   # B8
end
```

`team_dashboard_path` (V4) et `profile_path` (V2) ne sont **pas** créés : la navigation du Lot 0c les rend inactifs. `schools_path` est créé : l'entrée « Établissements » de l'équipe est **active** dès la V1.

| Fichier | Test |
|---|---|
| (routes) | `test/routing/v1_routes_test.rb` : chaque nom de `NavigationHelper::DESTINATIONS` existe pour student, teacher et team, sauf `team_dashboard_path` et `profile_path` ; les sept noms gelés et `schools_path` existent ; `/teams/courses/new` n'est pas capté par un `:slug` ; aucune route ne contient `:id`. |

### 0a.5 Support de test

Chaque fichier de `test/support/` **s'inclut lui-même** (`ActiveSupport::TestCase.include(self)`, ou `ApplicationSystemTestCase` pour les helpers système) : 0d et 0e ajoutent leurs helpers sans toucher à `test_helper.rb`.

| Fichier | Contenu |
|---|---|
| `test/test_helper.rb` (modifié) | Après `rails/test_help` : `Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { require it }`, puis `setup { Rails.cache.clear }`. Rien d'autre ne change (SimpleCov, `parallelize`). |
| `test/support/factories/identity.rb` | `create_user(role:, contact: séquence, pin: "2468", …)`, `create_student(classroom: nil)`, `create_teacher(school:, material:, onboarded: true, classrooms: [])`, `create_team_member(team_role: "admin", second_factor: true)` (renvoie aussi le secret TOTP), `create_invitation(…)`, `create_pin_recovery_code(user:, issued_by:, code: "12345678")` |
| `test/support/factories/school.rb` | `create_drena(name:)`, `create_school(drena:, name:, school_type: "public", cycle: "both", status: "active")` |
| `test/support/factories/classroom.rb` | `create_classroom(school:, level:, series: nil, name:, join_code: :auto, status: "active", max_students: 80)`, `create_assignment(classroom:, assignable:, by:)` |
| `test/support/factories/catalog.rb` | `create_level(name:, position:, cycle:)`, `create_series(name:)`, `link_level_series`, `create_material(name:, category:)`, `create_course(status: "published", content: "<p>…</p>")`, `create_essential(course:, status: "published")`, `seed_referential` : le référentiel du seed de développement (ADR-0034), niveaux, séries, couples et matières |
| `test/support/factories/assessment.rb` | `create_exercise(essential:, status: "published", questions: 2)`, `create_session(student:, exercise:, status:)`, `create_attempt(session:, question:, correct:)`, `create_badge(…)`, `create_gap(…)` |

| Test | Ce qu'il vérifie |
|---|---|
| `test/support/factories_test.rb` | Chaque fabrique crée une ligne valide ; `seed_referential` donne 7 niveaux, 5 séries, 10 couples niveau–série et 7 matières. |

---

## Lot 0b — Domaine pur

- **Couche**       : domaine (Ruby pur)
- **Fichiers**     : les chemins des tableaux 0b.1 à 0b.5, exhaustifs.
- **Dépend de**    : V0 seulement. Parallèle de 0a : aucun fichier commun.
- **Test associé** : colonne « Test » des tableaux ; aucun test de 0b n'ouvre la base.
- **Done quand**   :
  - chaque entité, objet-valeur, policy et DTO a son test, vert, à 100 % lignes et branches ;
  - chaque port est un module dont chaque méthode lève `NotImplementedError`, avec les signatures de 0b.3 ;
  - `DomainPurityTest` est vert ;
  - `bin/ci` est vert. Les ports sont **gelés** au merge.
- **UDR**          : aucune.

### 0b.1 Socle partagé et garde

| Fichier | Contenu | Test |
|---|---|---|
| `app/domain/shared/result.rb` | `Shared::Result = Data.define(:value, :code, :errors)`, tel que dans l'ADR-0026 : `success(value = nil)`, `failure(code, errors: {})`, `success?`, `failure?`, `ERROR_CODES = %i[forbidden not_found invalid conflict locked expired]`. Un code hors liste lève `ArgumentError`. | `test/domain/shared/result_test.rb` |
| `app/domain/ports/shared/transaction_port.rb` | `Ports::Shared::TransactionPort`. `call { … }` → la valeur du bloc ; une exception annule et remonte. `attempt { … }` → `Result.success(valeur)`, ou `Result.failure(:conflict, errors: { base: [:write_failed] })` si la base refuse l'écriture (contrainte, verrou) ; tout est annulé. Le domaine n'a ainsi jamais à nommer une exception d'infrastructure. | couvert par le repository (0d) |
| `app/domain/entities/shared/natural_key.rb` | `Entities::Shared::NaturalKey.normalize(text)` : `squish`, minuscules, sans accents (`ActiveSupport::Inflector.transliterate`). Clé de doublon des imports (ADR-0039). | `test/domain/entities/shared/natural_key_test.rb` (« Lycée  Moderne » = « lycee moderne ») |
| `test/domain/domain_purity_test.rb` (modifié) | `FORBIDDEN` couvre aussi `ActiveStorage`, `ActionController` et `ActionDispatch`, avec un cas de plus dans le test de détection. | lui-même |

### 0b.2 Entités et objets-valeurs

**Règles communes aux entités** (ADR-0026) : un objet Ruby ou un `Data`. `ActiveModel::Model`, `Validations` et `Attributes` sont tolérés, rien d'autre. Aucune mention d'`ActiveRecord`, `Orm::`, `Repositories::`, `Queries::`, `ActiveStorage` ni `ActionController`. Les constantes métier sont **nommées** dans l'entité qui les porte.

| Fichier | Classe | Attributs et règles | Test |
|---|---|---|---|
| `app/domain/entities/identity/actor.rb` | `Entities::Identity::Actor` (Data) | `user_id, role, team_role, school_id` (ADR-0028). `role` ∈ `:student, :teacher, :school_admin, :team`. Un visiteur est `actor: nil`. Un compte `team` sans second facteur vérifié n'obtient **jamais** d'`Actor`. | `test/domain/entities/identity/actor_test.rb` |
| `app/domain/entities/identity/user.rb` | `Entities::Identity::User` | `id, public_id, last_name, first_name, contact, gender, role, team_role, anonymized_at`. Validation du nom selon l'ADR-0037 (`NAME_FORMAT`, 50 et 80, `squish` seulement). `display_name` = `"#{first_name} #{last_name}"`, sans changement de casse. `ROLES`, `GENDERS = %w[male female]`. | `test/domain/entities/identity/user_test.rb` |
| `app/domain/entities/identity/contact.rb` | `Entities::Identity::Contact` | `FORMAT = /\A0[157]\d{8}\z/`, `normalize(raw)` tel que dans l'ADR-0050 (retire `00225` sur 15 chiffres, `225` sur 13), renvoie `nil` si invalide. | `test/domain/entities/identity/contact_test.rb` |
| `app/domain/entities/identity/pin.rb` | `Entities::Identity::Pin` | `FORMAT = /\A\d{4}\z/`. Le PIN n'est jamais dérivé du contact et n'est jamais stocké dans une entité. | `test/domain/entities/identity/pin_test.rb` |
| `app/domain/entities/identity/session_lifetime.rb` | `Entities::Identity::SessionLifetime` | `IDLE_TTL = 30.days` ; `ABSOLUTE_TTL = { team: 12.hours, school_admin: 12.hours }` ; `TOUCH_EVERY = 5.minutes`. `expired?(role:, created_at:, last_seen_at:, now:)`. | `test/domain/entities/identity/session_lifetime_test.rb` |
| `app/domain/entities/identity/lockout.rb` | `Entities::Identity::Lockout` | Paliers d'échecs **consécutifs** depuis le dernier succès : `{ 5 => 15.minutes, 10 => 1.hour, 20 => :until_recovery }`. `retry_after(failures:, last_failed_at:, now:)` renvoie `nil` ou une durée (ou `:until_recovery`). | `test/domain/entities/identity/lockout_test.rb` (4, 5, 9, 10, 19, 20 échecs) |
| `app/domain/entities/identity/audit_action.rb` | `Entities::Identity::AuditAction` | Liste fermée `ALL` : `login.locked`, `totp.enrolled`, `totp.reset`, `backup_code.used`, `pin.recovery_code_issued`, `pin.reset`, `invitation.sent`, `invitation.accepted`, `content.published`, `content.archived`, `taxonomy.changed`, `school.changed`, `import.run`. | `test/domain/entities/identity/audit_action_test.rb` |
| `app/domain/entities/identity/secret_digest.rb` | `Entities::Identity::SecretDigest` | `hmac(value, key:)` (HMAC-SHA256 hexadécimal, `OpenSSL` de la bibliothèque standard) et `secure_compare`. La clé est injectée par le contrôleur (`key_generator.generate_key("lnclass-secrets")`). | `test/domain/entities/identity/secret_digest_test.rb` |
| `app/domain/entities/identity/backup_codes.rb` | `Entities::Identity::BackupCodes` | `COUNT = 10`, `LENGTH = 10`, `generate` (base58). | `test/domain/entities/identity/backup_codes_test.rb` |
| `app/domain/entities/identity/pin_recovery_code.rb` | `Entities::Identity::PinRecoveryCode` | `TTL = 15.minutes`, `LENGTH = 8` chiffres, `MAX_FAILED_ATTEMPTS = 5`, `generate`, `status(now:)` → `:usable`, `:expired` ou `:revoked`. | `test/domain/entities/identity/pin_recovery_code_test.rb` |
| `app/domain/entities/identity/invitation.rb` | `Entities::Identity::Invitation` | `TTL = 72.hours`, `TOKEN_LENGTH = 32` (base58), `status(now:)` → `:pending`, `:expired`, `:accepted` ou `:revoked`. | `test/domain/entities/identity/invitation_test.rb` |
| `app/domain/entities/identity/teacher_profile.rb` | `Entities::Identity::TeacherProfile` (Data) | `user_id, material_id, onboarding_completed_at`, `onboarded?` | couvert par le repository |
| `app/domain/entities/identity/session_state.rb` | `Entities::Identity::SessionState` (Data) | `id, user_id, role, created_at, last_seen_at, second_factor_verified_at, second_factor_confirmed`. `verified?`. Fait des policies de session. | couvert par `session_policy_test` |
| `app/domain/entities/identity/home_destination.rb` | `Entities::Identity::HomeDestination` | `for(actor:, primary_membership:, primary_school_id:, onboarded:)` → symbole. **Student** : `:student_home` s'il a une classe principale active, sinon `:pending_account`. **Teacher** : `:pending_account` sans école principale, `:teacher_classrooms` si l'onboarding n'est pas fini, sinon `:teacher_home`. **Team** : `:team_home`. **School_admin** : `:pending_account` (V2). Aucune destination ne renvoie vers une page qui la redirige elle-même. | `test/domain/entities/identity/home_destination_test.rb` |
| `app/domain/entities/school/drena.rb` | `Entities::School::Drena` | `id, public_id, slug, name` ; `name` présent, 80 au plus, `squish`. | `test/domain/entities/school/drena_test.rb` |
| `app/domain/entities/school/school.rb` | `Entities::School::School` | `id, public_id, drena_id, name, sigle, status, school_type, cycle`. `SCHOOL_TYPES = %w[public private mixed]`, `STATUSES = %w[draft active inactive]`, `CYCLES = %w[first both]`. `self.cycle_for(name:)` : `'first'` si le nom **contient** « collège », accents et casse ignorés (« Collége », « COLLEGE »), sinon `'both'` (ADR-0030). `plan_type` : `"public"` pour `public`, `"private"` sinon (un établissement `mixed` suit le barème privé). Nom enregistré tel que saisi, après `squish` (ADR-0037). | `test/domain/entities/school/school_test.rb` |
| `app/domain/entities/classroom/school_year.rb` | `Entities::Classroom::SchoolYear` | `START_MONTH = 9`, `current(date)`, tel que dans l'ADR-0041. | `test/domain/entities/classroom/school_year_test.rb` |
| `app/domain/entities/classroom/join_code.rb` | `Entities::Classroom::JoinCode` | `LETTERS = ("a".."z").to_a - %w[i o]`, `DIGITS = ("2".."9").to_a`, `LENGTH = 5`. `generate(random:)` : 3 lettres puis 2 chiffres. `generate_unique(count:, taken:, random:)` tire `count` codes distincts, hors de l'ensemble `taken`, qu'il complète. `normalize(raw)` retire les espaces et passe en minuscules. `display(code)` passe en majuscules (CL-04). | `test/domain/entities/classroom/join_code_test.rb` |
| `app/domain/entities/classroom/classroom.rb` | `Entities::Classroom::Classroom` | `id, public_id, school_id, level_id, series_id, name, school_year, status, join_code, max_students, teacher_ids, active_students_count`. `active?`. `name` présent, 15 au plus. | `test/domain/entities/classroom/classroom_test.rb` |
| `app/domain/entities/classroom/default_classroom_plan.rb` | `Entities::Classroom::DefaultClassroomPlan` | `PLAN` de l'ADR-0030, **tel quel**, par slug de niveau et de série. `for(school_type)`. `rows_for(school:, lookup:)` → `Data(rows, skipped)` : `rows` = `[{ name:, level_id:, series_id: }]` ; une école `cycle: 'first'` n'a que les niveaux de cycle `first` ; « par série » = chaque série liée au niveau dans `level_series` ; une série nommée n'est prise que si le couple existe ; un niveau ou une série absent est **sauté** et listé dans `skipped` (`{ levels: [...], series: [...] }`). Nom toujours espacé : « 6ème 1 », « Tle D 3 », « 1ère A1 2 ». **Aucun élève de démonstration.** | `test/domain/entities/classroom/default_classroom_plan_test.rb` : avec le référentiel du seed, lycée public = **77** classes, privé = **38**, mixte = 38, collège public = **28** et aucune de second cycle ; une `1ere` sans série est sautée et comptée |
| `app/domain/entities/classroom/membership.rb` | `Entities::Classroom::Membership` (Data) | `classroom_id, student_id, primary, joined_at, left_at, classroom_status`, `active?` | couvert par le repository |
| `app/domain/entities/classroom/assignable.rb` | `Entities::Classroom::Assignable` (Data `type, id, key, name`) | `TYPES = %w[Course Essential Exercise]` (ADR-0048). Un type hors liste lève `ArgumentError`. | `test/domain/entities/classroom/assignable_test.rb` |
| `app/domain/entities/classroom/assignment.rb` | `Entities::Classroom::Assignment` (Data) | `id, public_id, classroom_id, assignable, status, assigned_by_id, assigned_at, archived_at`. `active?`. Une réassignation crée une **nouvelle** ligne (ADR-0048). | `test/domain/entities/classroom/assignment_test.rb` |
| `app/domain/entities/catalog/content_status.rb` | `Entities::Catalog::ContentStatus` | `VALUES = %w[draft published archived]`. `TRANSITIONS = { "draft" => %w[published], "published" => %w[archived], "archived" => %w[published] }`. Retour à `draft` interdit (ADR-0035). `transition(from:, to:, parent_published:)` → `Shared::Result`, `:conflict` sinon. | `test/domain/entities/catalog/content_status_test.rb` |
| `app/domain/entities/catalog/level.rb` | `Entities::Catalog::Level` | `id, slug, name, position, cycle`. `CYCLES = %w[first second]`. `name` présent, 20 au plus. Le slug est figé : c'est le code du plan de génération. | `test/domain/entities/catalog/level_test.rb` |
| `app/domain/entities/catalog/series.rb` | `Entities::Catalog::Series` | `id, slug, name` ; `name` présent, 10 au plus. | `test/domain/entities/catalog/series_test.rb` |
| `app/domain/entities/catalog/material.rb` | `Entities::Catalog::Material` | `id, slug, name, shortname, category`. `CATEGORIES = %w[literature science other]`, **obligatoire** (CA-26). `shortname` : 10 au plus. | `test/domain/entities/catalog/material_test.rb` |
| `app/domain/entities/catalog/taxonomy_lookup.rb` | `Entities::Catalog::TaxonomyLookup` (Data) | Index en mémoire construit par `TaxonomyRepositoryPort#lookup` : niveaux, séries et matières par slug (matières aussi par `shortname` paramétrisé), couples niveau–série. `resolve_level(name)`, `resolve_series(name)`, `resolve_material(name)` comparent `name.parameterize` au slug (ADR-0039). `pair?(level_id, series_id)`, `series_for(level_id)`. | `test/domain/entities/catalog/taxonomy_lookup_test.rb` (« Physique Chimie » → `physique-chimie` ; « 1ère » → `1ere`) |
| `app/domain/entities/catalog/course.rb` | `Entities::Catalog::Course` | `id, slug, name, subtitle, content, level_id, series_id, material_id, author_id, status, published_at, archived_at`. `name` présent (200 au plus), `squish` sans changement de casse. `readable_chain_published?`. **Une seule entité** pour la lecture et l'écriture (chantier `catalog-lecture-ecriture-incompatibles`). | `test/domain/entities/catalog/course_test.rb` |
| `app/domain/entities/catalog/essential.rb` | `Entities::Catalog::Essential` | `id, slug, course_id, name, subtitle, content, position, author_id, status, published_at, archived_at, course_status`. `readable_chain_published?` exige aussi le cours publié. | `test/domain/entities/catalog/essential_test.rb` |
| `app/domain/entities/catalog/slug.rb` | `Entities::Catalog::Slug` | `unique(base_name, taken:)` : `parameterize`, puis `-2`, `-3`… hors de `taken`, qu'il complète. Même règle que `Orm::HasFrozenSlug`, pour les écritures en masse (ADR-0039 : identifiants calculés avant l'insertion). | `test/domain/entities/catalog/slug_test.rb` |
| `app/domain/entities/catalog/import_kind.rb` | `Entities::Catalog::ImportKind` | Registre **fermé** des quatre types de l'ADR-0039 : `kind`, `format`, `version` (1), clé des éléments racines, clé de cible, `max_roots`, `policy`. `schools` : `lnclass.schools`, `schools`, cible `drena` (facultative si chaque école porte la sienne), 5 000, `Policies::School::ManageSchoolPolicy`. `course_tree` : `lnclass.course-tree`, `courses`, pas de cible, 500, `Policies::Catalog::ManageContentPolicy`. `essentials` : `lnclass.essentials`, `essentials`, cible `course`, 2 000, idem. `exercises` : `lnclass.exercises`, `exercises`, cible `essential`, 10 000, idem. `MAX_BYTES = 20 * 1024 * 1024`. `MAX_ERRORS = 1_000`. `BATCH_SIZE = 100`. | `test/domain/entities/catalog/import_kind_test.rb` |
| `app/domain/entities/catalog/import_error.rb` | `Entities::Catalog::ImportError` (Data `path, code, params`) | `path` en notation JSON (`schools[412].type`, `$` pour le fichier). `BLOCKING` (rejet en bloc) : `json_invalid`, `format_mismatch`, `version_unsupported`, `unknown_target`, `too_many_roots`, `too_large`. `ELEMENT` : `schema`, `blank`, `too_long`, `unknown_level`, `unknown_series`, `unknown_material`, `unknown_drena`, `series_not_allowed`, `invalid_value`, `question_structure`, `write_failed`. Un code hors liste lève `ArgumentError`. | `test/domain/entities/catalog/import_error_test.rb` |
| `app/domain/entities/catalog/import_item.rb` | `Entities::Catalog::ImportItem` (Data `path, key, plan, errors`) | Verdict d'un élément racine : `valid?` si `errors` est vide. `key` : clé de doublon normalisée. `plan` : ce que l'adaptateur écrira, opaque pour le moteur. | `test/domain/entities/catalog/import_item_test.rb` |
| `app/domain/entities/catalog/import_context.rb` | `Entities::Catalog::ImportContext` (Data `target, existing_keys, data`) | Préparé une fois par l'adaptateur : la cible résolue, l'ensemble des clés déjà en base, et ses référentiels chargés (`data`). | couvert par `run_import_test` (0e) |
| `app/domain/entities/catalog/import_report.rb` | `Entities::Catalog::ImportReport` (Data) | `id, public_id, kind, status, format_version, total_count, imported_count, skipped_count, error_count, processed_count, details, import_errors, imported_by_id, started_at, finished_at`. `STATUSES`, `RUNNING = %w[queued validating importing]`, `running?`. | `test/domain/entities/catalog/import_report_test.rb` |
| `app/domain/entities/catalog/content_node.rb` | `Entities::Catalog::ContentNode` | Validateurs partagés par I1, I2 et I3 : `validate_course(hash, path:, lookup:)`, `validate_essential(hash, path:)`, `validate_exercise(hash, path:)` → `[ImportError]`. Noms présents et bornés ; `exercise_type` ∈ `fixation`, `evaluation` ; au moins une question ; cohérence de chaque question par `Entities::Assessment::Question.structure_errors_for` (ADR-0039). La clé `status` est ignorée : tout naît `draft`. | `test/domain/entities/catalog/content_node_test.rb` |
| `app/domain/entities/assessment/grading.rb` | `Entities::Assessment::Grading` | Tel que dans l'ADR-0033 : `PASS_THRESHOLD = 50`, `MASTERY_THRESHOLD = 70`, `GOLD_THRESHOLD = 80`, `PERFECT_THRESHOLD = 100`, `BADGE_THRESHOLDS = { bronze: 50, silver: 70, gold: 80, diamond: 100 }`, `BADGE_ORDER = %i[bronze silver gold diamond]`, `badge_for(score)`, `upgrade?(current, candidate)`. Plus `score_percent(correct:, total:)` en **division entière**, `grade_on_20(score)` = `(score / 5.0).round`, `mastery_for(score)` → `:acquired` (≥ 70), `:fragile` (50 à 69), `:struggling` (< 50). | `test/domain/entities/assessment/grading_test.rb` : bornes 49, 50, 69, 70, 79, 80, 99, 100 ; 9/10 donne 90 et Or, jamais Diamant |
| `app/domain/entities/assessment/gap_decision.rb` | `Entities::Assessment::GapDecision` | Tel que dans l'ADR-0043, validé par le porteur : `:open`, `:increment`, `:remediated`, `:self_corrected` ou `:none`. | `test/domain/entities/assessment/gap_decision_test.rb` |
| `app/domain/entities/assessment/answer.rb` | `Entities::Assessment::Answer` (Data) | `id, position, content, correct` | couvert par `question_test` |
| `app/domain/entities/assessment/question.rb` | `Entities::Assessment::Question` | `id, position, content, explanation, question_type, answers`. `EXPECTED = { true_false: 1, single_choice: 1, multiple_correct_2: 2, multiple_correct_3: 3 }`. `well_formed?(selected_ids)` et `correct?(selected_ids)` tels que dans l'ADR-0054. `self.structure_errors_for(question_type:, answers:)` applique les règles de l'ADR-0039 (`true_false` : exactement 2 propositions). `without_correction` renvoie une copie sans le champ `correct`. | `test/domain/entities/assessment/question_test.rb` |
| `app/domain/entities/assessment/exercise.rb` | `Entities::Assessment::Exercise` | `id, public_id, essential_id, title, description, exercise_type, position, author_id, status, published_at, archived_at, questions, parents_published`. `publishable?` : au moins une question, toutes bien formées (ADR-0035). `questions_locked?(has_attempts:)`. | `test/domain/entities/assessment/exercise_test.rb` |
| `app/domain/entities/assessment/exercise_session.rb` | `Entities::Assessment::ExerciseSession` | `id, public_id, student_id, exercise_id, status, question_count, answered_count, correct_count, progress_percent, score_percent, kind, knowledge_gap_id, classroom_assignment_id, started_at, completed_at`. `STATUSES = %w[started completed abandoned]`. `complete?` quand `answered_count == question_count`. | `test/domain/entities/assessment/exercise_session_test.rb` |
| `app/domain/entities/assessment/question_attempt.rb` | `Entities::Assessment::QuestionAttempt` (Data) | `session_id, question_id, selected_answer_ids, correct, answered_at` | couvert par le repository |
| `app/domain/entities/assessment/badge.rb` | `Entities::Assessment::Badge` (Data) | `student_id, exercise_id, session_id, level, awarded_at` | couvert par le repository |
| `app/domain/entities/assessment/knowledge_gap.rb` | `Entities::Assessment::KnowledgeGap` (Data) | `id, student_id, essential_id, status, failed_sessions_count` | couvert par le repository |

### 0b.3 Ports

**Forme d'un port.** Un port est un `module` dont chaque méthode lève `NotImplementedError`. Le repository fait `include` du port et convertit chaque ligne `Orm::` en entité, par une méthode privée `map_to_entity`. **Aucun objet `Orm::` ne sort d'un repository.**

**Pas de dossier `adapters/`** (ADR-0027). Ce qui parle à une gemme ou à un service vit dans un repository de son contexte : la TOTP (`rotp`) dans `SecondFactorRepository` ; le fichier d'import (Active Storage) dans `ImportFileStore` ; la validation par schéma (`json_schemer`) dans `ImportSchemaValidator` ; la mise en file du job dans `ImportQueue`.

**Les dates.** Les méthodes qui dépendent du temps reçoivent `at:` ou `now:`. Les use cases reçoivent une horloge `clock:` injectée, qui vaut `Time` par défaut.

**Les transactions.** Un repository n'ouvre **jamais** de transaction lui-même : c'est le use case qui les ouvre, par `TransactionPort` (ADR-0026). Les méthodes marquées « verrou » font un `SELECT … FOR UPDATE` et ne sont appelées que dans un bloc de transaction.

**Écritures en masse** (ADR-0039 §4.5, ADR-0020 §2.1 et §2.2). `insert_many`, `insert_generated` et `ContentTreeWriterPort#write` font des `insert_all` avec `returning: %w[id …]`. Le domaine calcule avant l'insertion `public_id`, slugs et codes d'adhésion, uniques en base **et** dans le lot ; le repository pose `created_at` et `updated_at`, puisque `insert_all` saute les callbacks des concerns.

| Port (0b) | Implémenté par (sous-lot) |
|---|---|
| `app/domain/ports/identity/user_repository_port.rb` | `UserRepository` (0d) |
| `app/domain/ports/identity/registration_repository_port.rb` | `RegistrationRepository` (0d) |
| `app/domain/ports/identity/teacher_profile_repository_port.rb` | `TeacherProfileRepository` (0d) |
| `app/domain/ports/identity/session_repository_port.rb` | `SessionRepository` (0d) |
| `app/domain/ports/identity/login_attempt_repository_port.rb` | `LoginAttemptRepository` (0d) |
| `app/domain/ports/identity/audit_log_port.rb` | `AuditLogRepository` (0d) |
| `app/domain/ports/identity/second_factor_repository_port.rb` | `SecondFactorRepository` (0d) |
| `app/domain/ports/identity/pin_recovery_repository_port.rb` | `PinRecoveryRepository` (0d) |
| `app/domain/ports/identity/invitation_repository_port.rb` | `InvitationRepository` (0d) |
| `app/domain/ports/school/drena_repository_port.rb` | `DrenaRepository` (0e) |
| `app/domain/ports/school/school_repository_port.rb` | `SchoolRepository` (0e) |
| `app/domain/ports/classroom/classroom_repository_port.rb` | `ClassroomRepository` (0e) |
| `app/domain/ports/classroom/membership_repository_port.rb` | `MembershipRepository` (0e) |
| `app/domain/ports/classroom/teaching_repository_port.rb` | `TeachingRepository` (0e) |
| `app/domain/ports/classroom/assignment_repository_port.rb` | `AssignmentRepository` (0e) |
| `app/domain/ports/catalog/taxonomy_repository_port.rb` | `TaxonomyRepository` (0e) |
| `app/domain/ports/catalog/course_repository_port.rb` | `CourseRepository` (0e) |
| `app/domain/ports/catalog/essential_repository_port.rb` | `EssentialRepository` (0e) |
| `app/domain/ports/catalog/content_tree_writer_port.rb` | `ContentTreeWriter` (0e) |
| `app/domain/ports/catalog/import_report_repository_port.rb` | `ImportReportRepository` (0e) |
| `app/domain/ports/catalog/import_file_store_port.rb` | `ImportFileStore` (0e) |
| `app/domain/ports/catalog/import_schema_port.rb` | `ImportSchemaValidator` (0e) |
| `app/domain/ports/catalog/import_queue_port.rb` | `ImportQueue` (0e) |
| `app/domain/ports/assessment/exercise_repository_port.rb` | `ExerciseRepository` (0e) |
| `app/domain/ports/assessment/exercise_session_repository_port.rb` | `ExerciseSessionRepository` (0e) |
| `app/domain/ports/assessment/badge_repository_port.rb` | `BadgeRepository` (0e) |
| `app/domain/ports/assessment/knowledge_gap_repository_port.rb` | `KnowledgeGapRepository` (0e) |

Test de 0b : `test/domain/ports/ports_shape_test.rb` — chaque module de `app/domain/ports/**` lève `NotImplementedError` sur chaque méthode, pour un objet vide qui l'inclut, et chaque méthode n'a que des arguments nommés. (Le test « un seul implémenteur, mêmes paramètres » est écrit par 0e, quand les implémenteurs existent.)

**Signatures gelées.** Toutes les méthodes prennent des arguments nommés. `→` indique le type de retour ; `nil` signifie « absent » ; `Result` désigne `Shared::Result`.

```ruby
Ports::Identity::UserRepositoryPort
  find(id:) · find_by_public_id(public_id:) · find_by_contact(contact:) → Entities::Identity::User | nil
  authenticate(contact:, pin:)           → User | nil        # bcrypt, temps constant même si le numéro est inconnu
  update_pin(user_id:, pin:)             → true
  actor_for(user_id:)                    → Entities::Identity::Actor   # school_id = école principale de l'enseignant, sinon nil

Ports::Identity::RegistrationRepositoryPort   # appelé dans la transaction du use case ; RecordNotUnique → :conflict
  create_student(user:, pin:)            → Result(User) | failure(:conflict, errors: { contact: [:taken] })
  create_teacher(user:, pin:, material_id:) → Result(User) | failure(:conflict, …)   # crée aussi teacher_profiles
  create_from_invitation(user:, pin:, invitation_id:, at:) → Result(User) | failure(:conflict, …)

Ports::Identity::TeacherProfileRepositoryPort
  find_by_user_id(user_id:)              → Entities::Identity::TeacherProfile | nil
  complete_onboarding(user_id:, at:)     → true               # idempotent

Ports::Identity::SessionRepositoryPort
  create(user_id:, token_digest:, ip:, user_agent:, at:) → Integer (id)
  find_by_token_digest(token_digest:)    → Entities::Identity::SessionState | nil
  touch(id:, at:) · mark_second_factor_verified(id:, at:) · destroy(id:) → true
  destroy_all_for(user_id:)              → Integer

Ports::Identity::LoginAttemptRepositoryPort
  record(contact:, user_id:, ip:, succeeded:, kind:, at:) → true
  consecutive_failures(contact:, kind:)  → Data(count, last_failed_at)   # depuis le dernier succès
  clear_failures(contact:)               → Integer            # après un PIN réinitialisé (ADR-0032)

Ports::Identity::AuditLogPort
  record(action:, actor_id:, subject_type: nil, subject_id: nil, metadata: {}, ip: nil, at:) → true
                                          # action ∈ Entities::Identity::AuditAction::ALL, sinon ArgumentError

Ports::Identity::SecondFactorRepositoryPort
  state_for(user_id:)                    → Data(confirmed, backup_codes_left) | nil
  begin_enrollment(user_id:, label:)     → Data(secret, provisioning_uri)   # remplace un secret non confirmé
  verify_code(user_id:, code:, now:)     → Integer (pas accepté) | nil      # ±1 pas ; refuse step ≤ last_used_step, puis l'enregistre
  confirm(user_id:, backup_code_digests:, at:) → true         # remplace les codes de secours existants
  consume_backup_code(user_id:, code_digest:, at:) → Boolean
  reset(user_id:)                        → true               # supprime le secret et les codes (ADR-0031)

Ports::Identity::PinRecoveryRepositoryPort
  issue(user_id:, issued_by_id:, code_digest:, expires_at:, at:) → true   # révoque le code actif précédent
  active_for(user_id:)                   → Data(id, code_digest, expires_at, failed_attempts) | nil
  record_failure(id:, at:)               → Integer            # nouveau compteur ; révoque à MAX_FAILED_ATTEMPTS
  consume(id:, at:)                      → true

Ports::Identity::InvitationRepositoryPort
  create(kind:, contact:, team_role:, invited_by_id:, token_digest:, expires_at:) → Result(Entities::Identity::Invitation) | failure(:conflict)
  find_by_token_digest(token_digest:)    → Invitation | nil
  mark_accepted(id:, user_id:, at:)      → true

Ports::School::DrenaRepositoryPort
  all                                    → [Entities::School::Drena]   # triées par nom
  find_by_public_id(public_id:) · find_by_slug(slug:) → Drena | nil
  create(drena:) · update(drena:)        → Result(Drena) | failure(:conflict, errors: { name: [:taken] })   # slug figé
  delete(id:)                            → Result | failure(:conflict, errors: { base: [:has_schools] })
  ids_by_slug                            → { "abidjan-1" => 12, … }

Ports::School::SchoolRepositoryPort
  find_by_public_id(public_id:)          → Entities::School::School | nil
  create(school:) · update(school:)      → Result(School) | failure(:conflict, errors: { name: [:taken] })
  delete_if_unreferenced(id:)            → Result | failure(:conflict, errors: { base: [:referenced] })
                                          # supprime aussi ses classes si aucune n'a d'élève, d'enseignant ni d'assignation
  existing_keys(drena_ids:)              → Set[[drena_id, natural_key]]
  insert_many(rows:, at:)                → [Data(id, public_id, drena_id, name, school_type, cycle)]   # public_id fournis
  attach_teacher(teacher_id:, school_id:, primary:, at:) → Result | failure(:conflict)  # ADR-0030
  primary_school_id_for(teacher_id:)     → Integer | nil

Ports::Classroom::ClassroomRepositoryPort
  find_by_public_id(public_id:)          → Entities::Classroom::Classroom | nil   # avec teacher_ids et active_students_count
  lock_by_join_code(join_code:)          → Classroom | nil   # verrou ; code déjà normalisé
  create(classroom:)                     → Result(Classroom) | failure(:conflict, errors: { name: [:taken] })
                                          # tire le code d'adhésion et retente une fois sur collision (ADR-0029)
  taken_join_codes                       → Set[String]
  insert_generated(rows:, at:)           → Integer            # rows portent public_id et join_code déjà tirés
  names_in(school_id:, school_year:)     → Set[String]

Ports::Classroom::MembershipRepositoryPort
  primary_for(student_id:)               → Entities::Classroom::Membership | nil   # active, avec le statut de la classe
  add_primary(classroom_id:, student_id:, at:) → Result | failure(:conflict)
  leave_primary(student_id:, at:)        → true               # pose left_at (JoinAsStudent, ADR-0040)

Ports::Classroom::TeachingRepositoryPort
  declare(teacher_id:, classroom_id:, at:) → :created | :already
  withdraw(teacher_id:, classroom_id:)   → true
  classroom_ids_for(teacher_id:)         → [Integer]

Ports::Classroom::AssignmentRepositoryPort
  active_for(classroom_id:, assignable:) → Entities::Classroom::Assignment | nil
  find_by_public_id(public_id:)          → Assignment | nil
  create(assignment:)                    → Result(Assignment) | failure(:conflict)   # index partiel actif (ADR-0048)
  archive(id:, archived_by_id:, at:)     → true
  resolve_assignable(type:, key:)        → Data(assignable, status, parents_published) | nil
                                          # key = slug (Course, Essential) ou public_id (Exercise)

Ports::Catalog::TaxonomyRepositoryPort
  levels · series · materials            → [Entities::Catalog::Level] · [Series] · [Material]   # triés
  find_level(slug:) · find_series(slug:) · find_material(slug:) → entité | nil
  create_level(level:) · update_level(level:) → Result(Level) | failure(:conflict, errors: { <champ>: [:taken] })
  create_series(series:) · update_series(series:) · create_material(material:) · update_material(material:) → idem
  delete_level(id:) · delete_series(id:) · delete_material(id:) → Result | failure(:conflict, errors: { base: [:referenced] })
  link(level_id:, series_id:, at:)       → Result | failure(:conflict)
  unlink(level_id:, series_id:)          → Result | failure(:conflict, errors: { base: [:referenced] })  # classes ou cours existants
  lookup                                 → Entities::Catalog::TaxonomyLookup

Ports::Catalog::CourseRepositoryPort
  find_by_slug(slug:)                    → Entities::Catalog::Course | nil   # tous statuts
  create(course:) · update(course:)      → Result(Course) | failure(:conflict, errors: { name: [:taken] })
  transition(id:, to:, at:)              → true               # pose published_at ou archived_at
  existing_keys                          → Set[[natural_key, level_id, material_id, series_id]]
  taken_slugs                            → Set[String]

Ports::Catalog::EssentialRepositoryPort
  find_by_slug(slug:)                    → Entities::Catalog::Essential | nil
  create(essential:) · update(essential:) → Result(Essential) | failure(:conflict, …)   # position = max + 1
  transition(id:, to:, at:)              → true
  existing_keys(course_ids: nil)         → Set[[course_id, natural_key]]
  next_position(course_id:)              → Integer
  taken_slugs                            → Set[String]

Ports::Catalog::ContentTreeWriterPort
  write(courses: [], essentials: [], exercises: [], author_id:, at:) → { courses:, essentials:, exercises:, questions:, answers: }
                                          # arbres déjà validés et identifiés ; tout en draft ; insert_all par table, parents d'abord

Ports::Catalog::ImportReportRepositoryPort
  create(kind:, checksum_sha256:, imported_by_id:, at:) → Result(Entities::Catalog::ImportReport)
                                          | failure(:conflict, errors: { kind: [:already_running] })   # index partiel par kind
  find(id:) · find_by_public_id(public_id:) → ImportReport | nil
  fail_stale(kind:, before:, at:)        → Integer            # validating ou importing commencé avant `before` → failed
  claim(id:, at:)                        → Boolean            # UPDATE … SET status = 'validating' WHERE status = 'queued'
  advance(id:, status:, processed_count:, format_version: nil) → true   # au plus une écriture toutes les 100 racines
  finish(id:, status:, counts:, details:, errors:, at:) → true   # completed, rejected ou failed ; 1 000 erreurs au plus

Ports::Catalog::ImportFileStorePort
  attach(report_id:, io:, filename:)     → true               # Active Storage, service railway (ADR-0047)
  read(report_id:)                       → String

Ports::Catalog::ImportSchemaPort
  validate(format:, version:, document:) → [Entities::Catalog::ImportError]   # config/schemas/<format>.v<version>.json

Ports::Catalog::ImportQueuePort
  enqueue(kind:, report_id:)             → true               # job du type, résolu à l'appel

Ports::Assessment::ExerciseRepositoryPort
  find_by_public_id(public_id:)          → Entities::Assessment::Exercise | nil   # questions, propositions, parents_published
  create(exercise:)                      → Exercise           # exercice, questions et propositions
  update(exercise:, replace_questions:)  → Exercise
  transition(id:, to:, at:)              → true
  has_sessions?(exercise_id:)            → Boolean
  existing_keys(essential_ids: nil)      → Set[[essential_id, natural_key]]
  next_positions(essential_ids:)         → { essential_id => Integer }

Ports::Assessment::ExerciseSessionRepositoryPort
  find_by_public_id(public_id:, lock: false) → Entities::Assessment::ExerciseSession | nil   # lock: true = verrou
  started_for(student_id:, exercise_id:) → ExerciseSession | nil
  start(session:)                        → ExerciseSession    # RecordNotUnique (session started) → renvoie la session existante
  abandon(id:, at:)                      → true
  record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:) → :recorded | :duplicate
                                          # insère la tentative et met à jour answered_count, correct_count, progress_percent
  attempts(session_id:)                  → [Entities::Assessment::QuestionAttempt]
  complete(id:, score_percent:, at:)     → true               # UPDATE … WHERE status = 'started'

Ports::Assessment::BadgeRepositoryPort
  find(student_id:, exercise_id:)        → Entities::Assessment::Badge | nil
  upsert(badge:)                         → Badge              # sur (student_id, exercise_id)

Ports::Assessment::KnowledgeGapRepositoryPort
  pending_for(student_id:, essential_id:) → Entities::Assessment::KnowledgeGap | nil
  find(id:)                              → KnowledgeGap | nil
  open(student_id:, essential_id:, source_session_id:, at:) → KnowledgeGap
  increment(id:)                         → true
  resolve(id:, status:, session_id:, at:) → true
```

### 0b.4 Policies

Forme unique : `Policies::<Ctx>::<Nom>Policy.new.call(actor:, **faits) → Shared::Result` (ADR-0028).
- Le succès est `Result.success`. Le refus est `Result.failure(:forbidden)`, avec la raison dans `errors[:base]` quand l'interface doit l'afficher.
- **Aucune lecture en base** : les faits sont chargés par le use case avant l'appel (`classroom.teacher_ids`, `exercise.parents_published`…).
- Un visiteur est `actor: nil`. Toutes les policies le refusent, sauf `JoinPolicy`, `RegisterTeacherPolicy`, `SessionPolicy` et `SecondFactorPolicy`, dont le fait est la session elle-même.
- Ordre dans un use case : DTO (`:invalid`), faits (`:not_found`), policy (`:forbidden`), écriture.
- **Seuls** `Identity::Authenticate`, `Identity::ResetPinWithCode` et `Identity::AcceptInvitation` sont exemptés de policy (ADR-0028). Les mécanismes de session et les importeurs **ne le sont pas**.

| Fichier | Règle | Test |
|---|---|---|
| `app/domain/policies/identity/session_policy.rb` | Faits : `session:` (`SessionState`, trouvée par l'empreinte du jeton). Autorise le porteur du jeton sur **sa** session : `ResolveSession`, `SignOut`. Refus si la session est absente. | `test/domain/policies/identity/session_policy_test.rb` |
| `app/domain/policies/identity/second_factor_policy.rb` | Faits : `session:`, `step:` (`:enroll` ou `:verify`). Compte `team` seulement. `:enroll` : second facteur non confirmé ; `:verify` : confirmé et session pas encore vérifiée. | `test/domain/policies/identity/second_factor_policy_test.rb` |
| `app/domain/policies/identity/register_teacher_policy.rb` | `actor` nul : seul un visiteur s'inscrit. | `test/domain/policies/identity/register_teacher_policy_test.rb` |
| `app/domain/policies/identity/invite_team_policy.rb` | `actor.role == :team && actor.team_role == "admin"` (ADR-0038) | `test/domain/policies/identity/invite_team_policy_test.rb` |
| `app/domain/policies/identity/issue_pin_recovery_code_policy.rb` | Faits : `target:` (User), `teaches_target:` (Boolean). **Teacher** : la cible est un élève et `teaches_target`. **Team** : cible student, teacher, school_admin ou team, jamais lui-même. Sinon refus (ADR-0032). | `test/domain/policies/identity/issue_pin_recovery_code_policy_test.rb` |
| `app/domain/policies/identity/reset_second_factor_policy.rb` | Team, cible team, jamais lui-même (ADR-0031). | `test/domain/policies/identity/reset_second_factor_policy_test.rb` |
| `app/domain/policies/identity/read_user_policy.rb` | Soi-même ; l'enseignant pour les élèves de ses classes (fait `teaches_target`) ; team (ADR-0028). | `test/domain/policies/identity/read_user_policy_test.rb` |
| `app/domain/policies/identity/delete_user_policy.rb` | Team (ADR-0028). Aucun appelant en V1. | `test/domain/policies/identity/delete_user_policy_test.rb` |
| `app/domain/policies/identity/update_self_policy.rb` | Soi-même (ADR-0028). Aucun appelant en V1. | `test/domain/policies/identity/update_self_policy_test.rb` |
| `app/domain/policies/school/manage_school_policy.rb` | Team. DRENA, établissements, génération des classes, imports d'établissements (ADR-0028, ADR-0030, ADR-0039). | `test/domain/policies/school/manage_school_policy_test.rb` : teacher, student et school_admin refusés |
| `app/domain/policies/classroom/join_policy.rb` | Tel que dans l'ADR-0028 : `actor` nul ou student. Faits : `classroom:`, `code:`. Classe active, sinon `classroom_archived` ; `code == classroom.join_code`, sinon `join_code_revoked` ; `active_students_count < max_students`, sinon `classroom_full`. | `test/domain/policies/classroom/join_policy_test.rb` : visiteur, élève, enseignant refusé, trois raisons |
| `app/domain/policies/classroom/declare_teaching_policy.rb` | Teacher ; `classroom.school_id == actor.school_id` ; classe active (ADR-0030). | `test/domain/policies/classroom/declare_teaching_policy_test.rb` |
| `app/domain/policies/classroom/teach_policy.rb` | Teacher dont l'`user_id` figure dans `classroom.teacher_ids`, ou team. | `test/domain/policies/classroom/teach_policy_test.rb` |
| `app/domain/policies/classroom/assign_policy.rb` | Comme `TeachPolicy`, et classe active (ADR-0048). | `test/domain/policies/classroom/assign_policy_test.rb` |
| `app/domain/policies/classroom/manage_classroom_policy.rb` | Team (ADR-0030). | `test/domain/policies/classroom/manage_classroom_policy_test.rb` |
| `app/domain/policies/classroom/read_classroom_policy.rb` | Team ; teacher dans `teacher_ids` ; student dont la classe principale active est celle-ci. Le fait `show_roster` est vrai pour team et teacher seulement. | `test/domain/policies/classroom/read_classroom_policy_test.rb` |
| `app/domain/policies/catalog/read_published_policy.rb` | Team : tout. Autre rôle connecté : contenu publié **et** parents publiés. Un refus devient `:not_found` (ADR-0035). | `test/domain/policies/catalog/read_published_policy_test.rb` |
| `app/domain/policies/catalog/manage_content_policy.rb` | Team. Cours, fiches, exercices, publication, archivage, imports de contenu. | `test/domain/policies/catalog/manage_content_policy_test.rb` |
| `app/domain/policies/catalog/manage_taxonomy_policy.rb` | Team (ADR-0034). | `test/domain/policies/catalog/manage_taxonomy_policy_test.rb` |
| `app/domain/policies/assessment/start_session_policy.rb` | Student ; exercice publié et parents publiés. **Aucune exigence d'assignation** (ADR-0028). | `test/domain/policies/assessment/start_session_policy_test.rb` |
| `app/domain/policies/assessment/submit_attempt_policy.rb` | Student propriétaire de la session ; session `started` (ADR-0054). | `test/domain/policies/assessment/submit_attempt_policy_test.rb` |
| `app/domain/policies/assessment/read_session_policy.rb` | Élève propriétaire ; teacher dont une classe **active** contient l'élève (fait `teaches_student`) ; team. | `test/domain/policies/assessment/read_session_policy_test.rb` |
| `app/domain/policies/assessment/reveal_answers_policy.rb` | **Student** : seulement pour une question déjà tentée dans la session (fait `attempted_question_ids`). **Team** : tout. **L'enseignant ne voit pas les bonnes réponses** (ADR-0028). | `test/domain/policies/assessment/reveal_answers_policy_test.rb` |

### 0b.5 DTO du socle

`Dtos::<Ctx>::<Nom>Input` dans `app/domain/dtos/<ctx>/` (ADR-0026). Ils incluent `ActiveModel::Model`, `Attributes` et `Validations`, et valident la **forme** seulement. Les DTO propres à un écran appartiennent à son lot ; celui du téléversement d'import appartient à 0e.

| Fichier | Attributs · validations | Test |
|---|---|---|
| `app/domain/dtos/identity/person_name_input.rb` | Tel que dans l'ADR-0037 : `last_name` (50), `first_name` (80), `squish`, `NAME_FORMAT`. Inclus par les DTO d'inscription des lots. | `test/domain/dtos/identity/person_name_input_test.rb` |
| `app/domain/dtos/identity/credentials_input.rb` | `contact, pin, ip, user_agent`. Présence ; `contact` normalisé par `Entities::Identity::Contact` à l'affectation. | `test/domain/dtos/identity/credentials_input_test.rb` |
| `app/domain/dtos/identity/second_factor_code_input.rb` | `code` : 6 chiffres (TOTP) ou 10 caractères base58 (code de secours). | `test/domain/dtos/identity/second_factor_code_input_test.rb` |
| `app/domain/dtos/identity/pin_reset_input.rb` | `contact, code, pin, pin_confirmation, ip`. `code` : 8 chiffres ; `pin` au format ; confirmation égale. | `test/domain/dtos/identity/pin_reset_input_test.rb` |

---

## Lot 0d — Authentification et shell branché

- **Couche**       : infrastructure (transaction, repositories `identity`, queries) + domaine (use cases d'authentification) + delivery + ui
- **Fichiers**     : les chemins des tableaux 0d.1 à 0d.4, exhaustifs.
- **Dépend de**    : part dès que 0a est mergé, en codant contre les signatures de ports gelées en 0b.3 ; mergé après 0a **et** 0b. Parallèle de 0e.
- **Test associé** : colonne « Test » des tableaux, et le test système de connexion (0d.4).
- **Done quand**   :
  - un élève, un enseignant et un membre de l'équipe créés par les fabriques se connectent ; le membre de l'équipe passe son TOTP ; chacun est redirigé vers sa destination (`HomeDestination`), qui peut encore répondre 404 tant que son lot n'est pas mergé ;
  - un compte team sans second facteur vérifié n'atteint aucune page de l'équipe, ni `/teams/jobs` ;
  - le test système de connexion passe **sans rechargement de page** sur l'échec (422 dans le formulaire) ;
  - `bin/ci` est vert.
- **UDR**          : UDR-0008 couvre la connexion, le second facteur, la réinitialisation du PIN, les écrans de sortie et le suivi des imports (0e).

### 0d.1 Transaction et repositories `identity`

| Fichier | Contenu | Test |
|---|---|---|
| `app/infrastructure/repositories/shared/transaction.rb` | `Repositories::Shared::Transaction` inclut `TransactionPort` : `call` = `ActiveRecord::Base.transaction { yield }` ; `attempt` renvoie `failure(:conflict, errors: { base: [:write_failed] })` sur `ActiveRecord::RecordNotUnique`, `RecordInvalid`, `InvalidForeignKey`, `NotNullViolation`, `CheckViolation` ou `LockWaitTimeout`, après rollback. | `test/infrastructure/repositories/shared/transaction_test.rb` : rollback sur exception ; `attempt` traduit une violation d'index |
| `app/infrastructure/repositories/identity/user_repository.rb` | port de 0b.3 | `test/infrastructure/repositories/identity/user_repository_test.rb` |
| `app/infrastructure/repositories/identity/registration_repository.rb` | idem | `test/infrastructure/repositories/identity/registration_repository_test.rb` |
| `app/infrastructure/repositories/identity/teacher_profile_repository.rb` | idem | `test/infrastructure/repositories/identity/teacher_profile_repository_test.rb` |
| `app/infrastructure/repositories/identity/session_repository.rb` | idem | `test/infrastructure/repositories/identity/session_repository_test.rb` |
| `app/infrastructure/repositories/identity/login_attempt_repository.rb` | idem | `test/infrastructure/repositories/identity/login_attempt_repository_test.rb` |
| `app/infrastructure/repositories/identity/audit_log_repository.rb` | idem | `test/infrastructure/repositories/identity/audit_log_repository_test.rb` |
| `app/infrastructure/repositories/identity/second_factor_repository.rb` | idem, `ROTP::TOTP` | `test/infrastructure/repositories/identity/second_factor_repository_test.rb` |
| `app/infrastructure/repositories/identity/pin_recovery_repository.rb` | idem | `test/infrastructure/repositories/identity/pin_recovery_repository_test.rb` |
| `app/infrastructure/repositories/identity/invitation_repository.rb` | idem | `test/infrastructure/repositories/identity/invitation_repository_test.rb` |

### 0d.2 Use cases et queries d'authentification

Une seule méthode publique `call(...) → Shared::Result`. Ports, policies et horloge sont injectés au constructeur : le domaine n'instancie **jamais** un repository, c'est le contrôleur ou le job qui câble.

| Fichier | Comportement | Test |
|---|---|---|
| `app/domain/use_cases/identity/authenticate.rb` | Exempté de policy (ADR-0028). (1) DTO invalide : `:invalid`. (2) `Lockout.retry_after(consecutive_failures)` non nul : `:locked`, avec `retry_after`, et le PIN n'est **pas** vérifié. (3) `users.authenticate` ; échec : `login_attempts.record(succeeded: false)`, audit `login.locked` si un palier vient d'être franchi, puis `:invalid` avec un message unique. (4) Succès : `record(succeeded: true)`, jeton de 32 octets, `sessions.create` avec son digest, puis `success({ user:, token: })`. | `test/domain/use_cases/identity/authenticate_test.rb` : paliers 5, 10 et 20 ; numéro inconnu ; message identique |
| `app/domain/use_cases/identity/resolve_session.rb` | `call(token:)`. Session par l'empreinte ; `SessionPolicy` ; `SessionLifetime.expired?` : la ligne est détruite, `:expired`. Sinon `touch` au-delà de `TOUCH_EVERY`, puis `success(Data(actor, session))` ; `actor` est `nil` pour un compte team dont la session n'est pas vérifiée. | `test/domain/use_cases/identity/resolve_session_test.rb` |
| `app/domain/use_cases/identity/sign_out.rb` | `call(token:)`. `SessionPolicy`, puis destruction. Idempotent. | `test/domain/use_cases/identity/sign_out_test.rb` |
| `app/domain/use_cases/identity/begin_second_factor_enrollment.rb` | `call(session:)`. `SecondFactorPolicy(step: :enroll)`. Renvoie secret et `provisioning_uri`. | `test/domain/use_cases/identity/begin_second_factor_enrollment_test.rb` |
| `app/domain/use_cases/identity/confirm_second_factor_enrollment.rb` | `call(session:, dto:)`. `SecondFactorPolicy(step: :enroll)`, `verify_code` ; échec : `:invalid`. Succès : `BackupCodes.generate`, `confirm` avec leurs HMAC, `mark_second_factor_verified`, audit `totp.enrolled`, puis les 10 codes en clair **une seule fois**. | `test/domain/use_cases/identity/confirm_second_factor_enrollment_test.rb` |
| `app/domain/use_cases/identity/verify_second_factor.rb` | `call(session:, dto:, ip:)`. `SecondFactorPolicy(step: :verify)`. Code TOTP par `verify_code` (rejeu refusé), ou code de secours par `consume_backup_code` avec audit `backup_code.used`. Échec : `login_attempts.record(kind: "second_factor")`, `:invalid` ou `:locked`. Succès : `mark_second_factor_verified`. | `test/domain/use_cases/identity/verify_second_factor_test.rb` |
| `app/domain/use_cases/identity/reset_pin_with_code.rb` | Exempté de policy (ADR-0028, anonyme). Utilisateur introuvable, code absent, révoqué ou faux : `:invalid` avec **un message identique** ; faux : `record_failure`. Expiré : `:expired`. Juste : `update_pin`, `consume`, `destroy_all_for`, `clear_failures`, audit `pin.reset`. Le tout dans une transaction. | `test/domain/use_cases/identity/reset_pin_with_code_test.rb` : 5 échecs révoquent le code |
| `app/infrastructure/queries/identity/home_destination_query.rb` | `Queries::Identity::HomeDestinationQuery#call(actor:)` → symbole. Lit la classe principale active, l'école principale et l'onboarding, puis délègue à `Entities::Identity::HomeDestination.for`. Lecture seule : ce n'est pas un use case. | `test/infrastructure/queries/identity/home_destination_query_test.rb` |
| `app/infrastructure/queries/identity/shell_user_query.rb` | `#call(user_id:)` → `NavigationHelper::ShellUser`-compatible : `Row(name, role, detail)`, lu une fois par requête. | `test/infrastructure/queries/identity/shell_user_query_test.rb` |

### 0d.3 Delivery et écrans

| Fichier | Contenu | Test |
|---|---|---|
| `app/controllers/application_controller.rb` (modifié) | `include Authentication`, `include RendersResult`. Le `allow_browser` de V0 est conservé (ADR-0051). | — |
| `app/controllers/concerns/authentication.rb` | **Cookie** `cookies.signed[:session_token]` : `httponly`, `same_site: :lax`, `secure` hors local (ADR-0050). **`start_session(user, token)`** : `reset_session`, puis dépose le cookie. **`require_authentication`** (par défaut) : `ResolveSession` ; absente ou expirée → `new_session_path`. **Compte team sans second facteur vérifié** : aucun `current_actor` ; redirection vers `new_identity_second_factor_path`, ou vers l'enrôlement si le compte n'est pas confirmé, partout sauf ces deux écrans et `session#destroy`. **Macros** `allow_unauthenticated_access(only:)` et `allow_roles(*roles)` (un rôle hors liste reçoit 403). `current_actor` en `helper_method`. **`redirect_to_home`** : `HomeDestinationQuery`, puis symbole → route. | `test/controllers/concerns/authentication_test.rb` : expiration absolue et d'inactivité, cookie falsifié, team non vérifiée bloquée partout, 403 hors rôle |
| `app/controllers/concerns/renders_result.rb` | Tel que dans l'ADR-0026 : `render_result(result, success:, form: nil)`. `:forbidden` → 403 (`errors/forbidden` en HTML, `{ error: }` en JSON, toast en Turbo Stream) ; `:not_found` → 404 ; `:invalid` et `:conflict` → `form` rendu en **422** (dans le frame qui l'a demandé) ; `:locked` → 429 ; `:expired` → connexion. | `test/controllers/concerns/renders_result_test.rb` |
| `app/controllers/authenticated_controller.rb` | `layout "shell"`, `helper_method :shell_user` (`NavigationHelper::ShellUser` construit depuis `ShellUserQuery`). Les contrôleurs connectés hors équipe en héritent. | couvert par les tests des lots |
| `app/controllers/teams/base_controller.rb` (modifié) | `Teams::BaseController < AuthenticatedController`, `allow_roles :team` ; la garde `deny_access` de V0 disparaît. Reste le `base_controller_class` de Mission Control (déjà configuré en V0). | `test/controllers/teams/base_controller_test.rb` (modifié) : enseignant 403 ; team non vérifiée redirigée ; `/teams/jobs` refusé sans second facteur |
| `app/controllers/homepage_controller.rb` (modifié) | `allow_unauthenticated_access`. Un visiteur connecté est envoyé vers `redirect_to_home` (TR-02). Le contenu de la landing appartient à A4. | `test/controllers/homepage_redirection_test.rb` |
| `app/controllers/design_controller.rb` (modifié) | `allow_unauthenticated_access` : le guide de style (hors production) reste ouvert. | `test/controllers/design_controller_test.rb` (V0) reste vert |
| `app/controllers/identity/sessions_controller.rb` | `rate_limit to: 5, within: 1.minute, only: :create, by: -> { request.remote_ip }` (ADR-0050). `create` : `Authenticate`, `start_session`, toast « Connexion réussie », `redirect_to_home`. Échec : formulaire re-rendu en 422, message unique, PIN vidé ; `:locked` : message avec l'heure de déblocage. `destroy` : `SignOut`, cookie supprimé, `/` avec « Vous êtes déconnecté ». | `test/controllers/identity/sessions_controller_test.rb` : rotation de l'identifiant de session, 429, préfixes `00225` et `225` |
| `app/controllers/identity/second_factors_controller.rb` | `new`, `create` ; `rate_limit to: 5, within: 1.minute`. Succès : `team_home_path`. | `test/controllers/identity/second_factors_controller_test.rb` : code rejoué refusé, code de secours accepté une fois |
| `app/controllers/identity/second_factor_enrollments_controller.rb` | `new` : QR en SVG (`RQRCode`) et secret en texte. `create` : rendu direct de `backup_codes`, **sans redirection** : les codes ne passent ni par le flash ni par la session. | `test/controllers/identity/second_factor_enrollments_controller_test.rb` |
| `app/controllers/identity/pin_resets_controller.rb` | `allow_unauthenticated_access`, `rate_limit to: 5, within: 1.minute`. `create` : `ResetPinWithCode` ; succès → connexion avec « Votre nouveau PIN est enregistré. Connectez-vous. » | `test/controllers/identity/pin_resets_controller_test.rb` |
| `app/controllers/identity/pending_accounts_controller.rb` | Écran de sortie : élève sans classe active (lien « Rejoindre une classe » vers `new_join_code_path`), enseignant sans école. **Ne redirige jamais**. | `test/controllers/identity/pending_accounts_controller_test.rb` : aucune boucle (ID-13) |
| `app/views/identity/sessions/new.html.erb` | Deux colonnes, reprises de `⟨ancienne⟩ views/identity/sessions/new.html.erb`. Contact en `telephone_field` (`maxlength` 15, placeholder « 07 00 00 00 00 »), PIN en `password_field` `inputmode="numeric"`. Lien « PIN oublié ? ». Titre « Connexion ». | (tests contrôleur) |
| `app/views/identity/second_factors/new.html.erb` | Champ code, aide « ou un code de secours » | — |
| `app/views/identity/second_factor_enrollments/new.html.erb` | QR, secret, champ code | — |
| `app/views/identity/second_factor_enrollments/backup_codes.html.erb` | 10 codes, « affichés une seule fois », bouton « J'ai noté mes codes » | — |
| `app/views/identity/pin_resets/new.html.erb` | Numéro, code à 8 chiffres, nouveau PIN, confirmation | — |
| `app/views/identity/pending_accounts/show.html.erb` | `ui_empty_state` selon le cas, bouton « Se déconnecter » | — |
| `app/views/errors/forbidden.html.erb` · `app/views/errors/not_found.html.erb` | « Accès interdit. » · « Page introuvable. », lien vers l'accueil | — |
| `config/locales/shared/common.fr.yml` | Clés **communes** : `errors.codes.*`, `activemodel.attributes.dtos/*` (Nom, Prénom(s), Genre, Numéro de contact, PIN…), `content_status.*`, `badges.{bronze,silver,gold,diamond,none}`, `mastery.{acquired,fragile,struggling}`, `materials.categories.*`, `genders.*`, `school_types.{public,private,mixed}` (Public, Privé, Mixte), `school_statuses.*`, `import_kinds.*`. | `test/i18n/locale_files_test.rb` : tout fichier sous `fr:`, aucune clé en double, aucun terme interdit par l'UDR-0007 (« Habileté », « Notion clé », « Leçon », « Quiz », « Essai », « Platine », « Médaille », « Trophée ») |
| `config/locales/identity/sessions.fr.yml` · `config/locales/identity/second_factors.fr.yml` · `config/locales/identity/pin_resets.fr.yml` · `config/locales/identity/pending_accounts.fr.yml` · `config/locales/errors/pages.fr.yml` | Textes des écrans ci-dessus | — |
| `config/initializers/filter_parameter_logging.rb` (modifié) | Ajouter `:pin, :pin_confirmation, :new_pin, :code, :otp, :backup_code, :token, :join_code`. | `test/integration/parameter_filtering_test.rb` (modifié) |

### 0d.4 Support de test système

| Fichier | Contenu |
|---|---|
| `test/application_system_test_case.rb` (modifié) | Ajoute `with_mobile_viewport` (`[390, 844]`). Le pilote Chrome headless de V0 ne change pas. |
| `test/support/authentication_helper.rb` | `sign_in_as(user, pin: "2468")` pour les tests d'intégration ; pour un compte team, saisit le TOTP courant depuis le secret de la fabrique. `sign_out`. |
| `test/support/system_authentication_helper.rb` | Même chose par les formulaires réels, inclus dans `ApplicationSystemTestCase`. |
| `test/support/turbo_assertions.rb` | Inclus dans `ApplicationSystemTestCase`. **`assert_no_page_reload { … }`** : pose un marqueur sur `window`, exécute le bloc, attend que Turbo soit au repos, puis vérifie que le marqueur a survécu : aucun rechargement de fenêtre. **`open_in_modal(path)`** : `Turbo.visit(path, { frame: "modal" })`, puis attend la modale ouverte. Sert aux lots dont le bouton d'ouverture vit dans l'écran d'un autre lot. **`assert_toast(text)`**. |
| `test/support/caching_helper.rb` | `with_fragment_caching { … }` |

| Test | Ce qu'il vérifie |
|---|---|
| `test/system/identity/sign_in_test.rb` | PIN faux : message dans le formulaire, sans rechargement ; bon PIN : arrivée sur la destination du rôle ; membre de l'équipe : second facteur, puis `/teams` ; même parcours en 390 px. |

---

## Lot 0e — Repositories, moteur d'import, front partagé

- **Couche**       : infrastructure (repositories, queries) + domaine (moteur d'import) + delivery (écran des imports, job de base) + ui (front partagé) + seeds + gardes d'architecture
- **Fichiers**     : les chemins des tableaux e1 à e4, exhaustifs.
- **Dépend de**    : part dès que 0a est mergé, en codant contre les signatures de ports gelées en 0b.2 et 0b.3 ; e1 à e3 sont mergées après 0a **et** 0b. **L'étape e4 attend le merge de 0d** (contrôleur d'équipe, authentification, `UserRepository`, `AuditLogRepository`, `Transaction`). Les étapes e1 à e3 avancent en parallèle de 0d.
- **Test associé** : colonne « Test » des tableaux, test système du parcours d'import (fin de e4), gardes d'architecture.
- **Done quand**   :
  - chaque repository passe son test de contrat, `AssignmentRepository` à 100 % lignes et branches pour les trois types de ressource ;
  - avec l'importeur factice, un fichier **mixte** (valides, invalides, doublons) donne un rapport **exact** : importés, ignorés, en erreur avec leur chemin JSON, `total_count` = somme des trois ; un lot en échec en base est rejoué élément par élément ; un fichier dont l'enveloppe est invalide finit `rejected` sans aucune écriture ; un second import du même type en cours donne `:conflict` ;
  - le suivi d'un import se met à jour **sans rechargement de page** ;
  - `bin/rails db:prepare db:seed` passe deux fois de suite en développement ; en production simulée, seul l'amorçage est créé ;
  - `bin/ci` est vert.

### e1 — Les 18 autres repositories

Même règle que 0d.1 : chaque repository implémente le port de 0b.3 et a son test de contrat sur PostgreSQL. `RichTextSanitizer` n'est pas un port : c'est un outil d'infrastructure partagé par trois repositories du catalogue.

| Repository | Test |
|---|---|
| `app/infrastructure/repositories/school/drena_repository.rb` | `test/infrastructure/repositories/school/drena_repository_test.rb` |
| `app/infrastructure/repositories/school/school_repository.rb` | `test/infrastructure/repositories/school/school_repository_test.rb` : seconde école principale → `:conflict` (ADR-0030) |
| `app/infrastructure/repositories/classroom/classroom_repository.rb` | `test/infrastructure/repositories/classroom/classroom_repository_test.rb` : `insert_generated` de 1 000 lignes ; code pris → `RecordNotUnique` levé (le rejeu est l'affaire du moteur) |
| `app/infrastructure/repositories/classroom/membership_repository.rb` | `test/infrastructure/repositories/classroom/membership_repository_test.rb` |
| `app/infrastructure/repositories/classroom/teaching_repository.rb` | `test/infrastructure/repositories/classroom/teaching_repository_test.rb` |
| `app/infrastructure/repositories/classroom/assignment_repository.rb` | `test/infrastructure/repositories/classroom/assignment_repository_test.rb` — **100 % lignes et branches, trois types de ressource** |
| `app/infrastructure/repositories/catalog/taxonomy_repository.rb` | `test/infrastructure/repositories/catalog/taxonomy_repository_test.rb` |
| `app/infrastructure/repositories/catalog/course_repository.rb` | `test/infrastructure/repositories/catalog/course_repository_test.rb` : le contenu est lu et écrit en HTML brut dans le rich text (`record.content.body.to_html`, `record.content = html`), assaini à l'écriture ; l'entité ne connaît pas Action Text |
| `app/infrastructure/repositories/catalog/essential_repository.rb` | `test/infrastructure/repositories/catalog/essential_repository_test.rb` : même traitement du contenu que `CourseRepository` |
| `app/infrastructure/repositories/catalog/content_tree_writer.rb` | `test/infrastructure/repositories/catalog/content_tree_writer_test.rb` : un arbre de 2 cours complet, parents d'abord, tout en `draft` ; le `content` des cours et des fiches est **assaini** puis écrit en masse (`insert_all`) dans `action_text_rich_texts` (`record_type` `Orm::Course` ou `Orm::Essential`, `name` `content`) ; un `<script>` du fichier n'arrive pas en base |
| `app/infrastructure/repositories/catalog/rich_text_sanitizer.rb` | `test/infrastructure/repositories/catalog/rich_text_sanitizer_test.rb` : `Repositories::Catalog::RichTextSanitizer.call(html)` applique la liste blanche d'Action Text (balises et attributs que Trix produit et que le rendu garde). Retirés : `<script>`, `<style>`, `<iframe>`, attributs `on*`, liens `javascript:`. Gardés : gras, italique, titres, listes, citations, `pre`, liens `https:`, et le texte des formules `$…$`. Utilisé par les deux repositories ci-dessus et par `ContentTreeWriter` : tout HTML écrit dans un rich text passe par lui, importé ou saisi. |
| `app/infrastructure/repositories/catalog/import_report_repository.rb` | `test/infrastructure/repositories/catalog/import_report_repository_test.rb` : second rapport en cours du même type → `:conflict` ; `fail_stale` ; `finish` tronque à 1 000 erreurs |
| `app/infrastructure/repositories/catalog/import_file_store.rb` | `test/infrastructure/repositories/catalog/import_file_store_test.rb` : aucun fichier écrit sous `tmp/` |
| `app/infrastructure/repositories/catalog/import_schema_validator.rb` | `test/infrastructure/repositories/catalog/import_schema_validator_test.rb` : `json_schemer`, erreurs converties en `ImportError` avec leur chemin JSON (`/schools/12/type` → `schools[12].type`) ; racine injectable (`root:`), `config/schemas` par défaut |
| `app/infrastructure/repositories/catalog/import_queue.rb` | `test/infrastructure/repositories/catalog/import_queue_test.rb` : lit `Rails.configuration.x.import_jobs[kind]`, fait `constantize` **à l'appel**, puis `perform_later(report_id)` |
| `app/infrastructure/repositories/assessment/exercise_repository.rb` | `test/infrastructure/repositories/assessment/exercise_repository_test.rb` |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` |
| `app/infrastructure/repositories/assessment/badge_repository.rb` | `test/infrastructure/repositories/assessment/badge_repository_test.rb` |
| `app/infrastructure/repositories/assessment/knowledge_gap_repository.rb` | `test/infrastructure/repositories/assessment/knowledge_gap_repository_test.rb` |

### e2 — Moteur d'import partiel (ADR-0039)

**La chaîne.** Téléversement (modale de l'écran des imports) → `StartImport` (rapport `queued`, fichier stocké, job en file) → job du type (`Shared::ImportJob`) → `RunImport` → écran de suivi, qui recharge son frame toutes les **3 s** tant que l'import tourne.

**`StartImport`** : DTO (fichier JSON présent, **20 Mo au plus** : sinon `:invalid` avec `too_large`, rien n'est créé) ; `ImportKind#policy` ; `reports.fail_stale(kind:, before: now - 30.min)` (un job tué passe `failed`) ; `reports.create` (un import du même type en cours : `:conflict`, « Un import de ce type est déjà en cours ») ; `files.attach` ; `queue.enqueue`. Renvoie le rapport.

**`RunImport`**, pour un `report_id` et un adaptateur :
1. `claim` : `queued` → `validating`. Un second job sur le même rapport ne fait rien. La policy du type est **réappliquée** à `users.actor_for(imported_by_id)` : un rôle retiré entre-temps fait échouer l'import.
2. **Rejet en bloc** (`rejected`, zéro écriture, erreurs au chemin `$` ou au chemin de l'enveloppe) : JSON illisible (`json_invalid`) ; `format` différent de celui du type (`format_mismatch`) ; `version` différente de 1 (`version_unsupported`) ; erreur de schéma **hors** des éléments racines ; cible introuvable (`adapter.resolve_target` en échec : `unknown_target`) ; plus de `max_roots` éléments racines (`too_many_roots`).
3. `adapter.prepare(target:)` → `ImportContext` : référentiels et clés existantes chargés **une fois**.
4. **Validation complète**, élément racine par élément racine : erreurs de schéma de cet élément, puis `adapter.validate_root(root:, path:, context:)` → `ImportItem`. Un élément invalide garde **toutes** ses erreurs. Un élément valide dont la clé est dans `context.existing_keys` ou déjà vue plus haut dans le fichier est **ignoré** et compté. `advance(processed_count:)` toutes les 100 racines.
5. `advance(status: "importing")`. **Écriture** des seuls éléments valides, par lots de `BATCH_SIZE` (100) : `transaction.attempt { adapter.write(items:, author_id:, at:) }`. Lot en échec : **rejeu élément par élément**, chacun dans son `attempt` ; un élément qui échoue encore reçoit `write_failed` à son chemin. Aucun élément n'est jamais écrit à moitié : l'atomicité est celle de l'élément racine (une école et ses classes, un cours et toute sa descendance, une fiche et ses exercices, un exercice, ses questions et ses propositions).
6. `finish(status: "completed")` avec `imported_count`, `skipped_count`, `error_count`, `total_count` (leur somme), `details` (fusion de ceux des lots) et les 1 000 premières erreurs. Audit `import.run` (type, rapport, compteurs).
7. Une exception imprévue : `finish(status: "failed")`, puis elle remonte au job (Mission Control la montre). Relancer le fichier compte en doublons ce qui était déjà écrit.

**Contrat d'un adaptateur.** Module `UseCases::Catalog::Importer`, que chaque adaptateur inclut. L'adaptateur **référence sa policy** (`Policies::School::ManageSchoolPolicy` ou `Policies::Catalog::ManageContentPolicy`) : il n'est pas exempté.

```ruby
KIND                                                  # "schools" | "course_tree" | "essentials" | "exercises"
resolve_target(document:)            → Result(target | nil) | failure(:not_found)
prepare(target:)                     → Entities::Catalog::ImportContext
validate_root(root:, path:, context:) → Entities::Catalog::ImportItem   # n'écrit rien
write(items:, author_id:, at:)       → { imported: Integer, details: Hash }   # appelé dans une transaction ; lève si la base refuse
```

**Câblage.** `Shared::ImportJob` (e4) construit `RunImport` avec les repositories réels et l'adaptateur que rend sa sous-classe. Chaque lot d'import livre sa sous-classe (`School::ImportSchoolsJob`, `Catalog::ImportCourseTreeJob`, `Catalog::ImportEssentialsJob`, `Assessment::ImportExercisesJob`). `ImportQueue` résout le nom du job **à l'appel**, depuis `config.x.import_jobs` : une constante d'un lot pas encore mergé ne casse ni le chargement ni l'`eager_load`.

| Fichier | Contenu | Test |
|---|---|---|
| `app/domain/use_cases/catalog/importer.rb` | Module de contrat ; chaque méthode lève `NotImplementedError`. | couvert par `importer_contract` |
| `app/domain/dtos/catalog/import_upload_input.rb` | `kind, filename, io`. `kind` ∈ `ImportKind`. `byte_size` et `checksum_sha256` calculés depuis `io` (`Digest::SHA256`). | `test/domain/dtos/catalog/import_upload_input_test.rb` |
| `app/domain/use_cases/catalog/start_import.rb` | ci-dessus | `test/domain/use_cases/catalog/start_import_test.rb` : non-team refusé ; 20 Mo + 1 octet ; `:conflict` ; rapport bloqué depuis 31 min passé `failed` |
| `app/domain/use_cases/catalog/run_import.rb` | étapes 1 à 7 | `test/domain/use_cases/catalog/run_import_test.rb`, avec l'adaptateur factice et des ports en mémoire : chaque motif de rejet en bloc (zéro écriture) ; **fichier mixte → rapport exact** (7 valides, 2 invalides avec leur chemin et leur motif, 1 doublon en base, 1 doublon dans le fichier : 7 + 2 + 2 = 11) ; lot en échec rejoué, un seul élément en `write_failed` ; 1 001 erreurs → 1 000 gardées, `error_count` = 1 001 ; rôle retiré → `failed` |
| `config/initializers/imports.rb` | `config.x.import_jobs = { "schools" => "School::ImportSchoolsJob", "course_tree" => "Catalog::ImportCourseTreeJob", "essentials" => "Catalog::ImportEssentialsJob", "exercises" => "Assessment::ImportExercisesJob" }` | couvert par `import_queue_test` |
| `app/infrastructure/queries/catalog/import_reports_query.rb` | `Queries::Catalog::ImportReportsQuery#call(kind: nil, limit: 50)` → `[Row(public_id, kind, filename, status, total_count, imported_count, skipped_count, error_count, imported_by_name, created_at, finished_at)]` | `test/infrastructure/queries/catalog/import_reports_query_test.rb` |
| `app/infrastructure/queries/catalog/import_report_query.rb` | `#call(public_id:)` → `Row(…, processed_count, details, import_errors)` ou `nil` | `test/infrastructure/queries/catalog/import_report_query_test.rb` |
| `test/support/fake_transaction.rb` | `FakeTransaction` : `call` et `attempt` en mémoire, avec échec programmable par élément. | — |
| `test/support/fake_importer.rb` | Adaptateur factice : `KIND = "schools"`, éléments `{ name: }`, clé = `NaturalKey`, écriture dans un tableau en mémoire, échec programmable par nom. Et `FakeImportJob < Shared::ImportJob`, qui l'utilise avec un schéma de test. | — |
| `test/support/importer_contract.rb` | `assert_importer_contract(adapter_class)` : inclut `UseCases::Catalog::Importer`, définit `KIND` et les quatre méthodes avec les paramètres gelés, référence une constante `Policies::`, et `validate_root` n'écrit rien en base (compte des tables avant et après). | — |
| `test/support/import_documents.rb` | Générateurs pour les lots d'import : `schools_document(count:, drena:, college_ratio: 0.44, types: %w[public private mixed])`, `course_tree_document(courses:, essentials: 8, exercises: 2, questions: 10, answers: 4)`, `essentials_document(…)`, `exercises_document(…)`, et `mixed(document, invalid_at: [3, 7], duplicate_of: { 5 => 1 })`. Lit aussi les exemples réels de `test/fixtures/files/imports/`. | — |
| `test/fixtures/files/imports/schools_legacy_sample.json` · `test/fixtures/files/imports/course_tree_tle_d_sample.json` | Extraits **enveloppés** de `.Business/content_pedagogics/DRENAS/` (10 écoles, public, privée, mixte, un collège) et de `tle_d/` (2 cours complets) : exemples d'import et données de test (ADR-0039 §6). | — |
| `test/fixtures/files/import_schemas/fake.v1.json` | Schéma du `FakeImportJob`. | — |

### e3 — Front partagé, queries et helpers communs

| Fichier | Contenu | Lots | Test |
|---|---|---|---|
| `app/javascript/controllers/index.js` (modifié) | Remplace le manifeste généré : `import controllers from "./**/*_controller.js"`, puis `controllers.forEach(c => application.register(c.name, c.module.default))`. Un fichier en sous-dossier a pour identifiant `<dossier>--<nom>`. Les quatre contrôleurs du Lot 0c gardent leur identifiant. | tous | `test/system/design_system_test.rb` (V0) reste vert |
| `app/javascript/controllers/math_controller.js` | À la connexion : `await import("katex/contrib/auto-render")` (**import dynamique**, ADR-0051), ajoute une fois au `<head>` le `<link>` de `katex.css` (même origine, compatible CSP), puis rend `$…$` et `$$…$$`. Sert à B1, B3, C1, C2 et C3. | B1, B3, C1 à C3 | `test/system/shared/math_rendering_test.rb` : une formule est rendue ; le point d'entrée commun ne contient pas KaTeX |
| `app/javascript/controllers/rich_text_editor_controller.js` | Identifiant `rich-text-editor`, posé sur le champ de contenu des formulaires de B2 et B4. À la connexion : `await Promise.all([import("trix"), import("@rails/actiontext")])` (**import dynamique**, amendement du 2026-09-25 de l'ADR-0051), puis ajoute une fois au `<head>` le `<link>` de `trix.css` (même origine, compatible CSP). Trix lit le nonce de la balise `csp-nonce` posée par `csp_meta_tag` (ADR-0049). **Pièces jointes refusées en V1** : `trix-file-accept` annulé, bouton de fichier masqué (voir « Décisions que ce plan suppose »). | B2, B4 | couvert par les tests système de B2 et B4, et par la garde d'import dynamique ci-dessous |
| `test/architecture/lazy_libraries_test.rb` | Aucun fichier de `app/javascript/` n'importe `trix`, `@rails/actiontext`, `katex` ni `canvas-confetti` **statiquement** (`import … from`, `import "…"`) : seuls les `import("…")` dynamiques sont permis (ADR-0051). | tous | — |
| `app/views/layouts/action_text/contents/_content.html.erb` | Gabarit de rendu d'un rich text : `<div class="rich-text">` avec les classes typographiques de l'UDR-0005 (titres, listes, citations, `pre`), sans valeur arbitraire. Le contenu est assaini au rendu par Action Text. | B1, B3 | couvert par les tests de B1 et B3 |
| `app/views/layouts/application.html.erb` (modifié) | Une ligne dans le `<head>` : `turbo_refreshes_with method: :morph, scroll: :preserve`. Un `turbo_stream.refresh` de succès re-demande la page courante et la fusionne, sans recharger la fenêtre. | tous les CRUD | couvert par les tests système des lots |
| `app/helpers/catalog/content_status_helper.rb` | `content_status_badge(status)` : « Brouillon — visible uniquement par l'équipe », « Publié », « Archivé ». **`content_status_panel(record:)`** : `<div id="content_status_<type>_<clé>">` avec le badge et, pour l'équipe, les transitions permises par `ContentStatus::TRANSITIONS` en boutons `button_to` (PATCH `publish` ou `archive`). Rendu par les pages de B1, B3 et C1 ; remplacé par les streams de B2, B4 et B5. | B1 à B5, C1 | `test/helpers/catalog/content_status_helper_test.rb` |
| `app/helpers/assessment/badges_helper.rb` | `badge_label(level)` → « Bronze », « Argent », « Or », « Diamant » ou « Non acquis » par `t()` (UDR-0007). `badge_tone(level)`. `mastery_label(score)` → « Acquis », « Fragile », « En difficulté » via `Grading.mastery_for`. `grade_label(score)` → « 14/20 ». | A2, B3, C1, C3 | `test/helpers/assessment/badges_helper_test.rb` : 4 paliers (50, 70, 80, 100), aucun libellé « Platine », « Médaille » ni « Trophée » |
| `app/infrastructure/queries/catalog/referential_options_query.rb` | `#call` → `Row(levels, series_by_level, materials)`, triés par position ou par nom ; chaque matière porte sa `category`. | B2, D1, D8, S2 | `test/infrastructure/queries/catalog/referential_options_query_test.rb` |
| `app/infrastructure/queries/school/school_options_query.rb` | `drenas` → `[Row(public_id, slug, name)]` ; `schools_for(drena_public_id:, status: "active")` → `[Row(public_id, name)]`. | D1, D8, S2, S3 | `test/infrastructure/queries/school/school_options_query_test.rb` |
| `app/infrastructure/queries/classroom/classroom_header_query.rb` | `#call(public_id:)` → `Row(public_id, name, level_name, series_name, school_name, school_year, status, join_code_display, max_students, active_students_count, teacher_ids, student_ids)` ou `nil`. Les faits de `ReadClassroomPolicy` et d'`AssignPolicy` en sont tirés. | D4, D5, D6, A3 | `test/infrastructure/queries/classroom/classroom_header_query_test.rb` |

**Badge de matière.** Aucun helper : les lots appellent `ui_subject_badge(material.name, category: material.category)` du Lot 0c. La couleur et l'icône viennent de la catégorie, jamais du nom (CA-26).

### e4 — Écran des imports, seeds, gardes (après le merge de 0d)

| Fichier | Contenu | Test |
|---|---|---|
| `app/jobs/shared/import_job.rb` | `Shared::ImportJob < ApplicationJob`, abstrait. `perform(report_id)` construit `RunImport` (repositories réels, `Transaction`, `AuditLogRepository`, `UserRepository`, horloge) avec `adapter` (méthode de la sous-classe) et `schema_validator` (surchargeable). `limits_concurrency to: 1, key: ->(_id) { self.class.name }`. `discard_on ActiveJob::DeserializationError`. | `test/jobs/shared/import_job_test.rb`, avec `FakeImportJob` |
| `app/controllers/teams/imports_controller.rb` | `Teams::ImportsController < Teams::BaseController`. `index` (rapports récents, filtre par type). `new` (`?kind=`) : **modale** dans le frame `modal`. `create` : `StartImport` ; succès → Turbo Stream : toast « Import lancé », `update "modal"` avec le suivi du rapport, `prepend "imports"` de sa ligne ; échec → modale re-rendue en **422** ; repli HTML : redirection vers `show`. `show` : HTML, et le frame `import_status` seul quand la requête vient du frame. La lecture d'un rapport applique la policy de son type. | `test/controllers/teams/imports_controller_test.rb` : non-team 403 ; 20 Mo + 1 octet → 422 ; second import du même type en cours → 422 avec message ; réponse `text/vnd.turbo-stream.html` |
| `app/views/teams/imports/index.html.erb` | Tableau `#imports` : date, type, fichier, statut (`ui_badge`), importés, ignorés, en erreur, auteur. Bouton « Nouvel import » (menu des quatre types, ouvre la modale). | — |
| `app/views/teams/imports/_import_row.html.erb` | Une ligne du tableau. | — |
| `app/views/teams/imports/new.html.erb` | `turbo_frame_tag "modal"` → `ui_modal(open: true)` : champ fichier (`accept=".json"`), rappel des limites (20 Mo, nombre d'éléments), puis `render "teams/imports/kinds/#{kind}"` **si ce partial existe** : aide et exemple fournis par le lot du type. | — |
| `app/views/teams/imports/create.turbo_stream.erb` | Toast, modale remplacée par le suivi, ligne ajoutée en tête. | — |
| `app/views/teams/imports/show.html.erb` | En-tête du rapport, puis le partial de statut. | — |
| `app/views/teams/imports/_status.html.erb` | `turbo_frame_tag "import_status"` avec `data-controller="teams--import-status"`, l'URL du frame et le statut. Pendant `validating` et `importing` : phase et barre `processed_count / total`. Quand l'import est fini : quatre compteurs (Importés, Ignorés (doublons), En erreur, Total), `details` (classes générées, niveaux ou séries sautés), puis la liste des erreurs. `rejected` : le motif du rejet en bloc. | — |
| `app/views/teams/imports/_import_errors.html.erb` | Une ligne par erreur : chemin JSON en `code`, motif traduit. « Et N autres erreurs » au-delà de 1 000. | — |
| `app/javascript/controllers/teams/import_status_controller.js` | Recharge le frame (`frame.reload()`) toutes les **3 s** tant que le statut est `queued`, `validating` ou `importing` ; s'arrête sinon, et à la déconnexion. Pas de WebSocket (ADR-0039). | couvert par le test système ci-dessous |
| `config/locales/teams/imports.fr.yml` | Écrans ; statuts (« En file d'attente », « Vérification », « Import en cours », « Terminé », « Rejeté », « Échoué ») ; compteurs ; un message par code d'`ImportError`. | — |
| `db/seeds.rb` (modifié) | Le tableau `SEEDS` de l'ADR-0034, tel quel : `identity` partout, `catalog` et `school` en développement et en test, `development` en développement. | `test/db/seeds_test.rb` : deux passages, mêmes comptes ; en `production` simulée, ni DRENA ni niveau ; `catalog.rb` évalué en production lève |
| `db/seeds/identity.rb` | Invitation d'amorçage (ADR-0034, ADR-0038) : si aucun compte `team` n'existe et que `ENV["TEAM_BOOTSTRAP_CONTACT"]` est posé, crée une invitation `kind: "team"`, `team_role: "admin"`, `invited_by_id: nil`, et affiche l'URL `/invitations/<jeton>` **une fois**. Aucun PIN dans le dépôt. | (même test) |
| `db/seeds/catalog.rb` | Garde `raise … unless Rails.env.local?`. Tel que dans l'ADR-0034 : niveaux 6ème, 5ème, 4ème, 3ème (`first`), 2nde, 1ère, Tle (`second`) ; séries A et C liées à la 2nde, A1, A2, C et D liées à la 1ère et à la Tle ; matières Mathématiques, Physique-Chimie, SVT (`science`), Français, Anglais, Histoire-Géographie, Philosophie (`literature`). Idempotent par slug. | (même test) |
| `db/seeds/school.rb` | Garde `Rails.env.local?`. Les 41 DRENA du fichier de données ci-dessous, puis quelques écoles (un lycée public, un lycée privé, un lycée mixte, un collège public) créées par `SchoolRepository#insert_many` et `ClassroomRepository#insert_generated` avec `DefaultClassroomPlan` : 77, 38, 38 et 28 classes. Idempotent par slug et par nom. | (même test) |
| `db/seeds/data/drenas.yml` | Les 41 DRENA, reprises de `.Business/content_pedagogics/Drenas.md` de l'ancienne application. | — |
| `db/seeds/development.rb` | Garde `Rails.env.development?`. Un compte team (`0700000000`, TOTP de développement affiché), un enseignant SVT `0500000001` onboardé qui enseigne « Tle D 1 », un élève `0100000001` membre principal, un cours publié avec une fiche et un exercice de 2 questions. PIN `2468`. | — |

| Garde d'architecture | Ce qu'elle vérifie |
|---|---|
| `test/architecture/port_contracts_test.rb` | Chaque module de `app/domain/ports/**` a **exactement un** implémenteur dans `app/infrastructure/`, qui définit chaque méthode avec les **mêmes paramètres**. |
| `test/architecture/use_case_policies_test.rb` | Chaque use case de `app/domain/use_cases/**` référence au moins une constante `Policies::`. **Seules exemptions**, nommées avec leur raison : `Identity::Authenticate`, `Identity::ResetPinWithCode`, `Identity::AcceptInvitation` (ADR-0028). |
| `test/architecture/layout_test.rb` | Aucun fichier à la racine de `entities/`, `use_cases/`, `ports/`, `dtos/`, `policies/`, `repositories/`, `queries/` ; aucun dossier `app/presentation/`, `app/services/`, `app/infrastructure/adapters/` ; `app/models/` ne contient que `application_record.rb` (ADR-0027) ; `grep find_or_create_by\|tmp/imports app/` ne renvoie rien (ADR-0039). |

| Test transverse | Ce qu'il vérifie |
|---|---|
| `test/system/teams/import_flow_test.rb` | Avec `FakeImportJob` (adaptateur `:inline` pour ce test) : un membre de l'équipe ouvre la modale d'import, envoie un fichier **mixte**, voit le suivi passer à « Terminé » **sans rechargement de page**, avec les compteurs exacts et chaque erreur à son chemin JSON ; un fichier à l'enveloppe invalide affiche « Rejeté » ; un fichier trop gros est refusé dans la modale (422). |

---

## Lots verticaux — règles communes

Chaque lot vertical :

- part de la branche d'intégration **après** le merge des quatre sous-lots du socle. Sa branche s'appelle `feature/boucle-pedagogique-lot-<id>` ; il travaille dans son propre worktree, avec sa propre base ;
- reçoit le **brief standard** de [`boucle-de-travail.md`](../refonte-application/boucle-de-travail.md) §5 : fichiers autorisés, tests rouges d'abord, sortie `bin/ci` ;
- **ne modifie aucun fichier du socle** : ports, entités, policies, DTO du socle, repositories, routes, fabriques, locales communes, layout, composants, moteur d'import. Un besoin de changement de contrat **arrête le lot** : l'agent le signale à l'orchestrateur, qui décide ;
- câble ses dépendances dans le contrôleur ou le job (`UseCases::X.new(repo: Repositories::…new, policy: Policies::…new, transaction: Repositories::Shared::Transaction.new)`) ;
- lit par une **query** (`Queries::<Ctx>::<Nom>Query` → `Row`), écrit par un **use case** (ADR-0026) ;
- construit ses écrans avec les composants `ui_*` du Lot 0c ; le badge de matière est **toujours** `ui_subject_badge(name, category:)` ;
- reproduit **la structure et le parcours** des écrans de l'ancienne application cités, pas leur CSS ;
- écrit ses textes dans **sa** locale `config/locales/<ctx>/<écran>.fr.yml`, avec le vocabulaire de l'UDR-0007 ;
- met l'en-tête HITL de 3 lignes sur chaque fichier créé dans `app/` ;
- écrit son UDR sous le numéro réservé, sans toucher au README des UDR ;
- vise 100 % de couverture, lignes et branches, sur ses fichiers, sans `:nocov:`.

**Règle Hotwire** (porteur, UDR-0006 §7, brief standard §5). Elle vaut pour tout lot à écran.

1. **Création et édition en modale.** Le lien d'ouverture porte `data-turbo-frame="modal"`. La vue `new` ou `edit` rend `turbo_frame_tag "modal"` → `ui_modal(title:, open: true)` → `form_with id: "<ressource>-form"`. Il n'existe **pas** de page `new` ou `edit` autonome : hors frame, la même vue s'affiche en modale ouverte sur le shell (repli HTML).
2. **Erreur de validation** : `render :new` ou `:edit`, `status: :unprocessable_entity`. La modale se rouvre avec ses erreurs et les valeurs saisies.
3. **Succès** : `create`, `update`, `destroy` et les transitions répondent par un fichier `<action>.turbo_stream.erb` : un toast (`turbo_stream_toast`), la liste mise à jour (`append`, `prepend`, `replace`, `remove`) quand elle est sur la page du lot, et la modale refermée. Quand la page hôte appartient à un **autre** lot (par exemple « Modifier le cours » ouvert depuis la page du cours de B1), le stream fait `turbo_stream.refresh(request_id: nil)` : la page est re-demandée et fusionnée par morphing, sans rechargement de fenêtre et sans rendre un partial d'un autre lot. **Jamais de redirection** depuis la modale.
4. **Repli HTML** : chaque action garde un `format.html` (redirection vers la liste avec un flash), pour un client sans Turbo.
5. **Frames** : filtres, recherche, pagination et listes secondaires dans un `turbo_frame_tag` avec `data-turbo-action="advance"` ; chargement différé avec `ui_loading_state`.
6. **Stimulus** seulement pour ce que Turbo ne couvre pas (copier dans le presse-papiers, champs imbriqués, rechargement périodique).
7. **Preuve** : chaque lot à écran a **un test système** (Chrome headless). Tout parcours d'écriture y est enveloppé dans `assert_no_page_reload`. Le test n'ouvre que des pages de son lot ou du socle ; un formulaire dont le bouton vit dans l'écran d'un autre lot est ouvert par `open_in_modal`. Le parcours par les vrais boutons est rejoué au Lot E.
8. Un lot **sans écriture en place** (écran en lecture seule, ou formulaire qui ouvre une session et change de page) n'a pas de `*.turbo_stream.erb` : son champ **Hotwire** le dit, et son test système prouve le rendu et la navigation.

**Règles supplémentaires des lots d'import (S3, I1, I2, I3).**
- L'adaptateur inclut `UseCases::Catalog::Importer`, référence sa policy et passe `assert_importer_contract`.
- Il livre sa sous-classe de `Shared::ImportJob`, déjà nommée dans `config.x.import_jobs` : aucun fichier du socle n'est touché.
- Son schéma JSON est `config/schemas/<format>.v1.json` (ADR-0039), validé par `json_schemer` via `ImportSchemaPort`. Les alias de clés de l'ancienne application y sont permis.
- Son partial `app/views/teams/imports/kinds/_<kind>.html.erb` explique le format, donne un exemple minimal et rappelle la cible.
- **Import partiel** (ADR-0039, arbitrage du porteur) : les éléments valides sont importés, les invalides listés avec leur chemin JSON et leur motif, les doublons ignorés et comptés ; seul un fichier dont l'enveloppe, la version ou la cible est invalide est rejeté en bloc. Chaque lot a le test **« fichier mixte → rapport exact »** : un fichier de N éléments racines, dont des valides, des invalides à des chemins connus, un doublon en base et un doublon dans le fichier, donne exactement les compteurs et les chemins attendus, et **aucun élément invalide n'a laissé de ligne**.
- Son **test de performance** est `test/performance/<ctx>/import_<kind>_performance_test.rb`, ignoré sans `PERF=1` (donc hors CI), joué avant la recette. Il mesure `RunImport` complet sur PostgreSQL et échoue au-delà de 120 s.

**Où lire l'inventaire.**

| Contexte | Fichiers |
|---|---|
| Identity | `inventaire/identity-communication.md` · `inventaire/complements-identity-communication.md` |
| Classroom et School | `inventaire/classroom-school.md` · `inventaire/complements-school-classroom.md` |
| Catalog | `inventaire/catalog.md` · `inventaire/complements-catalog.md` |
| Assessment | `inventaire/assessment.md` · `inventaire/complements-assessment.md` |
| Transverse | `inventaire/transverse.md` · `inventaire/complements-transverse.md` · `inventaire/ui-design-system.md` |
| Sécurité | [`securite.md`](../refonte-application/securite.md), par numéro |

---

## Lot A1 — Rejoindre une classe par son code

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/classroom/join_with_code_input.rb`
    - Inclut `Dtos::Identity::PersonNameInput`. `gender`, `contact` (normalisé), `pin`, `pin_confirmation`. **Aucun attribut `role`.**
  - `app/domain/use_cases/classroom/join_with_code.rb`
    - Visiteur (ADR-0040). DTO ; puis, dans une transaction : `classrooms.lock_by_join_code` (absente : `:not_found`), `JoinPolicy` (raison affichée), `registrations.create_student` (numéro pris : `:conflict` sur `contact`), `memberships.add_primary`.
    - Le rôle est **imposé** à `student`. Le verrou garantit le plafond `max_students` sous concurrence (ADR-0041).
  - `app/domain/use_cases/classroom/join_as_student.rb`
    - Élève connecté. Classe principale active : `:conflict` (« Tu es déjà inscrit dans une classe »). Classe principale archivée : `leave_primary`, puis `add_primary` sur la nouvelle, sous `JoinPolicy`.
  - `app/infrastructure/queries/classroom/join_preview_query.rb`
    - `#call(code:)` → `Row(classroom_name, school_name, level_name)` ou `nil`. Ni identifiant, ni effectif, ni enseignant.
  - `app/controllers/classroom/join_codes_controller.rb`
    - `allow_unauthenticated_access`. `new` : champ « Code de classe ». `create` : `JoinCode.normalize`, puis redirection vers `join_classroom_path(code)`.
  - `app/controllers/classroom/joins_controller.rb`
    - `allow_unauthenticated_access`. `rate_limit to: 10, within: 1.minute` (ADR-0041).
    - `new` : aperçu de la classe ; code inconnu : 404 avec « Code de classe invalide. » et lien vers `new_join_code_path`. Visiteur : formulaire d'inscription. Élève connecté : bouton « Rejoindre cette classe ».
    - `create` : `JoinWithCode` (visiteur) ou `JoinAsStudent` (élève), puis `start_session` le cas échéant, puis `student_home_path` avec « Bienvenue dans ta classe ! ». Échec : formulaire re-rendu en 422.
    - Un enseignant ou un membre de l'équipe connecté reçoit 403.
  - `app/views/classroom/join_codes/new.html.erb`
  - `app/views/classroom/joins/new.html.erb`
  - `app/views/classroom/joins/_classroom_preview.html.erb`
    - Bandeau « Classe — Établissement ».
  - `app/views/classroom/joins/_signup_form.html.erb`
    - Nom, Prénom(s), genre en radios, numéro, PIN (`password`, 4 chiffres, `inputmode numeric`) et confirmation.
  - `config/locales/classroom/joins.fr.yml`
- **Dépend de**    : socle (0a, 0b, 0d, 0e)
- **Test associé** :
  - `test/domain/dtos/classroom/join_with_code_input_test.rb`
  - `test/domain/use_cases/classroom/join_with_code_test.rb`
    - Classe archivée, code révoqué, classe pleine, numéro pris, atomicité (aucun compte sans adhésion).
  - `test/domain/use_cases/classroom/join_as_student_test.rb`
  - `test/infrastructure/queries/classroom/join_preview_query_test.rb`
  - `test/controllers/classroom/joins_controller_test.rb`
    - TR-cadre-1 (paramètre `role=team` ignoré), PIN vide, confirmation différente, `/c/<inconnu>` 404, 429, enseignant 403.
  - `test/controllers/classroom/join_codes_controller_test.rb`
  - `test/integration/classroom/join_capacity_test.rb`
    - Deux inscriptions concurrentes sur la dernière place : une seule réussit.
  - `test/system/classroom/join_test.rb`
    - Code saisi, aperçu, inscription avec une confirmation de PIN fausse : erreurs affichées **sans rechargement de page** ; puis inscription juste : arrivée connecté sur `/students`. Même parcours en 390 px.
- **Done quand**   : un visiteur ouvre `/c/kfm37`, s'inscrit et arrive connecté sur `/students` ; une erreur de saisie s'affiche **sans rechargement de page**. Les critères ID-01, ID-02, CL-06, CL-07, CL-08 et les trois refus de `JoinPolicy` sont verts.
- **Hotwire**      : formulaires en Turbo Drive ; erreur re-rendue en 422 dans le formulaire ; succès : navigation Turbo vers l'accueil (changement de page voulu : la session vient de naître). Pas de `*.turbo_stream.erb` : aucune liste à mettre à jour.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/students/registrations/new.html.erb`
  - `⟨ancienne⟩ javascript/controllers/classrooms_controller.js` (comportement de l'aperçu)
  - captures `docs/design/captures/original/student-signup--desktop.png` et `student-signup--mobile.png`
- **Fiches d'inventaire** : ID-01, ID-02, ID-07, ID-08 (partie écartée), CL-06, CL-07, CL-08. Sécurité n° 5.
- **Non-régression** :
  - la cascade école + niveau → classe n'existe pas ;
  - la création n'est jamais partielle ;
  - l'aperçu ne révèle rien d'autre que le nom de la classe, du niveau et de l'établissement, et il est limité en débit.
- **UDR**          : UDR-0009 — Rejoindre une classe

---

## Lot A2 — Accueil élève

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_home_query.rb`
    - `Row(school_name, level_name, classroom_name, classmates_count, assigned_exercises:, recent_sessions:, pending_gaps:)`.
    - `assigned_exercises` : exercices assignés **actifs**, directement ou par leur fiche ou leur cours, à la classe principale, **publiés** ainsi que leurs parents. Pour chacun : `public_id, title, material_name, material_category, badge_level, best_score_percent, completed_count, started_session_public_id`.
    - `recent_sessions` : les 10 dernières sessions `completed`, avec score et note sur 20.
    - `pending_gaps` : lacunes `pending` (ADR-0043), avec le nom de la fiche essentielle.
  - `app/controllers/classroom/student_homes_controller.rb`
    - `allow_roles :student`. Sans classe principale active : un seul saut vers `pending_account_path`.
  - `app/views/classroom/student_homes/show.html.erb`
    - Sections dans l'ordre de `NavigationHelper::HOME_SECTIONS[:student]`.
  - `app/views/classroom/student_homes/_classroom_card.html.erb`
    - Classe, établissement, niveau, nombre de camarades. **Pas de code d'adhésion.**
  - `app/views/classroom/student_homes/_assigned_exercise.html.erb`
    - `ui_subject_badge`, badge par `badge_label` (Bronze, Argent, Or, Diamant), meilleur score et maîtrise, nombre de sessions, bouton « Commencer » ou « Reprendre ».
  - `app/views/classroom/student_homes/_recent_activity.html.erb`
  - `app/views/classroom/student_homes/_pending_gaps.html.erb`
    - « Fiches essentielles à revoir », lien vers la fiche.
  - `config/locales/classroom/student_homes.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_home_query_test.rb`
    - Assignation retirée, exercice archivé ou brouillon : absent. Assignation par cours : présent. Meilleur score. Classe principale seulement.
  - `test/controllers/classroom/student_homes_controller_test.rb`
    - 200 ; sans classe : une redirection ; enseignant 403 ; le HTML ne contient pas le code de la classe.
  - `test/system/classroom/student_home_test.rb`
    - Un élève connecté voit son exercice assigné et son badge ; « Commencer » mène à la session. En 390 px, la barre du bas est visible.
- **Done quand**   : un élève connecté voit ses exercices assignés et leur progression. Les critères CL-23, TR-04 et AS-36 sont verts.
- **Hotwire**      : écran en lecture seule, sans écriture en place : pas de `*.turbo_stream.erb`. Les sections secondaires (activité récente) sont des frames paresseux avec `ui_loading_state variant: :skeleton`. Test système du rendu et de la navigation.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/students/feed/index.html.erb`
  - `⟨ancienne⟩ views/students/feed/content/_feed_header.html.erb`, `_classroom.html.erb`, `_exercises.html.erb`, `_activities.html.erb`, `_empty_state.html.erb`
  - `⟨ancienne⟩ views/components/_exercise_card.html.erb` et `_exercise_badge.html.erb`
- **Fiches d'inventaire** : TR-04, CL-23, AS-36, TR-02 (élève sans classe).
- **Non-régression** : pas de boucle de redirection pour l'élève sans classe ; aucun exercice non publié listé ; le code de la classe n'est jamais montré à l'élève.
- **UDR**          : UDR-0010 — Accueil élève

---

## Lot A3 — Ma classe (élève)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/student_classroom_query.rb`
    - `Row(classroom_name, level_name, series_name, school_name, school_year, courses:)`. `courses` : cours assignés actifs et publiés, avec `slug, name, subtitle, material_name, material_category, essentials_count`. **Ni code, ni liste nominative.**
  - `app/controllers/classroom/student_classrooms_controller.rb`
    - `allow_roles :student`. L'en-tête vient de `ClassroomHeaderQuery`, sous `ReadClassroomPolicy` ; la vue n'en rend ni `join_code_display` ni `student_ids`.
  - `app/views/classroom/student_classrooms/show.html.erb`
  - `app/views/classroom/student_classrooms/_assigned_course.html.erb`
  - `config/locales/classroom/student_classrooms.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/classroom/student_classroom_query_test.rb`
  - `test/controllers/classroom/student_classrooms_controller_test.rb`
    - Le HTML ne contient ni le code de la classe ni le nom d'un autre élève.
  - `test/system/classroom/student_classroom_test.rb`
    - L'élève voit ses cours assignés, ouvre l'un d'eux.
- **Done quand**   : les critères CL-22 et CL-10 (volet élève) sont verts ; **l'élève ne voit pas le code de sa classe**.
- **Hotwire**      : lecture seule, pas de stream ; test système du rendu.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/students/classroom/show.html.erb`, `⟨ancienne⟩ views/students/feed/content/_courses.html.erb`
- **Fiches d'inventaire** : CL-22, CL-10 (volet élève).
- **Non-régression** : aucun cours retiré ou archivé affiché.
- **UDR**          : UDR-0011 — Ma classe

---

## Lot A4 — Landing (contenu V1)

- **Couche**       : ui
- **Fichiers**     :
  - `app/views/homepage/index.html.erb` (modifié)
    - Deux entrées, « Je suis élève » et « Je suis enseignant », qui ouvrent chacune un `ui_modal` (contrôleur Stimulus `modal` du Lot 0c).
  - `app/views/homepage/_role_modal.html.erb`
    - Élève : « Se connecter » (`new_session_path`) et « Rejoindre ma classe » (`new_join_code_path`). Enseignant : « Se connecter » et « Créer un compte » (`new_teacher_registration_path`).
  - `config/locales/homepage/index.fr.yml` (modifié)
- **Dépend de**    : socle
- **Test associé** :
  - `test/controllers/homepage_controller_test.rb` (modifié)
    - Chaque `href` est reconnu par le routeur (`Rails.application.routes.recognize_path`).
  - `test/system/homepage_test.rb` (modifié)
    - Ouvrir la modale élève puis la modale enseignant **sans rechargement de page**, suivre « Rejoindre ma classe ».
- **Done quand**   : le critère TR-01 est vert, aucun lien de la landing ne pointe vers une chaîne littérale, et les modales s'ouvrent sans rechargement.
- **Hotwire**      : pas d'écriture ; les modales de rôle sont du contenu statique ouvert par Stimulus (`modal`, Lot 0c). Pas de stream.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/homepage/index.html.erb`
  - `⟨ancienne⟩ javascript/controllers/homepage_student_modal_controller.js` et `homepage_teacher_modal_controller.js`
  - captures `original/accueil--desktop.png`, `accueil--mobile.png`, `accueil-modale-eleve--*.png`, `accueil-modale-enseignant--*.png`
- **Fiches d'inventaire** : TR-01, TR-03 (le lien « Espace Etabl. » n'est **pas** repris : V2).
- **Non-régression** : aucun lien vers une route inexistante (TR-03).
- **UDR**          : UDR-0012 — Landing, modales de rôle

---

## Lot B1 — Catalogue et lecture d'un cours

- **Couche**       : infrastructure (queries) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/catalog/course_catalog_query.rb`
    - `#call(actor:, level: nil, material: nil)` → `[Row(slug, name, subtitle, level_name, series_name, material_name, material_category, status)]`. Publiés seulement, sauf pour l'équipe. Tri par matière, niveau, nom.
  - `app/infrastructure/queries/catalog/course_detail_query.rb`
    - `#call(slug:)` → `Row(course, essentials:)` avec l'état publié du cours et son rich text (`with_rich_text_content`) ; le contrôleur applique `ReadPublishedPolicy` (refus → 404). Fiches essentielles publiées, ou toutes pour l'équipe, avec `slug, name, subtitle, exercises_count`.
  - `app/controllers/catalog/courses_controller.rb`
    - `index`, `show`, pour tous les rôles connectés. `index` rend le frame `courses` seul quand la requête vient de ce frame.
  - `app/views/catalog/courses/index.html.erb`
    - Filtres niveau et matière (formulaire GET visant `turbo_frame_tag "courses"`, `data-turbo-action="advance"`), grille de cartes dans le frame. Pour l'équipe : « Nouveau cours » (`new_teams_course_path`, `data-turbo-frame="modal"`) et « Importer des cours » (`new_teams_import_path(kind: "course_tree")`, même frame).
  - `app/views/catalog/courses/show.html.erb`
    - Fil d'Ariane, badges niveau, série et matière, `content_status_panel(record:)` pour l'équipe, contenu rendu par Action Text (assaini par sa liste blanche, gabarit `rich-text` du socle) dans `data-controller="math"`, section « Fiches essentielles ».
  - `app/views/catalog/courses/_course_card.html.erb`
  - `app/views/catalog/courses/_essential_row.html.erb`
  - `app/views/catalog/courses/_role_actions.html.erb`
    - Équipe : `ui_dropdown` « Modifier » (`edit_teams_course_path`), « Nouvelle fiche essentielle » (`new_teams_course_essential_path`), « Importer des fiches essentielles » (`new_teams_import_path(kind: "essentials", course: slug)`, le partial du type rappelle le slug à mettre dans l'enveloppe). Tous en `data-turbo-frame="modal"`.
    - Enseignant : « Assigner à mes classes » (`course_assignments_path`, CA-27).
  - `config/locales/catalog/courses.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/catalog/course_catalog_query_test.rb`
  - `test/infrastructure/queries/catalog/course_detail_query_test.rb`
  - `test/controllers/catalog/courses_controller_test.rb`
    - Brouillon ouvert par un élève ou un enseignant : 404. Actions d'équipe et d'import visibles pour l'équipe seulement. « Assigner à mes classes » pour l'enseignant seulement. Le contenu est nettoyé (`<script>` retiré).
  - `test/system/catalog/course_catalog_test.rb`
    - Filtrer par matière **sans rechargement de page** (l'URL change) ; ouvrir un cours ; une formule `$…$` est rendue par KaTeX.
- **Done quand**   : les critères CA-01, CA-04, CA-10, CA-26 et TR-41 sont verts ; le filtrage se fait **sans rechargement de page**.
- **Hotwire**      : filtres dans le frame `courses` ; liens d'écriture ouverts dans le frame `modal` (les formulaires appartiennent à B2, B4 et 0e). Pas de stream propre : les pages de B1 sont rafraîchies par morphing par les streams de B2 et B4, et leur panneau de statut remplacé.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/catalog/courses/index.html.erb`, `show.html.erb` et `_course.html.erb`
  - `⟨ancienne⟩ views/components/courses/_course_card.html.erb`
  - captures `teams/Lnclass - Les cours (23.09.2026 16_14).png` et `teams/Lnclass - Génétique Et évolution (23.09.2026 16_14).png`
- **Fiches d'inventaire** : CA-01, CA-04, CA-10, CA-26, CA-27 (point d'entrée), CA-08 et CA-15 (points d'entrée des imports), TR-41.
- **Non-régression** : un brouillon n'est jamais lisible par URL directe ; la couleur d'une matière vient de sa catégorie ; aucun KaTeX servi par un CDN.
- **UDR**          : UDR-0013 — Catalogue et page cours

---

## Lot B2 — Gestion des cours (équipe)

- **Couche**       : domaine (DTO, use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/catalog/course_input.rb`
    - `name, subtitle, level_slug, series_slug, material_slug, content` (HTML produit par l'éditeur riche ; le domaine le garde en chaîne, sans connaître Action Text).
  - `app/domain/use_cases/catalog/create_course.rb`
    - DTO ; faits : niveau, matière, série, `lookup.pair?` (série non permise : `:invalid`) ; `ManageContentPolicy` ; `courses.create` en `draft`, `author_id = actor.user_id`. Nom pris : `:conflict`.
  - `app/domain/use_cases/catalog/update_course.rb`
  - `app/domain/use_cases/catalog/publish_course.rb`
    - `ContentStatus.transition` (ADR-0035) ; audit `content.published`.
  - `app/domain/use_cases/catalog/archive_course.rb`
    - Audit `content.archived`. Aucune écriture sur les fiches ni sur les assignations.
  - `app/controllers/teams/courses_controller.rb`
    - `new`, `create`, `edit`, `update`, `publish`, `archive`. Échec : `render :new` ou `:edit` en 422. Repli HTML : `course_path`.
  - `app/views/teams/courses/new.html.erb`
  - `app/views/teams/courses/edit.html.erb`
    - `turbo_frame_tag "modal"` → `ui_modal(size: :lg, open: true)` → `_form`.
  - `app/views/teams/courses/_form.html.erb`
    - `form_with id: "course-form"`. Nom, sous-titre, niveau, série (options filtrées par niveau côté serveur), matière, contenu dans l'**éditeur riche** : `f.rich_textarea :content` dans un conteneur `data-controller="rich-text-editor"` (Trix chargé à la demande, 0e). Pièces jointes refusées en V1. Le statut ne se change pas dans le formulaire.
  - `app/views/teams/courses/create.turbo_stream.erb`
    - Toast « Cours créé (brouillon) », modale refermée, `turbo_stream.refresh(request_id: nil)` : le catalogue de B1 se met à jour par morphing.
  - `app/views/teams/courses/update.turbo_stream.erb`
    - Toast « Cours modifié », modale refermée, refresh de la page du cours.
  - `app/views/teams/courses/transition.turbo_stream.erb`
    - Rendu par `publish` et `archive` : toast, `turbo_stream.replace` du `content_status_panel` du cours. Refus (`:conflict`) : toast d'erreur, statut 422.
  - `config/locales/teams/courses.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/catalog/course_input_test.rb`
  - `test/domain/use_cases/catalog/create_course_test.rb`
  - `test/domain/use_cases/catalog/update_course_test.rb`
  - `test/domain/use_cases/catalog/publish_course_test.rb`
    - Archivé → publié permis ; retour à draft refusé.
  - `test/domain/use_cases/catalog/archive_course_test.rb`
  - `test/controllers/teams/courses_controller_test.rb`
    - Élève ou enseignant : 403. `create` et `publish` en `text/vnd.turbo-stream.html` ; nom vide : 422 ; repli HTML : redirection.
  - `test/integration/catalog/course_lifecycle_test.rb`
    - Créer, lire, modifier, publier, archiver, republier par le même agrégat (chantier `catalog-lecture-ecriture-incompatibles`).
  - `test/system/teams/course_management_test.rb`
    - Depuis une page du socle, `open_in_modal(new_teams_course_path)` : nom vide → erreurs dans la modale, puis création → toast ; même chose pour l'édition ; le tout dans `assert_no_page_reload`.
    - Éditeur riche : Trix se charge dans la modale, **sous la CSP stricte** (aucune erreur de CSP dans la console) ; un passage mis en gras et une liste à puces sont enregistrés et rendus tels quels sur la page du cours ; le contenu déjà saisi est rechargé dans l'éditeur à l'édition ; un fichier glissé dans l'éditeur est refusé.
- **Done quand**   : les critères CA-05, CA-06 et CA-07 sont verts ; le contenu se saisit dans l'**éditeur riche** ; création, modification, publication et archivage se font **sans rechargement de page**.
- **Hotwire**      : modales `new` et `edit` ; 422 dans la modale ; `create`, `update`, `transition` en `*.turbo_stream.erb` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/courses/new.html.erb`, `edit.html.erb` et `_form.html.erb`
- **Fiches d'inventaire** : CA-05, CA-06, CA-07. Contradiction C-19 (feuille de route §4).
- **Non-régression** : le nom n'est pas passé en `titleize` ; il n'y a pas deux familles d'entités ; l'archivage ne détruit rien.
- **UDR**          : UDR-0014 — Formulaire cours

---

## Lot B3 — Fiche essentielle : lecture et progression

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/catalog/essential_detail_query.rb`
    - `#call(course_slug:, slug:, student_id: nil)` → la fiche, son cours et leurs statuts, puis les exercices (publiés, ou tous pour l'équipe). Pour un élève, chaque exercice porte `assigned_to_my_classroom`, `badge_level`, `best_score_percent` et `started_session_public_id`, puis la lacune `pending` éventuelle de la fiche.
  - `app/controllers/catalog/essentials_controller.rb`
    - `show`, sous `ReadPublishedPolicy` (fiche et cours ; refus → 404).
  - `app/views/catalog/essentials/show.html.erb`
    - Contenu rendu par Action Text, avec KaTeX, `content_status_panel` pour l'équipe, liste des exercices. Menu d'équipe en modales : « Modifier » (`edit_teams_essential_path`), « Nouvel exercice » (`new_teams_essential_exercise_path`), « Importer des exercices » (`new_teams_import_path(kind: "exercises", essential: slug)`).
  - `app/views/catalog/essentials/_exercise_progress.html.erb`
    - Tout exercice publié se démarre (ADR-0028). Un exercice assigné à la classe de l'élève porte l'étiquette « Assigné par ton enseignant ».
  - `config/locales/catalog/essentials.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/catalog/essential_detail_query_test.rb`
  - `test/controllers/catalog/essentials_controller_test.rb`
  - `test/system/catalog/essential_page_test.rb`
    - L'élève voit sa progression (badge « Or » à 80 %) et démarre un exercice.
- **Done quand**   : les critères CA-11 et AS-37 sont verts.
- **Hotwire**      : lecture seule, pas de stream ; liens d'écriture vers le frame `modal`. Rafraîchie par les streams de B4 et B5.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/catalog/essentials/show.html.erb` et `_essential.html.erb`
  - captures `teams/Lnclass - Habilité _ Brassage Génétique Par La Méiose (23.09.2026 16_15).png` et `teams/Lnclass - Anomalies De La Méiose (23.09.2026 16_15).png`
  - Le mot « Habilité » des captures n'est **pas** repris (UDR-0007).
- **Fiches d'inventaire** : CA-10, CA-11, AS-37.
- **Non-régression** : aucun exercice non publié listé à un élève.
- **UDR**          : UDR-0015 — Page fiche essentielle

---

## Lot B4 — Gestion des fiches essentielles (équipe)

- **Couche**       : domaine (DTO, use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/catalog/essential_input.rb`
    - `course_slug, name, subtitle, content` (HTML produit par l'éditeur riche).
  - `app/domain/use_cases/catalog/create_essential.rb`
    - DTO ; cours existant ; `ManageContentPolicy` ; nom unique dans le cours ; `draft` ; position = `next_position`.
  - `app/domain/use_cases/catalog/update_essential.rb`
  - `app/domain/use_cases/catalog/publish_essential.rb`
    - Cours non publié : `:conflict` (ADR-0035).
  - `app/domain/use_cases/catalog/archive_essential.rb`
  - `app/controllers/teams/essentials_controller.rb`
    - `new`, `create` (sous le cours), `edit`, `update`, `publish`, `archive`.
  - `app/views/teams/essentials/new.html.erb`
  - `app/views/teams/essentials/edit.html.erb`
  - `app/views/teams/essentials/_form.html.erb`
    - `form_with id: "essential-form"`, contenu dans l'**éditeur riche** (`f.rich_textarea :content` sous `data-controller="rich-text-editor"`, comme B2).
  - `app/views/teams/essentials/create.turbo_stream.erb`
    - Toast « Fiche essentielle créée (brouillon) », modale refermée, refresh (page du cours, B1).
  - `app/views/teams/essentials/update.turbo_stream.erb`
  - `app/views/teams/essentials/transition.turbo_stream.erb`
  - `config/locales/teams/essentials.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/catalog/essential_input_test.rb`
  - `test/domain/use_cases/catalog/create_essential_test.rb`
  - `test/domain/use_cases/catalog/update_essential_test.rb`
  - `test/domain/use_cases/catalog/publish_essential_test.rb`
  - `test/domain/use_cases/catalog/archive_essential_test.rb`
  - `test/controllers/teams/essentials_controller_test.rb`
    - Enseignant ou élève : 403 (l'ancienne application ouvrait la création à tout compte connecté). Réponses en Turbo Stream, 422, repli HTML.
  - `test/system/teams/essential_management_test.rb`
    - `open_in_modal(new_teams_course_essential_path(course))` : erreur, puis création, puis édition, dans `assert_no_page_reload`. Le contenu est saisi dans Trix (gras, liste) sous la CSP stricte et rendu tel quel sur la page de la fiche.
- **Done quand**   : les critères CA-12, CA-13 et CA-14 sont verts ; le contenu se saisit dans l'**éditeur riche** ; tout se fait **sans rechargement de page**.
- **Hotwire**      : comme B2 (modales, 422, trois streams, repli HTML).
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/essentials/new.html.erb`, `edit.html.erb` et `_form.html.erb`
- **Fiches d'inventaire** : CA-12, CA-13, CA-14.
- **Non-régression** : création fermée aux non-équipe ; archivage sans cascade.
- **UDR**          : UDR-0016 — Formulaire fiche essentielle

---

## Lot B5 — Gestion des exercices (équipe)

- **Couche**       : domaine (DTO, use cases) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/dtos/assessment/answer_input.rb`
  - `app/domain/dtos/assessment/question_input.rb`
  - `app/domain/dtos/assessment/exercise_input.rb`
    - `title, description, exercise_type, questions` ; `ExerciseInput.from_params(hash)` construit l'arbre depuis `questions_attributes`.
  - `app/domain/use_cases/assessment/create_exercise.rb`
    - `ManageContentPolicy`, DTO, entité `Exercise` avec ses `Question` et `Answer` ; `Question.structure_errors_for` ; `draft`.
  - `app/domain/use_cases/assessment/update_exercise.rb`
    - Si `has_sessions?`, toute modification de question renvoie `:invalid` avec `questions_locked` (ADR-0036, ADR-0054).
  - `app/domain/use_cases/assessment/publish_exercise.rb`
    - `Exercise#publishable?` et fiche publiée, sinon `:conflict`.
  - `app/domain/use_cases/assessment/archive_exercise.rb`
  - `app/controllers/teams/exercises_controller.rb`
    - `new`, `create` (sous la fiche), `edit`, `update`, `publish`, `archive`.
  - `app/views/teams/exercises/new.html.erb`
  - `app/views/teams/exercises/edit.html.erb`
    - Modale `size: :lg`.
  - `app/views/teams/exercises/_form.html.erb`
    - `form_with id: "exercise-form"`. Titre, description, type (fixation ou évaluation), questions. Questions verrouillées : bandeau et champs en lecture seule.
  - `app/views/teams/exercises/_question_fields.html.erb`
    - Énoncé, explication, type, propositions.
  - `app/views/teams/exercises/_answer_fields.html.erb`
    - Texte de la proposition et case « Proposition correcte ».
  - `app/views/teams/exercises/create.turbo_stream.erb`
  - `app/views/teams/exercises/update.turbo_stream.erb`
  - `app/views/teams/exercises/transition.turbo_stream.erb`
  - `app/javascript/controllers/teams/nested_form_controller.js`
    - « + Ajouter une question », « + Ajouter une proposition », « Retirer », par clonage de `<template>` rendus par le serveur. Turbo ne sait pas ajouter un champ sans aller-retour : c'est le cas où Stimulus est justifié.
  - `config/locales/teams/exercises.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/assessment/exercise_input_test.rb`
  - `test/domain/use_cases/assessment/create_exercise_test.rb`
    - Quatre types de question, valides et invalides ; titre sans `titleize`.
  - `test/domain/use_cases/assessment/update_exercise_test.rb`
  - `test/domain/use_cases/assessment/publish_exercise_test.rb`
  - `test/domain/use_cases/assessment/archive_exercise_test.rb`
  - `test/controllers/teams/exercises_controller_test.rb`
    - TR-cadre-6 : l'archivage conserve sessions, tentatives et badges. Non-équipe : 403. Turbo Stream et 422.
  - `test/system/teams/exercise_form_test.rb`
    - `open_in_modal(new_teams_essential_exercise_path(essential))` : ajouter 2 questions et 5 propositions, soumettre une question sans proposition correcte (erreur dans la modale), corriger, enregistrer, rouvrir en édition ; le tout **sans rechargement de page**.
- **Done quand**   : les critères AS-03, AS-04 et AS-05 sont verts ; l'exercice se crée et se modifie **sans rechargement de page**.
- **Hotwire**      : comme B2, en modale `lg` ; Stimulus pour les champs imbriqués seulement.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercises/new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_question_fields.html.erb` et `_answer_fields.html.erb`
  - Le contrôleur Stimulus `nested-form` **n'existait pas** : il est à construire.
- **Fiches d'inventaire** : AS-03, AS-04, AS-05. Complément assessment §3 (C-08 à C-11).
- **Non-régression** : « + Ajouter une question » n'est pas inerte ; les questions sont persistées ; l'archivage ne détruit rien.
- **UDR**          : UDR-0017 — Formulaire exercice

---

## Lot B6 — Accueil équipe et section Référentiel

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/catalog/team_home_query.rb`
    - `Row(drenas_count, schools_count, classrooms_count, levels:, materials_count, recent_courses:, recent_exercises:, recent_imports:)`. Listes récentes triées par `updated_at`, tous statuts.
  - `app/controllers/teams/homes_controller.rb`
    - `show`.
  - `app/views/teams/homes/show.html.erb`
    - Sections dans l'ordre de `HOME_SECTIONS[:team]` ; sections secondaires en frames paresseux.
  - `app/views/teams/homes/_shortcuts.html.erb`
    - « Nouveau cours » (modale), « Établissements » (`schools_path`), « Importer » (`teams_imports_path`), « Inviter un membre » (`new_teams_invitation_path`, modale), « Débloquer un compte » (`teams_account_lookup_path`).
  - `app/views/teams/homes/_referential.html.erb`
    - Section « Référentiel » (CA-25) : DRENA, niveaux, séries, matières, avec leurs compteurs et un lien vers chaque écran de gestion (`drenas_path`, `levels_path`, `series_index_path`, `materials_path`).
  - `app/views/teams/homes/_recent_content.html.erb`
  - `config/locales/teams/homes.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/catalog/team_home_query_test.rb`
  - `test/controllers/teams/homes_controller_test.rb`
  - `test/system/teams/team_home_test.rb`
    - Le membre de l'équipe voit ses compteurs ; « Nouveau cours » ouvre la modale sans rechargement.
- **Done quand**   : les critères TR-09 et CA-25 sont verts.
- **Hotwire**      : lecture seule, pas de stream ; raccourcis d'écriture vers le frame `modal`.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teams/feed/index.html.erb` et `content/_feed_header.html.erb`, `_drenas.html.erb`, `_levels.html.erb`, `_activities.html.erb`
  - `⟨ancienne⟩ views/teams/dashboard/setup.html.erb` pour la section Référentiel
  - captures `teams/Team-feed.png`, `teams/Team - DRENA.png`, `teams/Lnclass - Configuration Plateforme.png`
- **Fiches d'inventaire** : TR-09, CA-25. TR-10 hors périmètre (V4).
- **Non-régression** : l'écran lit les vraies tables, pas une constante `Orm` disparue.
- **UDR**          : UDR-0018 — Accueil équipe

---

## Lot B7 — Invitation d'un membre de l'équipe (F-16)

- **Couche**       : domaine (DTO, use cases) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/identity/team_invitation_input.rb`
    - `contact, team_role`.
  - `app/domain/dtos/identity/invitation_acceptance_input.rb`
    - Inclut `PersonNameInput`. `gender, pin, pin_confirmation` (ADR-0038 : nom, prénom(s) et PIN).
  - `app/domain/use_cases/identity/invite_team_member.rb`
    - `InviteTeamPolicy`. Numéro déjà lié à un compte : `:conflict`. Invitation en cours : `:conflict` (index partiel). Jeton de 32 caractères base58, digest HMAC, `expires_at` à +72 h, audit `invitation.sent`. Renvoie l'URL en clair une seule fois.
  - `app/domain/use_cases/identity/accept_invitation.rb`
    - Exempté de policy (ADR-0028). Jeton inconnu : `:not_found` ; expiré, accepté ou révoqué : `:expired`. Dans une transaction : `create_from_invitation`, puis `mark_accepted`, audit `invitation.accepted`. Le compte n'a pas de second facteur : il l'enrôle à sa première connexion.
  - `app/controllers/teams/invitations_controller.rb`
    - `new` (modale), `create`. Succès : stream ; repli HTML : rend `created`. Jamais de flash contenant le lien.
  - `app/controllers/identity/invitations_controller.rb`
    - `allow_unauthenticated_access`, `rate_limit to: 5, within: 1.minute`. `show` et `accept` (422 en cas d'erreur).
  - `app/views/teams/invitations/new.html.erb`
  - `app/views/teams/invitations/_created.html.erb`
    - Lien affiché une fois, dans un champ en lecture seule, avec la consigne « Transmettez ce lien à la personne invitée ; il expire dans 72 h ».
  - `app/views/teams/invitations/create.turbo_stream.erb`
    - Toast « Invitation créée », `turbo_stream.update "modal"` avec `_created` : le lien s'affiche **dans la modale**.
  - `app/views/teams/invitations/created.html.erb`
    - Repli HTML, rend `_created`.
  - `app/views/identity/invitations/show.html.erb`
    - Nom, Prénom(s), genre, PIN et confirmation.
  - `config/locales/teams/invitations.fr.yml`
  - `config/locales/identity/invitations.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/identity/invite_team_member_test.rb`
  - `test/domain/use_cases/identity/accept_invitation_test.rb`
  - `test/controllers/teams/invitations_controller_test.rb`
    - `team_role` content ou field : 403. Turbo Stream, 422, repli HTML.
  - `test/controllers/identity/invitations_controller_test.rb`
    - Lien expiré, lien déjà utilisé, `/team-signup` 404.
  - `test/system/identity/team_invitation_test.rb`
    - `open_in_modal(new_teams_invitation_path)` : numéro invalide (erreur dans la modale), puis numéro valide : le lien apparaît dans la modale, **sans rechargement de page**. Dans une seconde session, le lien est accepté, le TOTP enrôlé, `/teams` atteint.
- **Done quand**   : le critère F-16 est vert ; l'invitation d'amorçage du seed s'accepte par le même écran ; le compte invité enrôle son TOTP puis arrive sur `/teams` ; l'invitation se crée **sans rechargement de page**.
- **Hotwire**      : modale `new` ; 422 dans la modale ; `create.turbo_stream.erb` affiche le lien dans la modale ; repli HTML `created`. Acceptation en Turbo Drive (formulaire public, 422).
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teams/registrations/new.html.erb`, en référence visuelle seulement ; captures `original/team-signup--desktop.png` et `original/team-signup--mobile.png`.
- **Fiches d'inventaire** : ID-04 (écartée, remplacée), F-16.
- **Non-régression** : aucune route publique ne crée un compte team.
- **UDR**          : UDR-0019 — Invitation équipe

---

## Lot B8 — Débloquer un compte (code de récupération, second facteur)

- **Couche**       : domaine (use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/identity/issue_pin_recovery_code.rb`
    - `call(actor:, target_public_id:)`. Faits : la cible, `teaches_target` (classes actives enseignées) ; `IssuePinRecoveryCodePolicy` ; code de 8 chiffres, digest HMAC, +15 min ; audit `pin.recovery_code_issued` avec émetteur et cible. Renvoie le code en clair et son expiration.
  - `app/domain/use_cases/identity/reset_second_factor.rb`
    - `ResetSecondFactorPolicy` ; `second_factors.reset` ; `sessions.destroy_all_for` ; audit `totp.reset`.
  - `app/infrastructure/queries/identity/account_lookup_query.rb`
    - Recherche par numéro **exact** après normalisation → `Row(public_id, display_name, role, team_role, classroom_name, second_factor_confirmed)` ou `nil`. Pas d'annuaire (V2).
  - `app/controllers/teams/account_lookups_controller.rb`
    - `show` avec `?contact=`, sous `ReadUserPolicy` ; rend le frame `account_lookup` seul quand la requête vient de ce frame.
  - `app/controllers/identity/pin_recovery_codes_controller.rb`
    - `allow_roles :team, :teacher`. `rate_limit to: 10, within: 1.minute`. `create` : stream (modale du code) ; repli HTML : `show`. Refus : 403.
  - `app/controllers/teams/second_factor_resets_controller.rb`
    - `create` : stream ; repli HTML : retour à la recherche avec « Second facteur réinitialisé ».
  - `app/views/teams/account_lookups/show.html.erb`
    - Formulaire GET visant `turbo_frame_tag "account_lookup"`, résultat dans le frame.
  - `app/views/teams/account_lookups/_result.html.erb`
    - Identité, rôle, classe ; boutons « Générer un code de récupération » et, pour un compte team, « Réinitialiser le second facteur ».
  - `app/views/identity/pin_recovery_codes/_code.html.erb`
    - Code en grands chiffres, « valable jusqu'à HH:MM », consigne à transmettre oralement.
  - `app/views/identity/pin_recovery_codes/create.turbo_stream.erb`
    - `turbo_stream.update "modal"` avec `ui_modal(open: true)` et `_code` : le code s'affiche **dans une modale**, jamais dans un flash.
  - `app/views/identity/pin_recovery_codes/show.html.erb`
    - Repli HTML, rend `_code`.
  - `app/views/teams/second_factor_resets/create.turbo_stream.erb`
    - Toast, `replace` du résultat de la recherche.
  - `config/locales/teams/account_lookups.fr.yml`
  - `config/locales/identity/pin_recovery_codes.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/identity/issue_pin_recovery_code_test.rb`
  - `test/domain/use_cases/identity/reset_second_factor_test.rb`
  - `test/infrastructure/queries/identity/account_lookup_query_test.rb`
  - `test/controllers/teams/account_lookups_controller_test.rb`
  - `test/controllers/identity/pin_recovery_codes_controller_test.rb`
    - Enseignant sur un élève de sa classe : 200 ; d'une autre classe : 403 ; élève : 403 ; team sur son propre compte : 403. Le code n'apparaît ni dans le flash ni dans le journal.
  - `test/controllers/teams/second_factor_resets_controller_test.rb`
    - Sur soi-même : 403.
  - `test/system/teams/account_unlock_test.rb`
    - Chercher un numéro, générer le code (modale), réinitialiser le second facteur d'un autre membre ; **sans rechargement de page**.
- **Done quand**   : le critère ID-15 (émission) et la réinitialisation du second facteur sont verts, **sans rechargement de page**.
- **Hotwire**      : recherche dans un frame ; un stream ouvre la modale du code ; un stream remplace le résultat après réinitialisation ; repli HTML.
- **Écrans de l'ancienne application** : aucun, la fonction était absente. UDR-0005 et UDR-0006.
- **Fiches d'inventaire** : ID-15, F-07. ADR-0031 et ADR-0032.
- **Non-régression** : un PIN perdu ou un téléphone perdu ne signifie plus un compte perdu.
- **UDR**          : UDR-0020 — Débloquer un compte

---

## Lot C1 — Détail d'un exercice

- **Couche**       : infrastructure (queries) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/assessment/exercise_detail_query.rb`
    - `#call(public_id:, reveal:)` → `Row(exercise, essential, course, questions:)`. **Si `reveal` est faux, la query ne sélectionne même pas la colonne `answers.correct`** : la vue ne peut rien fuiter, même par erreur.
  - `app/infrastructure/queries/assessment/exercise_progress_query.rb`
    - Pour un élève : `badge_level`, `best_score_percent`, `mastery`, `completed_count`, `started_session_public_id`.
  - `app/controllers/assessment/exercises_controller.rb`
    - `show`. `ReadPublishedPolicy` (refus → 404), puis `RevealAnswersPolicy` pour l'aperçu : **vrai pour l'équipe seulement** ; l'élève voit les corrections dans sa session, pas ici. `StartSessionPolicy` décide du bouton.
  - `app/views/assessment/exercises/show.html.erb`
    - Titre, description, nombre de questions, matière. Élève : progression, « Commencer » (POST `exercise_sessions_path`) ou « Reprendre » et « Recommencer » (`restart: true`). Équipe : `content_status_panel` et « Modifier » (modale de B5).
  - `app/views/assessment/exercises/_questions_preview.html.erb`
    - Questions dans `data-controller="math"`. La marque « Proposition correcte » n'est rendue que si `reveal`. **Aucun `cache`** dans ce partial ni dans la vue.
  - `app/views/assessment/exercises/_student_progress.html.erb`
  - `config/locales/assessment/exercises.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/assessment/exercise_detail_query_test.rb`
  - `test/infrastructure/queries/assessment/exercise_progress_query_test.rb`
  - `test/controllers/assessment/exercises_controller_test.rb`
  - `test/integration/assessment/answer_leak_test.rb`
    - TR-cadre-3. Sous `with_fragment_caching`, l'équipe affiche l'exercice, puis l'enseignant, puis l'élève. Le HTML de l'enseignant et de l'élève ne contient ni la marque de proposition correcte ni l'identifiant d'une proposition correcte.
  - `test/system/assessment/exercise_page_test.rb`
    - L'élève voit sa progression et clique « Commencer » : il arrive sur la première question.
- **Done quand**   : les critères AS-02 et AS-39 sont verts.
- **Hotwire**      : lecture seule, pas de stream ; « Commencer » change de page (Turbo Drive) ; « Modifier » vise le frame `modal`.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercises/show.html.erb`, `_questions_list.html.erb` et `_exercise.html.erb`
  - `⟨ancienne⟩ views/components/_question_card.html.erb`
- **Fiches d'inventaire** : AS-02, AS-39. Sécurité n° 29.
- **Non-régression** : aucune proposition correcte servie par un cache partagé entre les rôles.
- **UDR**          : UDR-0021 — Page exercice

---

## Lot C2 — Jouer une session (démarrer, reprendre, répondre, clôturer)

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/assessment/attempt_input.rb`
    - `session_public_id, question_id, answer_ids` (entiers, `compact`). Vide : « Sélectionne au moins une proposition. »
  - `app/domain/use_cases/assessment/start_exercise_session.rb`
    - Tel que dans l'ADR-0054. `StartSessionPolicy`. Session `started` existante : reprise, sauf `restart: true` qui l'abandonne. Sinon `start` avec `question_count` figé, `kind` et `knowledge_gap_id` (remédiation si une lacune `pending` existe sur la fiche, ADR-0043), et `classroom_assignment_id` s'il existe une assignation active.
  - `app/domain/use_cases/assessment/submit_question_attempt.rb`
    - Tel que dans l'ADR-0054. Transaction ; session **verrouillée** ; `SubmitAttemptPolicy` ; question de l'exercice et propositions de la question, sinon `:invalid` ; `Question#well_formed?` puis `correct?` (égalité exacte des ensembles) ; `record_attempt` (`:duplicate` → `:conflict`, rien d'écrit). **À la dernière réponse**, appelle `CloseExerciseSession` injecté, dans la même transaction.
  - `app/domain/use_cases/assessment/close_exercise_session.rb`
    - `correct_count` recalculé depuis les tentatives ; `Grading.score_percent` ; `complete` ; badge par `Grading.badge_for` et `upgrade?` (ADR-0033 : Bronze 50, Argent 70, Or 80, Diamant 100) ; lacune par `GapDecision` (ADR-0043) : `open`, `increment` ou `resolve`. Renvoie `Row(score_percent, badge_level, earned_now)`.
  - `app/infrastructure/queries/assessment/session_play_query.rb`
    - `Row(session_public_id, exercise_title, answered_count, question_count, progress_percent, next_question:, last_feedback:)`. `next_question` : première question sans tentative ; propositions **sans** `correct`, mélangées de façon stable (`Random.new(session_id ^ question_id)`). `last_feedback` : la question qui vient d'être tentée, avec ses propositions correctes et son explication (`RevealAnswersPolicy` : question tentée).
  - `app/controllers/assessment/exercise_sessions_controller.rb`
    - `allow_roles :student`. `create` → `show`. `show` d'une session `completed` → `exercise_session_result_path`.
  - `app/controllers/assessment/question_attempts_controller.rb`
    - `create` : succès → Turbo Stream ; `:invalid` → carte de question re-rendue en 422 dans le frame `question` ; `:conflict` → retour à la session avec « Question déjà répondue ». Repli HTML : `exercise_session_path`.
  - `app/views/assessment/exercise_sessions/show.html.erb`
    - Barre de progression, puis `turbo_frame_tag "question"`.
  - `app/views/assessment/exercise_sessions/_question_card.html.erb`
    - Radios pour `true_false` et `single_choice` ; cases à cocher avec « Plusieurs propositions correctes » pour `multiple_*`. KaTeX.
  - `app/views/assessment/exercise_sessions/_feedback_card.html.erb`
    - « Bonne réponse » ou « Mauvaise réponse », les propositions correctes, l'explication, puis « Question suivante » (recharge le frame `question`) ou « Voir mon résultat ».
  - `app/views/assessment/exercise_sessions/_progress_bar.html.erb`
  - `app/views/assessment/question_attempts/create.turbo_stream.erb`
    - `replace "question"` par la correction, `replace "progress_bar"`.
  - `config/locales/assessment/exercise_sessions.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/assessment/attempt_input_test.rb`
  - `test/domain/use_cases/assessment/start_exercise_session_test.rb`
    - Exercice non assigné : démarrable. Reprise. `restart`. Remédiation.
  - `test/domain/use_cases/assessment/submit_question_attempt_test.rb`
    - Sans crédit partiel ; proposition d'une autre question ; doublon ; clôture automatique à la dernière réponse.
  - `test/domain/use_cases/assessment/close_exercise_session_test.rb`
    - Bornes 49, 50, 69, 70, 79, 80, 99, 100 ; remplacement strictement supérieur ; lacune ouverte, incrémentée, résolue.
  - `test/infrastructure/queries/assessment/session_play_query_test.rb`
    - Ordre stable ; aucun `correct` dans `next_question`.
  - `test/controllers/assessment/exercise_sessions_controller_test.rb`
    - Brouillon : 404. Enseignant : 403.
  - `test/controllers/assessment/question_attempts_controller_test.rb`
    - Réponse vide en Turbo : 422, jamais 500. Session d'un autre élève : 403.
  - `test/integration/assessment/double_submission_test.rb`
    - Deux soumissions concurrentes de la même question : une tentative, `answered_count` = 1 (sécurité n° 30).
  - `test/system/assessment/exercise_session_test.rb`
    - Réponse vide (erreur dans la carte), puis deux réponses, correction après chacune, « Voir mon résultat » : tout dans `assert_no_page_reload` jusqu'au lien de résultat. Même parcours en 390 px.
- **Done quand**   : les critères AS-07, AS-08, AS-09, AS-10 et AS-11 (clôture et badge) sont verts ; on répond à chaque question **sans rechargement de page**.
- **Hotwire**      : frame `question` ; stream `create` (correction et progression) ; 422 dans le frame ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/assessment/exercise_sessions/show.html.erb`, `_question_card.html.erb`, `_feedback_card.html.erb` et `update.turbo_stream.erb`
- **Fiches d'inventaire** : AS-07 à AS-11. Complément assessment §3 et §4 (E-01 à E-25). Sécurité n° 30.
- **Non-régression** : pas de nouvelle soumission après le corrigé ; aucun doublon compté ; aucune session terminée sans score.
- **UDR**          : UDR-0022 — Session d'exercice

---

## Lot C3 — Résultat et badge

- **Couche**       : infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/infrastructure/queries/assessment/session_result_query.rb`
    - `Row(exercise, essential, score_percent, grade_on_20, correct_count, question_count, mastery, badge_level, earned_now, review:)`. `review` : pour chaque question, les propositions choisies et correctes, et l'explication. Le contrôleur applique `ReadSessionPolicy`, puis `RevealAnswersPolicy` : **l'enseignant voit le score et la note, pas les propositions correctes** (ADR-0028).
  - `app/controllers/assessment/session_results_controller.rb`
    - `show`, pour student, teacher et team. Session absente : 404 ; refus : 403 ; session non terminée : retour à la session.
  - `app/views/assessment/session_results/show.html.erb`
    - À partir de 50 % : « Félicitations ! » avec `data-controller="assessment--confetti"` pendant 3 s ; en dessous : « Courage ! ». Note sur 20, pourcentage, maîtrise, badge ou « Non acquis ». « Recommencer » si le score est inférieur à 100. Retour à la fiche essentielle.
  - `app/views/assessment/session_results/_question_review.html.erb`
  - `app/views/assessment/session_results/_badge.html.erb`
    - Bronze, Argent, Or ou Diamant (UDR-0007), avec « Nouveau badge ! » si `earned_now`.
  - `app/javascript/controllers/assessment/confetti_controller.js`
    - CSS et JS locaux, sans bibliothèque, désactivé si `prefers-reduced-motion`.
  - `config/locales/assessment/session_results.fr.yml`
    - Reprend les messages d'encouragement de la locale de gamification de l'ancienne application.
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/assessment/session_result_query_test.rb`
  - `test/controllers/assessment/session_results_controller_test.rb`
    - Autre élève : 403. Enseignant d'une classe active de l'élève : 200, sans proposition correcte dans le HTML. Équipe : 200.
  - `test/system/assessment/session_result_test.rb`
    - 10/10 : « Diamant » et « Nouveau badge ! » ; 9/10 : « Or » ; « Recommencer » ouvre une nouvelle session.
- **Done quand**   : les critères AS-11 (affichage), AS-12 et AS-13 sont verts.
- **Hotwire**      : lecture seule, pas de stream ; « Recommencer » change de page ; Stimulus pour les confettis seulement.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/assessment/exercise_sessions/result.html.erb` et `finish.turbo_stream.erb`
  - `⟨ancienne⟩ views/components/_exercise_badge.html.erb`
  - `⟨ancienne⟩ javascript/controllers/confetti_controller.js`
- **Fiches d'inventaire** : AS-11, AS-12, AS-13. ADR-0033 et ADR-0054.
- **Non-régression** : le badge gagné est affiché ; le résultat montre la note et le badge, pas seulement le pourcentage ; 9/10 donne Or, jamais Diamant.
- **UDR**          : UDR-0023 — Résultat de session

---

## Lot D1 — Inscription enseignant

- **Couche**       : domaine (DTO, use case) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/domain/dtos/identity/teacher_registration_input.rb`
    - Inclut `PersonNameInput`. `gender, contact, pin, pin_confirmation, drena_public_id, school_public_id, material_slug`.
  - `app/domain/use_cases/identity/register_teacher.rb`
    - `RegisterTeacherPolicy` ; faits : école active de la DRENA, matière ; transaction : `create_teacher` (profil avec matière, `onboarding_completed_at` nul), `schools.attach_teacher(primary: true)` (ADR-0030). Rôle imposé à `teacher`.
  - `app/controllers/identity/teacher_registrations_controller.rb`
    - `allow_unauthenticated_access`, `rate_limit to: 5, within: 1.minute, only: :create`. Succès : `start_session`, puis `teacher_classrooms_path` avec « Bienvenue ! Sélectionnez vos classes pour commencer. ». Échec : 422.
  - `app/controllers/school/drena_schools_controller.rb`
    - `allow_unauthenticated_access`, `rate_limit to: 30, within: 1.minute`. `index` par `SchoolOptionsQuery#schools_for` : HTML = le frame `schools` (liste déroulante des établissements actifs) ; JSON = `[{ public_id, name }]` (SC-26). DRENA inconnue : 404.
  - `app/views/identity/teacher_registrations/new.html.erb`
  - `app/views/identity/teacher_registrations/_form.html.erb`
    - Nom, Prénom(s), genre, numéro, PIN et confirmation, DRENA (filtre non persisté), `turbo_frame_tag "schools"`, matière. Sans JS, « Afficher les établissements » soumet en GET avec la DRENA.
  - `app/views/school/drena_schools/index.html.erb`
  - `app/javascript/controllers/school/drena_schools_controller.js`
    - Au changement de DRENA, pose `src` du frame `schools` : Turbo ne sait pas lier un `<select>` à un frame sans cette ligne.
  - `config/locales/identity/teacher_registrations.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/identity/teacher_registration_input_test.rb`
  - `test/domain/use_cases/identity/register_teacher_test.rb`
    - École hors de la DRENA ou inactive ; rôle forcé ; atomicité.
  - `test/controllers/identity/teacher_registrations_controller_test.rb`
    - TR-cadre-1, variante `role=team`.
  - `test/controllers/school/drena_schools_controller_test.rb`
    - HTML et JSON ; école inactive absente ; 429.
  - `test/system/identity/teacher_signup_test.rb`
    - Choisir une DRENA : les établissements apparaissent **sans rechargement de page** ; PIN non confirmé : erreurs sans rechargement ; inscription juste : arrivée sur `/teachers/classrooms`.
- **Done quand**   : les critères ID-03, ID-08, SC-26 et SC-27 sont verts ; la liste des établissements se recharge **sans rechargement de page**.
- **Hotwire**      : frame `schools` rechargé par la DRENA ; formulaire en Turbo Drive, 422. Pas de stream : le succès change de page.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/registrations/new.html.erb`
  - `⟨ancienne⟩ javascript/controllers/schools_controller.js`
  - captures `original/teacher-signup--desktop.png`, `original/teacher-signup--mobile.png`
- **Fiches d'inventaire** : ID-03, ID-08, SC-26, SC-27, TR-17 (formulaire « Prepa BAC » écarté).
- **Non-régression** : l'endpoint public est limité en débit et ne liste que les écoles actives.
- **UDR**          : UDR-0024 — Inscription enseignant

---

## Lot D2 — Déclarer ses classes (onboarding persisté)

- **Couche**       : domaine (use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/use_cases/classroom/declare_teaching.rb`
    - `DeclareTeachingPolicy` (même école, classe active) ; `teaching.declare`. Idempotent.
  - `app/domain/use_cases/classroom/withdraw_teaching.rb`
    - Même policy ; `teaching.withdraw`. N'efface ni assignation ni session.
  - `app/domain/use_cases/identity/complete_teacher_onboarding.rb`
    - Teacher ; au moins une classe déclarée, sinon `:invalid` (« Sélectionnez au moins une classe. ») ; `complete_onboarding`.
  - `app/infrastructure/queries/classroom/teaching_selection_query.rb`
    - Classes actives de l'école principale et de l'année en cours, groupées par niveau, triées par position puis nom ; chacune porte `declared`.
  - `app/controllers/classroom/teaching_selections_controller.rb`
    - `allow_roles :teacher`. `index`. Sans école principale : `pending_account_path`.
  - `app/controllers/classroom/teachings_controller.rb`
    - `create` et `destroy`, en Turbo Stream ; repli HTML : retour à la liste.
  - `app/controllers/classroom/teacher_onboardings_controller.rb`
    - `create` → `teacher_home_path` ; aucune classe : erreur en 422.
  - `app/views/classroom/teaching_selections/index.html.erb`
    - « Quelles classes enseignez-vous ? », compteur `#teaching_counter`, bouton « Terminer la configuration » tant que l'onboarding n'est pas fini.
  - `app/views/classroom/teaching_selections/_level_group.html.erb`
  - `app/views/classroom/teachings/_toggle.html.erb`
  - `app/views/classroom/teachings/_counter.html.erb`
  - `app/views/classroom/teachings/create.turbo_stream.erb`
    - `replace` de la bascule et du compteur.
  - `app/views/classroom/teachings/destroy.turbo_stream.erb`
  - `config/locales/classroom/teaching_selections.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/classroom/declare_teaching_test.rb`
    - Classe d'une autre école : 403 ; classe archivée : 403.
  - `test/domain/use_cases/classroom/withdraw_teaching_test.rb`
  - `test/domain/use_cases/identity/complete_teacher_onboarding_test.rb`
  - `test/infrastructure/queries/classroom/teaching_selection_query_test.rb`
  - `test/controllers/classroom/teachings_controller_test.rb`
  - `test/controllers/classroom/teaching_selections_controller_test.rb`
  - `test/system/classroom/teaching_selection_test.rb`
    - Cocher trois classes, en décocher une : bascules et compteur à jour **sans rechargement de page** ; « Terminer » mène à l'accueil enseignant.
- **Done quand**   : les critères CL-09 et TR-08 (remplacé) sont verts ; un enseignant onboardé n'est plus renvoyé sur cette page ; la déclaration se fait **sans rechargement de page**.
- **Hotwire**      : streams `create` et `destroy` (bascule et compteur) ; aucun Stimulus (le compteur de l'ancienne application est remplacé par le stream).
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/classrooms/index.html.erb` et `_classroom_group.html.erb`
  - `⟨ancienne⟩ javascript/controllers/classroom_selection_controller.js` et `checkable_controller.js`
  - `⟨ancienne⟩ views/teachers/dashboard/setup.html.erb` sert de contre-exemple (TR-08, écarté).
- **Fiches d'inventaire** : CL-09, TR-08, TR-02 (enseignant sans école).
- **Non-régression** : l'onboarding n'est pas déduit de `classrooms.empty?` ; pas de boucle de redirection.
- **UDR**          : UDR-0025 — Déclaration des classes

---

## Lot D3 — Accueil enseignant

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/teacher_home_query.rb`
    - `Row(school_name, material_name, material_category, classrooms: [Row(public_id, name, level_name, active_students_count, active_assignments_count, average_score_percent)])`.
  - `app/controllers/classroom/teacher_homes_controller.rb`
    - `allow_roles :teacher`. Onboarding non fini : `redirect_to_home`.
  - `app/views/classroom/teacher_homes/show.html.erb`
    - Sections de `HOME_SECTIONS[:teacher]` ; « activité » en `ui_empty_state` « Bientôt » (V3), sans lien mort.
  - `app/views/classroom/teacher_homes/_classroom_card.html.erb`
  - `config/locales/classroom/teacher_homes.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/infrastructure/queries/classroom/teacher_home_query_test.rb`
  - `test/controllers/classroom/teacher_homes_controller_test.rb`
  - `test/system/classroom/teacher_home_test.rb`
    - L'enseignant voit ses classes et ouvre l'une d'elles.
- **Done quand**   : le critère TR-05 est vert.
- **Hotwire**      : lecture seule, pas de stream.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teachers/feed/index.html.erb` et `content/_feed_header.html.erb`, `_classrooms.html.erb`, `_levels.html.erb` ; `_examen_dashboard.html.erb` écarté (TR-06).
- **Fiches d'inventaire** : TR-05, TR-06 (écarté), TR-07 (écarté).
- **Non-régression** : aucun montant « Prepa » affiché.
- **UDR**          : UDR-0026 — Accueil enseignant

---

## Lot D4 — Page d'une classe (enseignant, équipe)

- **Couche**       : infrastructure (query) + delivery + ui (Stimulus)
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/classroom_overview_query.rb`
    - Cours assignés actifs et publiés, avec `classroom_course_path` ; puis, **seulement si `show_roster`**, les élèves (`public_id, display_name, contact, last_score_percent`).
  - `app/controllers/classroom/classrooms_controller.rb`
    - `allow_roles :teacher, :team`. En-tête par `ClassroomHeaderQuery` ; `ReadClassroomPolicy`. Un élève reçoit 403 : il n'a pas accès à cette page, ni au code.
  - `app/views/classroom/classrooms/show.html.erb`
  - `app/views/classroom/classrooms/_header.html.erb`
    - Nom, année scolaire, code en majuscules et bouton « Copier » ; effectif / plafond.
  - `app/views/classroom/classrooms/_assigned_courses.html.erb`
  - `app/views/classroom/classrooms/_roster.html.erb`
    - Une ligne par élève, bouton « Générer un code de récupération » (`button_to` POST vers `account_pin_recovery_codes_path` ; la réponse est le stream de B8, qui ouvre la modale du code).
  - `app/javascript/controllers/classroom/join_code_copy_controller.js`
    - Copie dans le presse-papiers : Turbo ne le fait pas.
  - `config/locales/classroom/classrooms.fr.yml`
- **Dépend de**    : socle. **Aucune dépendance de code à B8** : le bouton vise une route du socle ; le parcours complet est prouvé au Lot E.
- **Test associé** :
  - `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
  - `test/controllers/classroom/classrooms_controller_test.rb`
    - Élève : 403.
  - `test/integration/classroom/foreign_teacher_access_test.rb`
    - TR-cadre-4 : 403, sans code ni nom d'élève dans le corps.
  - `test/system/classroom/classroom_page_test.rb`
    - L'enseignant voit le code, le copie (message « Code copié »), voit la liste de ses élèves.
- **Done quand**   : les critères CL-10 et CL-04 (affichage) sont verts.
- **Hotwire**      : lecture seule, pas de stream propre ; Stimulus pour la copie ; le bouton du code de récupération reçoit le stream de B8.
- **Écrans de l'ancienne application** :
  - `⟨ancienne⟩ views/teachers/classrooms/show.html.erb`, `_student_row.html.erb`, `_course_assigned.html.erb`
  - `⟨ancienne⟩ views/classroom/classrooms/show.html.erb` et `_student.html.erb`
  - `⟨ancienne⟩ javascript/controllers/clipboard_controller.js`
  - capture `teams/Lnclass - Classe _ 6ème 1.png`
- **Fiches d'inventaire** : CL-10, CL-04, ID-15 (émission par l'enseignant).
- **Non-régression** : la fiche de classe ne casse plus au premier exercice assigné ; aucune donnée servie à un enseignant hors de la classe.
- **UDR**          : UDR-0027 — Page classe

---

## Lot D5 — Assignation, et cours dans la classe

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/classroom/assignment_input.rb`
    - `classroom_public_id, assignable_type, assignable_key`. Type dans `Assignable::TYPES`.
  - `app/domain/use_cases/classroom/assign_resource.rb`
    - DTO ; classe ; `resolve_assignable` (absent ou non publié : `:not_found`) ; `AssignPolicy` ; déjà actif : **`:conflict`** (« Déjà assigné à cette classe ») ; sinon `create` d'une **nouvelle ligne**, `assigned_by_id = actor.user_id` (ADR-0048).
  - `app/domain/use_cases/classroom/archive_assignment.rb`
    - `AssignPolicy` ; `archive` : la ligne n'est jamais supprimée.
  - `app/infrastructure/queries/classroom/classroom_course_query.rb`
    - La classe, le cours, ses fiches publiées, avec l'assignation active éventuelle du cours et de chaque fiche.
  - `app/controllers/classroom/assignments_controller.rb`
    - `create` et `archive`, **toujours en Turbo Stream** (jamais 204) ; en HTML, redirection vers l'origine.
  - `app/controllers/classroom/classroom_courses_controller.rb`
    - `show`, sous `ReadClassroomPolicy` avec `ClassroomHeaderQuery`.
  - `app/views/classroom/assignments/_toggle.html.erb`
    - « Assigner », ou « Assigné » avec l'action « Retirer ». `id` = `"assignment_#{classroom_public_id}_#{type}_#{key}"`. **Réutilisé par D6 et D7.**
  - `app/views/classroom/assignments/create.turbo_stream.erb`
    - Toast « Assigné à la classe », `replace` de la bascule.
  - `app/views/classroom/assignments/archive.turbo_stream.erb`
    - Toast « Retiré de la classe », `replace` de la bascule. `:conflict` : toast d'erreur, statut 422.
  - `app/views/classroom/classroom_courses/show.html.erb`
  - `config/locales/classroom/assignments.fr.yml`
  - `config/locales/classroom/classroom_courses.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/classroom/assignment_input_test.rb`
  - `test/domain/use_cases/classroom/assign_resource_test.rb`
    - Assigner ; déjà actif → `:conflict` ; réassigner après retrait → nouvelle ligne ; non publié ; classe non enseignée ; classe archivée.
  - `test/domain/use_cases/classroom/archive_assignment_test.rb`
  - `test/infrastructure/queries/classroom/classroom_course_query_test.rb`
  - `test/controllers/classroom/assignments_controller_test.rb`
    - `text/vnd.turbo-stream.html` ; autre classe : 403 ; trois types de ressource.
  - `test/controllers/classroom/classroom_courses_controller_test.rb`
  - `test/system/classroom/assignment_toggle_test.rb`
    - Assigner le cours, puis une fiche, retirer, réassigner : bascules et toasts **sans rechargement de page**.
- **Done quand**   : les critères CL-11, CL-16, CL-17, CL-20, AS-18 et AS-19 sont verts ; assigner et retirer se font **sans rechargement de page**.
- **Hotwire**      : streams `create` et `archive` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teachers/classrooms/course.html.erb`, `⟨ancienne⟩ views/classroom/classrooms/_classroom_essential.html.erb` et `_classroom_exercise.html.erb`
- **Fiches d'inventaire** : CL-11, CL-16, CL-17, CL-20, AS-18, AS-19. Chantier `classroom-assignment-belongs-to-casses`.
- **Non-régression** : pas de `RecordNotUnique` à la réassignation ; pas de 204 ; `assigned_by_id` n'est jamais un identifiant de profil.
- **UDR**          : UDR-0028 — Cours dans la classe et bascule d'assignation

---

## Lot D6 — Fiche essentielle dans la classe

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/classroom_essential_query.rb`
    - La classe, la fiche, ses exercices publiés avec l'assignation active et `questions_count`, et le taux de réussite de la classe par exercice.
  - `app/controllers/classroom/classroom_essentials_controller.rb`
  - `app/views/classroom/classroom_essentials/show.html.erb`
    - Rend la bascule de D5 pour chaque exercice.
  - `config/locales/classroom/classroom_essentials.fr.yml`
- **Dépend de**    : socle et **Lot D5** (partial de bascule, streams d'assignation)
- **Test associé** :
  - `test/infrastructure/queries/classroom/classroom_essential_query_test.rb`
  - `test/controllers/classroom/classroom_essentials_controller_test.rb`
  - `test/system/classroom/classroom_essential_test.rb`
    - Assigner puis retirer un exercice **sans rechargement de page**.
- **Done quand**   : les critères CL-12 et AS-20 sont verts ; l'assignation d'un exercice se fait **sans rechargement de page**.
- **Hotwire**      : pas de stream propre ; les streams de D5 remplacent les bascules de cette page.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teachers/classrooms/essential.html.erb`
- **Fiches d'inventaire** : CL-12, AS-20.
- **Non-régression** : aucun exercice non publié proposé à l'assignation.
- **UDR**          : UDR-0029 — Fiche essentielle dans la classe

---

## Lot D7 — Assigner un cours depuis sa page (CA-27)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/infrastructure/queries/classroom/course_assignment_targets_query.rb`
    - Les classes actives enseignées par l'enseignant connecté, avec l'assignation active de ce cours.
  - `app/controllers/classroom/course_assignments_controller.rb`
    - `allow_roles :teacher`. `index`. Cours non publié : 404.
  - `app/views/classroom/course_assignments/index.html.erb`
    - Une ligne par classe, avec la bascule de D5.
  - `config/locales/classroom/course_assignments.fr.yml`
- **Dépend de**    : socle et **Lot D5**
- **Test associé** :
  - `test/infrastructure/queries/classroom/course_assignment_targets_query_test.rb`
  - `test/controllers/classroom/course_assignments_controller_test.rb`
  - `test/system/classroom/course_assignments_test.rb`
    - Assigner le cours à deux classes **sans rechargement de page**.
- **Done quand**   : le critère CA-27 est vert, **sans rechargement de page**.
- **Hotwire**      : comme D6.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/courses/show.html.erb`, partie d'assignation dont le bouton était inatteignable.
- **Fiches d'inventaire** : CA-27.
- **Non-régression** : le bouton n'est plus inatteignable.
- **UDR**          : UDR-0030 — Assigner un cours

---

## Lot D8 — Créer une classe dans un établissement (équipe)

- **Couche**       : domaine (DTO, use case) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/classroom/classroom_input.rb`
    - `school_public_id, level_slug, series_slug, name, max_students`. `name` : 15 au plus ; `max_students` entre 1 et 150, 80 par défaut.
  - `app/domain/use_cases/classroom/create_classroom.rb`
    - `ManageClassroomPolicy` ; école active ; niveau ; `lookup.pair?` ; `school_year = SchoolYear.current` ; `classrooms.create` (code unique tiré par le repository). Nom pris dans l'école et l'année : `:conflict`.
  - `app/controllers/teams/school_classrooms_controller.rb`
    - `new` (modale), `create` sous `schools/:school_public_id`. Échec : 422. Repli HTML : `classroom_path`.
  - `app/views/teams/school_classrooms/new.html.erb`
  - `app/views/teams/school_classrooms/_form.html.erb`
    - `form_with id: "classroom-form"`. Niveau, série (options filtrées par niveau côté serveur), nom, plafond.
  - `app/views/teams/school_classrooms/create.turbo_stream.erb`
    - Toast « Classe créée. Code : KFM37 », modale refermée, refresh de la fiche établissement (S2).
  - `config/locales/teams/school_classrooms.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/classroom/classroom_input_test.rb`
  - `test/domain/use_cases/classroom/create_classroom_test.rb`
    - Nom pris, série incompatible, école inactive, non-équipe.
  - `test/controllers/teams/school_classrooms_controller_test.rb`
  - `test/system/teams/school_classroom_creation_test.rb`
    - `open_in_modal(new_school_classroom_path(school))` : nom pris (erreur dans la modale), puis création : toast avec le code, **sans rechargement de page**.
- **Done quand**   : les critères CL-01 et CL-04 (génération) sont verts ; la classe se crée **sans rechargement de page**.
- **Hotwire**      : modale ; 422 ; `create.turbo_stream.erb` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/classroom/classrooms/new.html.erb` et `_form.html.erb` ; capture `teams/team-school-id-school.png`
- **Fiches d'inventaire** : CL-01, CL-04.
- **Non-régression** : le code ne dépasse pas la colonne ; un rôle non autorisé reçoit 403, pas 500.
- **UDR**          : UDR-0031 — Création de classe

---

## Lot R1 — Niveaux (référentiel, équipe)

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/catalog/level_input.rb`
    - `name` (20 au plus), `position`, `cycle` ∈ `Level::CYCLES`.
  - `app/domain/use_cases/catalog/create_level.rb`
    - `ManageTaxonomyPolicy` ; `Level` valide ; `create_level` (nom ou position pris : `:conflict`) ; le slug, dérivé du nom et figé, sert de code à la génération des classes ; audit `taxonomy.changed`.
  - `app/domain/use_cases/catalog/update_level.rb`
    - Nom, position, cycle. Le slug ne change jamais (ADR-0029).
  - `app/domain/use_cases/catalog/delete_level.rb`
    - Référencé par une série liée, une classe ou un cours : `:conflict` (ADR-0034, ADR-0036).
  - `app/infrastructure/queries/catalog/levels_query.rb`
    - `[Row(slug, name, position, cycle, series_names, classrooms_count, courses_count)]`, par position.
  - `app/controllers/teams/levels_controller.rb`
    - `index`, `new`, `create`, `edit`, `update`, `destroy`.
  - `app/views/teams/levels/index.html.erb`
    - Tableau `#levels` ; « Nouveau niveau » en `data-turbo-frame="modal"`.
  - `app/views/teams/levels/_level_row.html.erb`
    - `id` = `dom_id` du niveau (par slug) ; « Modifier » (modale), « Supprimer » (`button_to` DELETE, confirmation intégrée à la page).
  - `app/views/teams/levels/_form.html.erb`
  - `app/views/teams/levels/new.html.erb`
  - `app/views/teams/levels/edit.html.erb`
  - `app/views/teams/levels/create.turbo_stream.erb`
    - Toast, modale refermée, `replace "levels"` (le tableau suit l'ordre des positions).
  - `app/views/teams/levels/update.turbo_stream.erb`
  - `app/views/teams/levels/destroy.turbo_stream.erb`
    - Succès : toast et `remove` de la ligne. Refus (`:conflict`) : toast « Ce niveau est utilisé », ligne conservée, statut 422.
  - `config/locales/teams/levels.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/catalog/level_input_test.rb`
  - `test/domain/use_cases/catalog/create_level_test.rb`
  - `test/domain/use_cases/catalog/update_level_test.rb`
    - Renommer ne change pas le slug.
  - `test/domain/use_cases/catalog/delete_level_test.rb`
  - `test/infrastructure/queries/catalog/levels_query_test.rb`
  - `test/controllers/teams/levels_controller_test.rb`
    - Non-équipe : 403 ; Turbo Stream sur les trois écritures ; 422 ; repli HTML.
  - `test/system/teams/levels_test.rb`
    - Créer, renommer, supprimer un niveau vierge, échouer à supprimer un niveau utilisé : tout **sans rechargement de page**.
- **Done quand**   : les critères CA-16 et CA-18 sont verts ; le CRUD se fait **sans rechargement de page**.
- **Hotwire**      : modales `new` et `edit` ; 422 ; `create`, `update`, `destroy` en `*.turbo_stream.erb` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teams/dashboard/setup/_levels.html.erb`, `⟨ancienne⟩ views/catalog/levels/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb`
- **Fiches d'inventaire** : CA-16, CA-18, CA-25. CA-17 (page publique de niveau) hors périmètre.
- **Non-régression** : aucune suppression en cascade ; le slug d'un niveau, dont dépendent la génération des classes et les imports, ne change jamais.
- **UDR**          : UDR-0032 — Gestion des niveaux

---

## Lot R2 — Séries et association aux niveaux

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/catalog/series_input.rb`
    - `name` (10 au plus).
  - `app/domain/use_cases/catalog/create_series.rb`
  - `app/domain/use_cases/catalog/update_series.rb`
    - Slug figé.
  - `app/domain/use_cases/catalog/delete_series.rb`
    - Liée à un niveau, ou utilisée par une classe ou un cours : `:conflict`.
  - `app/domain/use_cases/catalog/link_level_series.rb`
    - `ManageTaxonomyPolicy` ; `link` ; audit `taxonomy.changed`.
  - `app/domain/use_cases/catalog/unlink_level_series.rb`
    - Une classe ou un cours utilise le couple : `:conflict`.
  - `app/infrastructure/queries/catalog/series_query.rb`
    - `[Row(slug, name, level_names, classrooms_count, courses_count)]`, et la matrice niveau × série pour l'écran d'association.
  - `app/controllers/teams/series_controller.rb`
    - `index`, `new`, `create`, `edit`, `update`, `destroy`.
  - `app/controllers/teams/level_series_controller.rb`
    - `create` et `destroy`.
  - `app/views/teams/series/index.html.erb`
    - Tableau `#series`, puis la matrice niveaux × séries `#level_series_matrix`, une case par couple.
  - `app/views/teams/series/_series_row.html.erb`
  - `app/views/teams/series/_form.html.erb`
  - `app/views/teams/series/new.html.erb`
  - `app/views/teams/series/edit.html.erb`
  - `app/views/teams/series/create.turbo_stream.erb`
    - Toast, modale refermée, `append "series"`, `replace "level_series_matrix"` (nouvelle colonne).
  - `app/views/teams/series/update.turbo_stream.erb`
  - `app/views/teams/series/destroy.turbo_stream.erb`
  - `app/views/teams/level_series/_cell.html.erb`
  - `app/views/teams/level_series/create.turbo_stream.erb`
    - `replace` de la case, toast.
  - `app/views/teams/level_series/destroy.turbo_stream.erb`
    - `replace` de la case ; refus : toast d'erreur, statut 422.
  - `config/locales/teams/series.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/catalog/series_input_test.rb`
  - `test/domain/use_cases/catalog/create_series_test.rb`
  - `test/domain/use_cases/catalog/update_series_test.rb`
  - `test/domain/use_cases/catalog/delete_series_test.rb`
  - `test/domain/use_cases/catalog/link_level_series_test.rb`
  - `test/domain/use_cases/catalog/unlink_level_series_test.rb`
  - `test/infrastructure/queries/catalog/series_query_test.rb`
  - `test/controllers/teams/series_controller_test.rb`
  - `test/controllers/teams/level_series_controller_test.rb`
  - `test/system/teams/series_test.rb`
    - Créer une série, la lier à la Tle, tenter de délier un couple utilisé : **sans rechargement de page**.
- **Done quand**   : les critères CA-19 et CA-24 sont verts ; CRUD et association **sans rechargement de page**.
- **Hotwire**      : modales ; 422 ; streams `create`, `update`, `destroy` des séries et des couples ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teams/dashboard/setup/_series.html.erb`, `⟨ancienne⟩ views/catalog/series/index.html.erb`, `_form.html.erb`
- **Fiches d'inventaire** : CA-19, CA-24, CA-25. CA-23 hors périmètre.
- **Non-régression** : dissocier un couple utilisé est refusé, jamais silencieux.
- **UDR**          : UDR-0033 — Gestion des séries

---

## Lot R3 — Matières

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/catalog/material_input.rb`
    - `name` (40), `shortname` (10), `category` ∈ `Material::CATEGORIES`, **obligatoire**.
  - `app/domain/use_cases/catalog/create_material.rb`
  - `app/domain/use_cases/catalog/update_material.rb`
    - Slug figé ; nom, abrégé et catégorie modifiables.
  - `app/domain/use_cases/catalog/delete_material.rb`
    - Référencée par un cours ou un profil enseignant : `:conflict`.
  - `app/infrastructure/queries/catalog/materials_query.rb`
    - `[Row(slug, name, shortname, category, courses_count, teachers_count)]`, par nom.
  - `app/controllers/teams/materials_controller.rb`
  - `app/views/teams/materials/index.html.erb`
    - Tableau `#materials` ; chaque ligne rend `ui_subject_badge(name, category:)` : l'équipe voit la couleur et l'icône de la catégorie.
  - `app/views/teams/materials/_material_row.html.erb`
  - `app/views/teams/materials/_form.html.erb`
    - Catégorie en radios « Lettres », « Sciences », « Autre », avec l'aperçu du badge.
  - `app/views/teams/materials/new.html.erb`
  - `app/views/teams/materials/edit.html.erb`
  - `app/views/teams/materials/create.turbo_stream.erb`
  - `app/views/teams/materials/update.turbo_stream.erb`
  - `app/views/teams/materials/destroy.turbo_stream.erb`
  - `config/locales/teams/materials.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/catalog/material_input_test.rb`
  - `test/domain/use_cases/catalog/create_material_test.rb`
  - `test/domain/use_cases/catalog/update_material_test.rb`
    - Changer la catégorie change le ton ; renommer ne le change pas.
  - `test/domain/use_cases/catalog/delete_material_test.rb`
  - `test/infrastructure/queries/catalog/materials_query_test.rb`
  - `test/controllers/teams/materials_controller_test.rb`
  - `test/system/teams/materials_test.rb`
    - Créer une matière sans catégorie (erreur dans la modale), puis avec ; changer sa catégorie : le badge de la ligne change **sans rechargement de page**.
- **Done quand**   : les critères CA-20, CA-22 et CA-26 (catégorie saisie) sont verts ; le CRUD se fait **sans rechargement de page**.
- **Hotwire**      : modales ; 422 ; streams `create`, `update`, `destroy` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teams/dashboard/setup/_materials.html.erb`, `⟨ancienne⟩ views/catalog/materials/index.html.erb`, `_form.html.erb`
- **Fiches d'inventaire** : CA-20, CA-22, CA-25, CA-26. CA-21 hors périmètre.
- **Non-régression** : une matière sans catégorie est impossible ; la couleur ne se déduit jamais du nom.
- **UDR**          : UDR-0034 — Gestion des matières

---

## Lot S1 — DRENA : gestion

- **Couche**       : domaine (DTO, use cases) + infrastructure (query) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/school/drena_input.rb`
    - `name` (80 au plus, `squish`).
  - `app/domain/use_cases/school/create_drena.rb`
    - `ManageSchoolPolicy` ; `drenas.create` (nom pris : `:conflict`) ; slug figé : c'est la cible des imports d'établissements ; audit `school.changed`.
  - `app/domain/use_cases/school/update_drena.rb`
    - Le nom change, pas le slug.
  - `app/domain/use_cases/school/delete_drena.rb`
    - Avec des établissements : `:conflict` (ADR-0036).
  - `app/infrastructure/queries/school/drenas_query.rb`
    - `[Row(public_id, slug, name, schools_count, classrooms_count)]`, par nom.
  - `app/controllers/teams/drenas_controller.rb`
    - `index`, `new`, `create`, `edit`, `update`, `destroy`.
  - `app/views/teams/drenas/index.html.erb`
    - Tableau `#drenas`, le slug affiché (« à utiliser dans les fichiers d'import »).
  - `app/views/teams/drenas/_drena_row.html.erb`
  - `app/views/teams/drenas/_form.html.erb`
  - `app/views/teams/drenas/new.html.erb`
  - `app/views/teams/drenas/edit.html.erb`
  - `app/views/teams/drenas/create.turbo_stream.erb`
  - `app/views/teams/drenas/update.turbo_stream.erb`
  - `app/views/teams/drenas/destroy.turbo_stream.erb`
  - `config/locales/teams/drenas.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/school/drena_input_test.rb`
  - `test/domain/use_cases/school/create_drena_test.rb`
  - `test/domain/use_cases/school/update_drena_test.rb`
    - Renommer ne change pas le slug.
  - `test/domain/use_cases/school/delete_drena_test.rb`
  - `test/infrastructure/queries/school/drenas_query_test.rb`
  - `test/controllers/teams/drenas_controller_test.rb`
    - Non-équipe : 403 ; Turbo Stream ; 422 ; repli HTML.
  - `test/system/teams/drenas_test.rb`
    - Créer, renommer, échouer à supprimer une DRENA qui a des établissements : **sans rechargement de page**.
- **Done quand**   : le critère SC-01 est vert ; la production démarre **sans aucune DRENA** et l'équipe les crée à l'écran ; le CRUD se fait **sans rechargement de page**. (SC-02, l'import de DRENA, est écartée par le porteur.)
- **Hotwire**      : modales ; 422 ; streams `create`, `update`, `destroy` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/teams/dashboard/setup/_drenas.html.erb`, `⟨ancienne⟩ views/catalog/drenas/index.html.erb`, `_form.html.erb`
- **Fiches d'inventaire** : SC-01. SC-02 écartée.
- **Non-régression** : aucune suppression en cascade ; le slug d'une DRENA ne change jamais.
- **UDR**          : UDR-0035 — Gestion des DRENA

---

## Lot S2 — Établissements : création avec classes, liste nationale, fiche

- **Couche**       : domaine (DTO, use cases) + infrastructure (queries) + delivery + ui
- **Fichiers**     :
  - `app/domain/dtos/school/school_input.rb`
    - `drena_public_id, name` (150), `sigle` (20), `school_type` ∈ `SCHOOL_TYPES` (Public, Privé, Mixte), `status` ∈ `STATUSES` (défaut `active`), `cycle` ∈ `CYCLES` (proposé par `School.cycle_for(name:)`, modifiable par l'équipe).
  - `app/domain/use_cases/school/create_school.rb`
    - `ManageSchoolPolicy` ; DRENA ; dans **une transaction** : `schools.create` (nom pris dans la DRENA : `:conflict`), puis `DefaultClassroomPlan.rows_for(school:, lookup: taxonomy.lookup)`, puis codes tirés par `JoinCode.generate_unique` contre `taken_join_codes`, puis `classrooms.insert_generated` pour `SchoolYear.current`, `max_students` 80 (ADR-0030). Audit `school.changed`. Renvoie l'école, le nombre de classes créées et les niveaux ou séries sautés. **Aucun élève de démonstration.**
  - `app/domain/use_cases/school/update_school.rb`
    - Nom, sigle, DRENA, type, statut, cycle. Ne régénère **jamais** les classes.
  - `app/domain/use_cases/school/deactivate_school.rb`
    - `status = inactive` : l'école disparaît de l'inscription enseignant et de la création de classe ; rien n'est supprimé.
  - `app/domain/use_cases/school/delete_school.rb`
    - `delete_if_unreferenced` ; référencée (élève, enseignant, assignation) : `:conflict` avec « Désactivez plutôt cet établissement » (ADR-0036).
  - `app/infrastructure/queries/school/schools_query.rb`
    - Liste nationale (SC-04) : filtres DRENA, type, cycle, statut, recherche sur le nom ; pagination par `page` (50 par page, compteur total) ; `[Row(public_id, name, sigle, drena_name, school_type, cycle, status, classrooms_count, teachers_count)]`.
  - `app/infrastructure/queries/school/school_detail_query.rb`
    - Fiche (SC-05) : l'école, ses classes de l'année courante groupées par niveau (nom, code affiché, effectif, enseignants), ses enseignants.
  - `app/controllers/teams/schools_controller.rb`
    - `index` (frame `schools` seul quand la requête vient du frame), `show`, `new`, `create`, `edit`, `update`, `deactivate`, `destroy`.
  - `app/views/teams/schools/index.html.erb`
    - Filtres visant `turbo_frame_tag "schools"` (`data-turbo-action="advance"`), `ui_pagination`. Boutons « Nouvel établissement » et « Importer des établissements » (`new_teams_import_path(kind: "schools")`), en `data-turbo-frame="modal"`.
  - `app/views/teams/schools/_filters.html.erb`
  - `app/views/teams/schools/_school_row.html.erb`
  - `app/views/teams/schools/show.html.erb`
    - En-tête `#school_header` (nom, sigle, type, cycle, statut), « Ajouter une classe » (`new_school_classroom_path`, modale de D8), « Modifier », « Désactiver ».
  - `app/views/teams/schools/_header.html.erb`
  - `app/views/teams/schools/_classroom_group.html.erb`
  - `app/views/teams/schools/_form.html.erb`
    - `form_with id: "school-form"`. Le cycle est pré-rempli selon le nom ; une aide explique qu'une école « collège » ne reçoit que le premier cycle.
  - `app/views/teams/schools/new.html.erb`
  - `app/views/teams/schools/edit.html.erb`
  - `app/views/teams/schools/create.turbo_stream.erb`
    - Toast « Établissement créé : 77 classes générées » (nombre réel, et niveaux sautés s'il y en a), modale refermée, `prepend` de la ligne dans la liste.
  - `app/views/teams/schools/update.turbo_stream.erb`
    - Toast, `replace` de la ligne et de l'en-tête (chacun ignoré s'il n'est pas sur la page).
  - `app/views/teams/schools/deactivate.turbo_stream.erb`
  - `app/views/teams/schools/destroy.turbo_stream.erb`
    - Succès : `remove` de la ligne. Refus : toast « Désactivez plutôt cet établissement », statut 422.
  - `config/locales/teams/schools.fr.yml`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/dtos/school/school_input_test.rb`
  - `test/domain/use_cases/school/create_school_test.rb`
    - Avec le référentiel de développement : lycée public **77** classes, lycée privé **38**, lycée mixte 38 (barème privé), « Collège moderne » public **28** et aucune de second cycle ; noms espacés (« 6ème 1 », « Tle D 3 ») ; une `1ere` sans série liée est sautée et comptée ; codes d'adhésion tous distincts ; échec d'insertion des classes → **aucune école créée**.
  - `test/domain/use_cases/school/update_school_test.rb`
    - Changer le cycle ne crée ni ne supprime de classe.
  - `test/domain/use_cases/school/deactivate_school_test.rb`
  - `test/domain/use_cases/school/delete_school_test.rb`
  - `test/infrastructure/queries/school/schools_query_test.rb`
  - `test/infrastructure/queries/school/school_detail_query_test.rb`
  - `test/controllers/teams/schools_controller_test.rb`
    - Non-équipe : 403 ; Turbo Stream ; 422 ; repli HTML.
  - `test/system/teams/schools_test.rb`
    - Filtrer la liste ; créer un lycée public (toast « 77 classes ») ; le modifier ; le désactiver ; échouer à supprimer un établissement référencé : tout **sans rechargement de page**.
- **Done quand**   : les critères SC-03, SC-04, SC-05, SC-06, SC-07 et SC-09 sont verts ; l'entrée « Établissements » de la navigation équipe mène à la liste ; tout se fait **sans rechargement de page**.
- **Hotwire**      : liste filtrée et paginée dans un frame ; modales ; 422 ; streams `create`, `update`, `deactivate`, `destroy` ; repli HTML.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/schools/index.html.erb`, `show.html.erb`, `_form.html.erb` ; `⟨ancienne⟩ domain/…/generate_default_classrooms.rb` (table des classes, reprise par l'ADR-0030) ; capture `teams/team-school-id-school.png`
- **Fiches d'inventaire** : SC-03 à SC-07, SC-09. CL-01 (génération).
- **Non-régression** : aucun élève de démonstration créé ; aucune école sans ses classes ; supprimer une école utilisée est refusé.
- **UDR**          : UDR-0036 — Établissements

---

## Lot S3 — Import des établissements, avec génération des classes

- **Couche**       : domaine (adaptateur d'import) + delivery (job) + ui (aide) + schéma + performance
- **Fichiers**     :
  - `app/domain/use_cases/school/import_schools.rb`
    - `School::ImportSchools`, inclut `UseCases::Catalog::Importer`, `KIND = "schools"`, policy `ManageSchoolPolicy`.
    - `resolve_target` : `drena` de l'enveloppe par `DrenaRepository#find_by_slug`, facultative (inconnue : `unknown_target`, rejet en bloc).
    - `prepare` : `ids_by_slug` des DRENA, `taxonomy.lookup`, `schools.existing_keys`, `classrooms.taken_join_codes`.
    - `validate_root` : alias de l'ADR-0039 (`name`/`nom`, `sigle`/`schoolsigle`, `status`/`schoolstatus`/`statut`, `type`/`schooltype` : `public`, `privée`, `privé`, `private` → `private`, `mixte`, `mixed` → `mixed`) ; DRENA de l'élément, sinon celle de l'enveloppe, sinon `unknown_drena` ; `cycle` explicite ou `School.cycle_for` ; nom présent (150) ; clé `(drena_id, NaturalKey)`. Le plan de l'élément : l'école (avec son `public_id`) et ses lignes de classes par `DefaultClassroomPlan.rows_for`.
    - `write` : `schools.insert_many`, puis codes tirés pour toutes les classes du lot, puis `classrooms.insert_generated`. `details` : `classrooms_created`, `skipped_levels`, `skipped_series`.
  - `app/jobs/school/import_schools_job.rb`
    - `School::ImportSchoolsJob < Shared::ImportJob`, `adapter` → `School::ImportSchools` câblé.
  - `config/schemas/lnclass.schools.v1.json`
    - Enveloppe `{ format, version, drena?, schools[] }` ; alias permis dans chaque école ; `additionalProperties: false`.
  - `app/views/teams/imports/kinds/_schools.html.erb`
    - Aide, exemple minimal de l'ADR-0039, liste des slugs de DRENA (`SchoolOptionsQuery#drenas`), rappel : « les classes sont générées selon le type et le cycle ; aucune école existante n'est modifiée ».
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/school/import_schools_test.rb`
    - `assert_importer_contract` ; alias ; « Collège » (accents et casse ignorés) → `first` ; mixte → barème privé ; DRENA par élément ; doublon en base et doublon dans le fichier ignorés et comptés ; **fichier mixte → rapport exact** (8 écoles valides, 2 invalides à `schools[3].type` et `schools[6].name`, 1 doublon : `imported_count` 8, `error_count` 2, `skipped_count` 1, `total_count` 11, aucune ligne ni classe pour les invalides) ; enveloppe `lnclass.courses` → `rejected`, zéro écriture ; lot en échec (code d'adhésion pris entre la validation et l'écriture) rejoué élément par élément.
  - `test/jobs/school/import_schools_job_test.rb`
    - Le job écrit l'extrait réel `schools_legacy_sample.json` du socle : écoles et classes créées, rapport `completed`.
  - `test/system/school/import_schools_test.rb`
    - `open_in_modal(new_teams_import_path(kind: "schools"))` : l'aide du type est affichée ; un fichier mixte donne, **sans rechargement de page**, le rapport exact avec les chemins d'erreur.
  - `test/performance/school/import_schools_performance_test.rb`
    - **500 écoles** (44 % de collèges, public, privé et mixte) → environ **35 000 classes**, `RunImport` complet en **moins de 120 s** ; mémoire du processus consignée. Ignoré sans `PERF=1`.
- **Done quand**   : le critère SC-08 est vert ; un fichier de l'ancienne application, **une fois enveloppé**, s'importe classes comprises ; un fichier mixte donne un rapport exact ; le suivi se fait **sans rechargement de page** ; le test de performance passe en local.
- **Hotwire**      : aucun contrôleur propre ; la modale, les streams et le suivi sont ceux du socle (0e) ; ce lot fournit le partial du type.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/catalog/schools/_import_form.html.erb` ; `⟨ancienne⟩ domain/…/school_import_strategy.rb` pour les clés acceptées ; exemples `.Business/content_pedagogics/DRENAS/`.
- **Fiches d'inventaire** : SC-08, SC-09, TR-28.
- **Non-régression** : aucun élève de démonstration ; codes d'adhésion uniques ; une école invalide ne bloque pas les valides ; aucune école existante mise à jour.
- **UDR**          : UDR-0037 — Import des établissements

---

## Lot I1 — Import de cours complets (`course_tree`)

- **Couche**       : domaine (adaptateur d'import) + delivery (job) + ui (aide) + schéma + performance
- **Fichiers**     :
  - `app/domain/use_cases/catalog/import_course_tree.rb`
    - `Catalog::ImportCourseTree`, `KIND = "course_tree"`, policy `ManageContentPolicy`. Pas de cible.
    - `prepare` : `taxonomy.lookup`, `courses.existing_keys`, `taken_slugs` des cours et des fiches.
    - `validate_root` : un cours et toute sa descendance. `level_name`, `series_name` et `material_name` résolus par `TaxonomyLookup` (`unknown_level`…), couple niveau–série permis (`series_not_allowed`) ; cours, fiches et exercices par `ContentNode` ; clé `(NaturalKey(nom), level_id, material_id, series_id)`. Le plan : slugs par `Slug.unique`, `public_id` des exercices, positions, tout en `draft` (la clé `status` est ignorée).
    - `write` : `ContentTreeWriter#write(courses:, author_id:, at:)`. Le `content` HTML des cours et des fiches est **assaini** puis écrit dans leur rich text (0e).
  - `app/jobs/catalog/import_course_tree_job.rb`
  - `config/schemas/lnclass.course-tree.v1.json`
  - `app/views/teams/imports/kinds/_course_tree.html.erb`
    - Aide, exemple, noms de niveaux, séries et matières acceptés.
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/catalog/import_course_tree_test.rb`
    - `assert_importer_contract` ; « Physique Chimie » résolue ; erreur localisée (`courses[3].essentials[1].exercises[0].questions[2].answers`) ; doublons ; tout en `draft` ; **fichier mixte → rapport exact** (valides écrits avec toute leur descendance, invalides sans aucune ligne, doublons comptés) ; rejet en bloc sur une version 2 ; lot en échec rejoué élément par élément.
  - `test/jobs/catalog/import_course_tree_job_test.rb`
    - Avec l'extrait réel `course_tree_tle_d_sample.json` du socle.
    - **HTML importé assaini** : un cours et une fiche dont le `content` contient `<script>`, un attribut `onclick` et un lien `javascript:` sont importés ; en base, leur rich text ne contient plus rien de cela, et garde le gras, les listes et les formules `$…$`.
  - `test/system/catalog/import_course_tree_test.rb`
    - `open_in_modal(new_teams_import_path(kind: "course_tree"))` : fichier mixte, rapport exact **sans rechargement de page**.
  - `test/performance/catalog/import_course_tree_performance_test.rb`
    - **200 cours complets** (8 fiches, 2 exercices par fiche, 10 questions, 4 propositions) en **moins de 120 s**. Ignoré sans `PERF=1`.
- **Done quand**   : le critère CA-08 est vert ; un fichier mixte donne un rapport exact ; le test de performance passe.
- **Hotwire**      : comme S3.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/components/_import_form.html.erb` ; `⟨ancienne⟩ domain/…/course_import_strategy.rb` ; exemples `.Business/content_pedagogics/tle_d/`.
- **Fiches d'inventaire** : CA-08, TR-28.
- **Non-régression** : aucun contenu importé n'est publié d'office ; un nom de matière inconnu est une erreur de l'élément, jamais une création silencieuse.
- **UDR**          : UDR-0038 — Import de cours

---

## Lot I2 — Import de fiches essentielles dans un cours (`essentials`)

- **Couche**       : domaine (adaptateur d'import) + delivery (job) + ui (aide) + schéma + performance
- **Fichiers**     :
  - `app/domain/use_cases/catalog/import_essentials.rb`
    - `Catalog::ImportEssentials`, `KIND = "essentials"`, policy `ManageContentPolicy`. Cible `course` (slug) obligatoire : `CourseRepository#find_by_slug`, sinon rejet en bloc. Élément racine : une fiche et ses exercices. Clé `(course_id, NaturalKey(nom))`. Positions à la suite de `next_position`. Tout en `draft`.
    - `write` : `ContentTreeWriter#write(essentials:, …)`. Le `content` HTML de chaque fiche est **assaini** puis écrit dans son rich text (0e).
  - `app/jobs/catalog/import_essentials_job.rb`
  - `config/schemas/lnclass.essentials.v1.json`
  - `app/views/teams/imports/kinds/_essentials.html.erb`
    - Rappelle le slug du cours reçu en paramètre (`course`), à placer dans l'enveloppe.
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/catalog/import_essentials_test.rb`
    - Contrat ; cours inconnu → `rejected` ; **fichier mixte → rapport exact** ; doublon ; lot rejoué.
  - `test/jobs/catalog/import_essentials_job_test.rb`
    - **HTML importé assaini** : une fiche dont le `content` contient `<script>` et un attribut `onerror` est importée ; son rich text en base n'en garde rien.
  - `test/system/catalog/import_essentials_test.rb`
    - Fichier mixte, rapport exact **sans rechargement de page**.
  - `test/performance/catalog/import_essentials_performance_test.rb`
    - Fichier au plafond : **2 000 fiches** (2 exercices, 10 questions, 4 propositions) en **moins de 120 s**. Ignoré sans `PERF=1`.
- **Done quand**   : le critère CA-15 est vert : depuis la page d'un cours, l'équipe importe ses fiches essentielles ; un fichier mixte donne un rapport exact.
- **Hotwire**      : comme S3.
- **Écrans de l'ancienne application** : `⟨ancienne⟩ views/components/_import_form.html.erb`
- **Fiches d'inventaire** : CA-15, TR-28.
- **Non-régression** : une fiche importée ne s'insère jamais dans un autre cours que la cible.
- **UDR**          : UDR-0039 — Import de fiches essentielles

---

## Lot I3 — Import d'exercices dans une fiche essentielle (`exercises`)

- **Couche**       : domaine (adaptateur d'import) + delivery (job) + ui (aide) + schéma + performance
- **Fichiers**     :
  - `app/domain/use_cases/assessment/import_exercises.rb`
    - `Assessment::ImportExercises`, `KIND = "exercises"`, policy `ManageContentPolicy`. Cible `essential` (slug) obligatoire. Élément racine : un exercice, ses questions et leurs propositions. Règles de cohérence de l'ADR-0039 par `ContentNode.validate_exercise`. Clé `(essential_id, NaturalKey(titre))`. `public_id` tirés, positions par `next_positions`. Tout en `draft`.
    - `write` : `ContentTreeWriter#write(exercises:, …)`.
  - `app/jobs/assessment/import_exercises_job.rb`
  - `config/schemas/lnclass.exercises.v1.json`
  - `app/views/teams/imports/kinds/_exercises.html.erb`
- **Dépend de**    : socle
- **Test associé** :
  - `test/domain/use_cases/assessment/import_exercises_test.rb`
    - Contrat ; quatre types de question, valides et invalides, avec leur chemin ; `true_false` à 3 propositions refusé ; **fichier mixte → rapport exact** ; fiche inconnue → `rejected` ; lot rejoué.
  - `test/jobs/assessment/import_exercises_job_test.rb`
  - `test/system/assessment/import_exercises_test.rb`
    - Fichier mixte, rapport exact **sans rechargement de page**.
  - `test/performance/assessment/import_exercises_performance_test.rb`
    - Fichier au plafond : **10 000 exercices** (5 questions, 4 propositions) en **moins de 120 s**. Ignoré sans `PERF=1`.
- **Done quand**   : le critère d'import d'exercices (remplaçant d'AS-06) est vert ; un fichier mixte donne un rapport exact.
- **Hotwire**      : comme S3.
- **Écrans de l'ancienne application** : aucun (AS-06 était un générateur, écarté).
- **Fiches d'inventaire** : AS-06 (écartée, remplacée), TR-28.
- **Non-régression** : aucune question mal formée n'entre en base.
- **UDR**          : UDR-0040 — Import d'exercices

---

## Lot E — Preuve bout en bout

- **Couche**       : tests système (Chrome headless) + recette
- **Fichiers**     :
  - `test/system/boucle_pedagogique_test.rb`
    - Base vierge **sans seed de contenu** (seul `identity.rb`). L'équipe accepte l'invitation d'amorçage, enrôle son TOTP, crée par les vrais boutons le référentiel (niveau « Tle », série « D », liés ; matière SVT, catégorie science), une DRENA et un lycée public : **6 classes « Tle D 1 » à « Tle D 6 »** générées, les autres niveaux du barème étant absents et comptés comme sautés. Elle crée un cours, une fiche essentielle et un exercice de 2 questions, et les publie.
    - L'enseignant s'inscrit, déclare une classe générée, ouvre la classe, le cours et la fiche, assigne l'exercice ; il génère un code de récupération pour un élève.
    - L'élève ouvre `/c/<code>`, s'inscrit, voit l'exercice sur son accueil (sans le code de sa classe), répond aux 2 questions ; la session se clôt seule ; il voit « Félicitations ! », 20/20 et le badge « Diamant ».
    - L'enseignant ouvre le résultat de l'élève : score et note, sans propositions correctes.
    - Chaque écriture (création, publication, assignation, réponse) est enveloppée dans `assert_no_page_reload`. Partie élève rejouée en viewport mobile.
  - `test/system/imports_end_to_end_test.rb`
    - L'équipe importe un fichier d'écoles au format de l'ancienne application **enveloppé**, puis un `course_tree` ; elle suit le rapport jusqu'à « Terminé » sans recharger ; les classes et le contenu en brouillon apparaissent dans leurs écrans ; un fichier **mixte** affiche ses compteurs exacts et ses chemins d'erreur, et seuls ses éléments valides sont en base ; un fichier à l'enveloppe invalide finit « Rejeté » sans rien écrire.
  - `test/system/role_homes_test.rb`
    - Pour chaque rôle : connexion réelle, accueil sans erreur, chaque destination active de la navigation ouverte (chantier `queries-constantes-orm-disparues`).
  - `test/system/error_paths_test.rb`
    - Joué **par un rôle distinct de l'auteur** : code de classe invalide, classe pleine, réponse vide, enseignant hors de sa classe, PIN oublié puis code émis par l'enseignant puis nouveau PIN, team sans second facteur, second import du même type pendant qu'un premier tourne.
- **Dépend de**    : tous les lots (0a, 0b, 0d, 0e, A1 à A4, B1 à B8, C1 à C3, D1 à D8, R1 à R3, S1 à S3, I1 à I3)
- **Test associé** : les quatre fichiers ci-dessus ; `bin/ci` complet ; les cinq tests de performance joués avec `PERF=1`.
- **Done quand**   :
  - les quatre tests système sont verts en local et en CI, **aucune écriture ne recharge la page** ;
  - les tests de performance passent en local et sur `Staging` ;
  - la recette est faite sur `Staging` par un rôle distinct (parcours nominal, un chemin d'erreur, un import réel de 500 écoles chronométré), et son compte rendu est dans `journal.md` ;
  - toutes les portes de sortie ci-dessous sont cochées.
- **Hotwire**      : aucun fichier d'interface ; ce lot prouve la règle par les vrais boutons, là où les lots l'ont prouvée par `open_in_modal`.
- **Fiches d'inventaire** : TR-04, TR-05, TR-09 (tests système), TR-28, et les critères de porte V1 du PRD cadre §5.

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier. La commande de [`plan-lots`](../../../.claude/skills/plan-lots/SKILL.md) doit renvoyer **une sortie vide** sur tout ce qui précède cette section :
>
> ```bash
> awk '/^## Vérification de collision/{exit} 1' docs/chantiers/boucle-pedagogique/plan.md \
>   | grep -oE '(app|test|config|db|lib)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d
> ```
>
> Vérifiée à la rédaction : sortie vide. Chaque chemin n'est écrit qu'une fois, dans le lot qui le possède. (Les schémas `config/schemas/*.json` sont captés sous la forme `….v1.js` : chacun reste unique.)

**Fichiers qui auraient été partagés, et que le socle a donc repris**

| Fichier ou famille | Lots qui en ont besoin | Propriétaire |
|---|---|---|
| `config/routes.rb` et les 7 fichiers de `config/routes/` | tous : 7 lots dans `classroom`, 16 dans l'espace équipe | **0a**, toutes les routes V1 dessinées |
| Migrations, schéma, modèles `Orm::`, fabriques, `test_helper` | tous | **0a** |
| `Gemfile`, `package.json`, `esbuild.config.mjs`, `config/environments/test.rb` | tous | **0a** ; `config/credentials.yml.enc` par l'orchestrateur |
| Ports, entités, policies, DTO du socle, `Shared::Result`, `TransactionPort` | tous | **0b**, gelés au merge |
| `DefaultClassroomPlan`, `TaxonomyLookup`, `Slug`, `NaturalKey`, `ContentNode`, `ImportKind` | S2, S3, I1 à I3, seeds | **0b** |
| `ApplicationController`, `AuthenticatedController`, `Teams::BaseController`, concerns, helpers de test système | tous | **0d** |
| Repositories `identity` et transaction | B7, B8, D1, A1, tous les use cases | **0d** |
| Les 18 autres repositories | par exemple `AssignmentRepository` : A2, A3, B3, C2, D4 à D7 ; `ClassroomRepository#insert_generated` : S2, S3, seeds | **0e** |
| Moteur d'import (`StartImport`, `RunImport`, contrat `Importer`, `Shared::ImportJob`, `Teams::ImportsController`, écran de suivi, `config.x.import_jobs`) | S3, I1, I2, I3 | **0e** ; chaque lot n'ajoute que son adaptateur, son job, son schéma et son partial `kinds/_<kind>` |
| `ContentTreeWriter` | I1, I2, I3 | **0e** |
| Chargement Stimulus par motif, `math_controller`, `rich_text_editor_controller`, gabarit de rendu Action Text, morphing dans le layout | A1 à D8, R, S | **0e** : aucun manifeste à éditer |
| Action Text : framework, table, `has_rich_text` ; `RichTextSanitizer` | B1 à B4, I1, I2 | **0a** ; assainissement **0e** |
| `ReferentialOptionsQuery`, `SchoolOptionsQuery`, `ClassroomHeaderQuery` | B2, D1, D4 à D8, S2, S3, A3 | **0e** |
| `badges_helper`, `content_status_helper` (`content_status_panel`) | A2, B1 à B5, C1, C3 | **0e** |
| Locales communes (`shared/common.fr.yml`) | tous | **0d** |
| Seeds et données de développement | tous (développement) | **0e** |
| Partial de bascule d'assignation et ses streams (D5) | D5, D6, D7 | **D5** ; D6 et D7 en dépendent (vague 4) |
| Pages hôtes d'un formulaire d'un autre lot (catalogue B1 pour B2, fiche établissement S2 pour D8…) | B2, B4, B5, D8, S3, I1 à I3 | **Aucun partage** : le stream du formulaire fait `turbo_stream.refresh` ou remplace le `content_status_panel` du socle ; il ne rend jamais un partial d'un autre lot |
| `app/views/homepage/index.html.erb` et ses tests (V0) | A4 (contenu), 0d (redirection) | **A4** ; la redirection de 0d est testée dans un fichier à part |
| `docs/decisions/udr/README.md` | chaque lot, pour son UDR | **Orchestrateur**, au merge de chaque lot |
| `docs/chantiers/boucle-pedagogique/journal.md` | tous | **Orchestrateur** |

## Vagues de dispatch

```
Vague 0 : V0 + Lot 0c (design)                         → mergés dans Develop (32fb626)
Vague 1 : 0a ‖ 0b                                      → 2 agents, fichiers disjoints
Vague 2 : 0d ‖ 0e (e1 à e3) dès le merge de 0a,
          mergés après 0b ; e4 après le merge de 0d    → 2 agents
Vague 3 : 30 lots verticaux, en quatre sous-vagues de 8 au plus
  3a : R1 ‖ R2 ‖ R3 ‖ S1 ‖ S2 ‖ B2 ‖ B4 ‖ B5            → 8 agents
  3b : D1 ‖ D2 ‖ D4 ‖ D5 ‖ A1 ‖ A2 ‖ C1 ‖ C2            → 8 agents
  3c : C3 ‖ B7 ‖ S3 ‖ I1 ‖ I2 ‖ I3 ‖ B1 ‖ B3            → 8 agents
  3d : A3 ‖ A4 ‖ B6 ‖ B8 ‖ D3 ‖ D8                     → 6 agents
Vague 4 : D6 ‖ D7 (dépendent de D5, mergé en 3b),
          lancés avec 3d                               → 2 agents (3d + 4 = 8)
Vague 5 : Lot E (dépend de tous)                       → 1 agent, rôle distinct des auteurs
```

**Ordre des sous-vagues : le chemin critique d'abord.**
- **3a et 3b, puis C3 et B7 en tête de 3c**, forment le chemin critique du parcours bout en bout. L'équipe crée le référentiel, une DRENA et un établissement, qui génère ses classes. Elle publie un cours, une fiche essentielle et un exercice, et invite un collègue. L'enseignant s'inscrit, déclare ses classes, ouvre sa classe et assigne. L'élève rejoint sa classe, voit son accueil, fait l'exercice et obtient son badge.
- **3c** ajoute les imports (S3, I1, I2, I3), puis la lecture du catalogue et des fiches (B1, B3).
- **3d** livre le reste : A3, A4, B6, B8, D3, D8, et D6 et D7, qui attendent D5.
- Les lots d'une même sous-vague ne dépendent que du socle : aucun n'attend un autre lot de la même sous-vague. Le découpage ne change donc pas le graphe. Il limite seulement le nombre d'agents et la file de merge.
- **Une sous-vague part quand la précédente est entièrement mergée** et que `bin/ci` est vert sur la branche de chantier. Si l'orchestrateur a de la capacité, il peut avancer un lot de la sous-vague suivante dès qu'une place se libère, en respectant l'ordre de la liste. Il ne dépasse jamais 8 lots verticaux actifs.

Chaque lot travaille dans son propre worktree, créé depuis la branche de chantier une fois ses dépendances mergées :

```bash
git worktree add ../lnclass-lot-s3 -b feature/boucle-pedagogique-lot-s3 feature/boucle-pedagogique
```

**Ordre de merge.**
- Vague 1 : 0a et 0b dans l'ordre où ils finissent ; aucun fichier commun.
- Vague 2 : 0d et e1 à e3 après 0a et 0b ; e4 part de la branche de chantier après le merge de 0d.
- Vague 3 : dans chaque sous-vague, dans l'ordre où les lots finissent ; les fichiers sont disjoints, il n'y a jamais de conflit textuel. D5 est mergé (3b) avant le départ de D6 et D7.
- Après chaque merge, l'orchestrateur lance `bin/ci` sur la branche de chantier : un lot qui la casse est retiré, pas corrigé sur place.

## Traçabilité — feature V1 → lot

Source : [feuille de route §6](../refonte-application/feuille-de-route.md#6-traçabilité--chaque-feature-de-lexistant-a-une-vague), colonne « Vague » = V1, **élargie par le porteur le 2026-09-25** (DRENA, établissements, référentiel, imports). Critères : [PRD §4](prd.md#4-critères-dacceptation).

| ID | Feature | Lot(s) |
|---|---|---|
| ID-01 | S'inscrire comme élève (par le code de classe) | A1 |
| ID-02 | S'inscrire par `/c/<code>` | A1 |
| ID-03 | S'inscrire comme enseignant | D1 |
| ID-04 | *(écartée)* Remplacée par l'invitation (F-16) et l'invitation d'amorçage | 0e (seed), B7 |
| ID-07 | Vérifier un code | A1 (aperçu de `/c/<code>`) |
| ID-08 | DRENA → établissements (la cascade vers les classes est écartée) | D1 |
| ID-12 | Se connecter | 0d |
| ID-13 | Être dirigé vers son espace | 0b (`HomeDestination`), 0d |
| ID-14 | Se déconnecter | 0d |
| ID-15 | Récupérer un PIN oublié | 0d (saisie du code), B8 (émission), D4 (bouton de l'enseignant) |
| ID-16 | Restreindre chaque espace à son rôle | 0b (policies), 0d |
| ID-28 | Normaliser et valider le numéro | 0b |
| ID-29 | Identifiant public | 0a |
| F-07 | TOTP équipe | 0d (enrôlement, vérification), B8 (réinitialisation) |
| F-16 | Invitation de l'équipe | B7 |
| CO-09 | Toasts | 0c (composant), tous les streams |
| SC-01 | Gérer les DRENA | S1 |
| SC-02 | *(écartée par le porteur)* Importer des DRENA : elles se créent à l'écran | — |
| SC-03 | Créer un établissement | S2 |
| SC-04 | Liste nationale des établissements | S2 |
| SC-05 | Consulter un établissement | S2 |
| SC-06 | Modifier un établissement | S2 |
| SC-07 | Supprimer un établissement (ou le désactiver) | S2 |
| SC-08 | Importer des établissements | S3 (adaptateur), 0e (moteur) |
| SC-09 | Générer les classes par défaut | 0b (`DefaultClassroomPlan`), 0e (`insert_generated`), S2 (création unitaire), S3 (import) |
| SC-26 | API des établissements d'une DRENA | D1 |
| SC-27 | Rattachement à l'école à l'inscription | D1 |
| CL-01 | Créer une classe | D8 (unitaire), S2 et S3 (génération) |
| CL-04 | Générer et afficher le code | 0b (`JoinCode`), D8 et S2 (génération), D4 (affichage) |
| CL-06 | Rejoindre par `/c/<code>` | A1 |
| CL-07 | S'inscrire avec un code | A1 |
| CL-08 | Vérification du code (la liste des classes est écartée) | A1 |
| CL-09 | Déclarer ses classes | D2 |
| CL-10 | Fiche d'une classe | D4 (enseignant, équipe), A3 (volet élève, sans code) |
| CL-11 | Cours dans la classe | D5 |
| CL-12 | Fiche essentielle dans la classe | D6 |
| CL-16 | Assigner / retirer un cours | D5 |
| CL-17 | Assigner / retirer une fiche essentielle | D5 |
| CL-20 | Assigner / retirer un exercice | D5 (bascule), D6 (écran) |
| CL-22 | Ma classe (élève) | A3 |
| CL-23 | Accueil élève | A2 |
| CA-01 | Catalogue publié | B1 |
| CA-04 | Consulter un cours | B1 |
| CA-05 | Créer un cours | B2 |
| CA-06 | Modifier un cours | B2 |
| CA-07 | Archiver un cours | B2 |
| CA-08 | Import de cours en masse | I1 (adaptateur), B1 (bouton), 0e (moteur) |
| CA-10 | Fiches essentielles d'un cours | B1 |
| CA-11 | Fiche essentielle et progression | B3 |
| CA-12 | Créer une fiche essentielle | B4 |
| CA-13 | Modifier une fiche essentielle | B4 |
| CA-14 | Archiver une fiche essentielle | B4 |
| CA-15 | Importer des fiches essentielles dans un cours | I2 (adaptateur), B1 (bouton), 0e (moteur) |
| CA-16 | Lister les niveaux | R1 |
| CA-18 | Gérer les niveaux | R1 |
| CA-19 | Associer des séries à un niveau | R2 |
| CA-20 | Lister les matières | R3 |
| CA-22 | Gérer les matières | R3 |
| CA-24 | Gérer les séries | R2 |
| CA-25 | Référentiel depuis l'accueil équipe (« Setup ») | B6 (section), R1 à R3, S1 (écrans) |
| CA-26 | Couleur et icône de la matière par catégorie | 0a (colonne et contrainte), 0c (`ui_subject_badge`), R3 (saisie), B1 (écran de référence) |
| CA-27 | Assigner un cours depuis sa page | B1 (lien), D7 (écran) |
| AS-02 | Détail d'un exercice | C1 |
| AS-03 | Créer un exercice | B5 |
| AS-04 | Modifier un exercice | B5 |
| AS-05 | Archiver un exercice | B5 |
| AS-06 | *(écartée)* Remplacée par l'import d'exercices | I3 (adaptateur), B3 (bouton), 0e (moteur) |
| AS-07 | Démarrer une session | C2 |
| AS-08 | Reprendre | C2 |
| AS-09 | Répondre une fois | C2 |
| AS-10 | Correction immédiate | C2 |
| AS-11 | Clôture automatique et badge | C2 (clôture), C3 (affichage) |
| AS-12 | Résultat | C3 |
| AS-13 | Recommencer | C3 (bouton), C2 (`restart`) |
| AS-18 | Assigner un exercice | D5 |
| AS-19 | Retirer un exercice | D5 |
| AS-20 | Exercices d'une fiche essentielle dans une classe | D6 |
| AS-36 | Exercices sur l'accueil élève | A2 |
| AS-37 | Progression sur la fiche essentielle | B3 |
| AS-39 | Aperçu des questions sans fuite | C1, C3 |
| TR-01 | Landing | A4 |
| TR-02 | Redirection par rôle | 0d |
| TR-04 | Accueil élève | A2, E |
| TR-05 | Accueil enseignant | D3, E |
| TR-08 | *(écartée)* Remplacée par l'onboarding persisté | 0a (`onboarding_completed_at`), 0b (`HomeDestination`), D2 |
| TR-09 | Accueil équipe | B6, E |
| TR-27 | Navigation par rôle | 0c, 0a (routes nommées, `schools_path` actif), 0d (shell branché) |
| TR-28 | Imports JSON en arrière-plan, **partiels** | 0e (moteur, job, suivi), S3, I1 à I3 (adaptateurs), E |
| TR-40 | Français par clés | 0d (clés communes), tous |
| TR-41 | KaTeX dans le bundle | 0a (build), 0e (`math_controller`) |
| Transverse | Tout CRUD par Hotwire, sans rechargement de page | 0d (assertions), 0e (morphing, panneau de statut), chaque lot à écran, E |
| chantier `queries-constantes-orm-disparues` | Accueils vivants | E |
| chantier `catalog-lecture-ecriture-incompatibles` | Un seul agrégat de cours | 0b, B2 |
| chantier `classroom-assignment-belongs-to-casses` | Repository d'assignation à 100 % | 0a (pas d'association polymorphe), 0e, D5 |
| chantier `classroom-code-adhesion-trop-long` | Longueur de colonne = longueur du code | 0a |
| chantier `dette-contrats-ports-et-injection` | Contrats de port, domaine sans repository | 0b, 0e (garde `port_contracts`) |
| PRD cadre §5, 6 critères | Porte V1 | 0d (n° 2, n° 5), A1 et D1 (n° 1), C1 (n° 3), D4 (n° 4), B5 (n° 6), E (rejeu système) |

## Décisions que ce plan suppose

Les ADR-0026 à ADR-0054 et l'UDR-0007 sont **acceptés** et ce plan s'aligne sur eux. Les **amendements** et **errata** qu'il exige sont **écrits dans la branche de ce plan** (`docs/boucle-pedagogique`), en section « Amendement du 2026-09-25 » à la fin de chaque fichier : UDR-0006, ADR-0027, ADR-0028, ADR-0034 et ADR-0039. Restent des **précisions** que les ADR laissent ouvertes, ajustables par l'orchestrateur sans toucher aux lots verticaux.

| Décision supposée | Nature | Où elle doit figurer |
|---|---|---|
| La colonne de l'ADR-0039 nommée `errors` s'appelle **`import_errors`** : `errors` est réservé par `ActiveModel` sur tout modèle. | **Erratum** | ADR-0039 |
| L'entrée « Établissements » (`schools_path`) de la navigation équipe est **active** dès la V1 : les établissements sont entrés dans le périmètre. `team_dashboard_path` et `profile_path` restent inactives. | **Amendement** | UDR-0006 (ligne « En V1, … restent inactives ») |
| Policies ajoutées à la liste de l'ADR-0028 : `DeclareTeachingPolicy` (ADR-0030), `IssuePinRecoveryCodePolicy` (ADR-0032), `ResetSecondFactorPolicy` (ADR-0031), `RegisterTeacherPolicy`, `ReadClassroomPolicy`, `SubmitAttemptPolicy` (règle de l'ADR-0054), `Identity::SessionPolicy` et `Identity::SecondFactorPolicy`. Ces deux dernières donnent une policy aux mécanismes de session, qui ne sont donc **pas** exemptés : les exemptions restent les trois de l'ADR-0028. La lecture d'un rapport d'import applique la policy de son type : pas de `ReadImportReportPolicy`. | **Amendement** | ADR-0028 |
| La destination d'accueil est une **query** (`HomeDestinationQuery`, qui délègue à l'entité `HomeDestination`), pas un use case : c'est une lecture. | Précision | ADR-0028 |
| `TransactionPort` vit dans `app/domain/ports/shared/` (`Ports::Shared::TransactionPort`, ADR-0026), et non dans `app/domain/shared/`. | **Erratum** | ADR-0027 |
| `Ports::Shared::TransactionPort#attempt` : un bloc dont l'écriture est refusée par la base renvoie `failure(:conflict)` au lieu de lever. C'est ce qui permet au moteur de rejouer un lot élément par élément sans nommer une exception d'infrastructure dans le domaine. | Précision | ADR-0026 |
| Le moteur d'import est câblé par `Shared::ImportJob` et `config.x.import_jobs` (nom du job par type, résolu à l'appel) : un lot d'import n'édite aucun fichier du socle. | Précision | ADR-0039 |
| **Un test de performance par type** (`test/performance/<ctx>/import_<kind>_performance_test.rb`), au lieu du fichier unique `test/performance/imports_test.rb` de l'ADR-0039 : chaque lot possède le sien, sans collision. Hors CI, joués avec `PERF=1` avant la recette. | Écart assumé | ADR-0039 |
| **Éditeur riche en V1** (retour du porteur du 2026-09-25) : le contenu des cours et des fiches essentielles est un rich text Action Text (`has_rich_text :content`), saisi dans Trix. Trix et `@rails/actiontext` sont chargés **uniquement sur les pages d'édition**, par import dynamique (`rich-text-editor`), hors du point d'entrée commun de 60 Ko. Les imports I1 et I2 écrivent du HTML **assaini** dans le même rich text. | **Amendement** | ADR-0051 (« Amendement du 2026-09-25 ») |
| **Pièces jointes de l'éditeur refusées en V1** : un fichier glissé dans Trix est rejeté. Le téléversement direct vers le bucket (ADR-0047) exigerait d'ouvrir `connect-src` de la CSP (ADR-0049). **À confirmer par le porteur.** | Précision | ADR-0051 |
| `users.gender` conservé, non nul (`male`, `female`) : l'ancienne application le demandait et le PRD cadre le garde. Confirmé par le porteur le 2026-09-25. | Précision | ADR-0037 |
| `friendly_id` **retiré** : slugs figés par `Orm::HasFrozenSlug`, `public_id` par `Orm::HasPublicId` ; la table `friendly_id_slugs` de V0 est supprimée. | Précision | ADR-0029 |
| La CSS de KaTeX est un **fichier séparé** (`katex.css`), chargé par `math_controller` seulement sur les pages qui ont des formules : le budget CSS commun (30 Ko) reste tenu. | Précision | ADR-0051 |
| `rate_limit` exige un cache réel en test : `config/environments/test.rb` passe à `:memory_store`, vidé avant chaque test. | Précision | ADR-0050 |
| Clés Active Record Encryption : ajoutées aux credentials par l'orchestrateur (`db:encryption:init`) ; des clés de test fixes sont posées dans `config/environments/test.rb`, puisque la CI n'a pas de clé maître. | Précision | ADR-0031 |
| Un fichier de routes `config/routes/teams.rb` en plus des six contextes, pour l'espace `/teams` (ADR-0026). | Précision | ADR-0027 |
| Lacunes (`knowledge_gaps`) écrites dès la V1 par `CloseExerciseSession` ; leur affichage enseignant et la remédiation guidée arrivent en V5, tels que validés (ADR-0043). | Précision | ADR-0043 |

## Risques

| Risque | Parade |
|---|---|
| Le socle reste gros (environ 400 chemins, tests compris) et tout le parallélisme l'attend. | Découpé en quatre sous-lots à fichiers disjoints, deux par deux en parallèle ; ports gelés dès le merge de 0b ; e1 à e3 avancent pendant 0d. |
| **Espace des codes d'adhésion** : 24³ × 8² = 884 736 codes. 2 000 écoles × 77 classes ≈ 154 000 codes par an, qui s'accumulent tant que les classes archivées gardent leur code. | `CloseJoinCode` à l'archivage de l'année (V3, ADR-0041) libère les codes. Le domaine tire contre l'ensemble des codes pris. Au-delà de 50 % d'occupation, un test d'alerte échoue : passage à 6 caractères par un nouvel ADR. |
| **Mémoire** : un JSON de 20 Mo parsé en entier, plus les plans de chaque élément, dans le worker. | Limite de 20 Mo et plafonds par type (`ImportKind`) ; un import à la fois par type (`limits_concurrency`, index partiel) ; mémoire mesurée par les tests de performance ; worker séparé (ADR-0052). |
| Un **code d'adhésion ou un slug pris entre la validation et l'écriture** (écriture concurrente à l'écran). | Le lot échoue en bloc (`attempt`), puis est rejoué élément par élément : seul l'élément en collision passe en `write_failed`, les autres sont écrits. Testé par S3. |
| **Job tué** en cours d'import (déploiement) : rapport bloqué en `importing`. | `StartImport` passe `failed` tout rapport commencé depuis plus de 30 min ; relancer le fichier compte en doublons ce qui était déjà écrit. |
| **`RAILS_MASTER_KEY`** absente ou différente sur Railway : les secrets TOTP chiffrés deviennent illisibles. | À vérifier par l'orchestrateur avant le déploiement de la V1 ; les tests n'en dépendent pas (clés de test dans `test.rb`). |
| **Stockage S3 Railway** (ADR-0047) : sans lui, les fichiers d'import ne sont pas conservés en production. | Le bucket et ses variables sont une action Railway, avec le feu vert du porteur, requise avant le déploiement de la V1 ; en local et en test, services `local` et `test`. |
| **Amendements non mergés** (UDR-0006, ADR-0028, ADR-0039, ADR-0027) : sans eux, le plan contredit des décisions acceptées. | Écrits dans la branche de ce plan ; ils entrent dans `Develop` avec lui. |
| Un test système de lot ne voit pas la page hôte d'un autre lot (pas encore mergée). | `open_in_modal` depuis une page du socle ; le parcours par les vrais boutons est rejoué au Lot E. |
| 30 lots verticaux : file de merge et temps de CI longs. | Quatre sous-vagues de 8 lots au plus, chemin critique d'abord (« Vagues de dispatch ») ; `bin/ci` après chaque merge. |

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
- [ ] Le parcours bout en bout passe en navigateur réel (Lot E), **sans rechargement de page** sur aucune écriture.
- [ ] La recette sur `Staging` est faite par un rôle distinct.
- [ ] Les budgets de performance des imports sont tenus en local et sur `Staging`.

## Challenger empirique

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Son mandat change selon le cycle : bugfix → il rejoue les étapes de reproduction du memo dans l'app ; refactoring → il vérifie que **rien** n'a changé pour l'utilisateur, et il lui est interdit de commenter le style ; optimisation → il **relance lui-même le bench** et doit obtenir le gain annoncé, sinon la PR ne passe pas.

**Mandat pour cette feature.**

1. Le challenger rejoue le chemin nominal du [PRD §3](prd.md#3-parcours-utilisateur) sur une base de production vierge (seul l'amorçage), en trois profils distincts : équipe, enseignant, élève. Le parcours élève se fait aussi en émulation 390 px. Il vérifie, onglet réseau ouvert, qu'**aucune écriture ne recharge la page** (aucune requête de document après un envoi de formulaire).
2. Il crée un lycée public avec le référentiel complet et compte **77 classes**, aux noms espacés (« Tle D 3 »).
3. Il importe lui-même un fichier réel de l'ancienne application (enveloppé) et un fichier de 500 écoles, et **chronomètre** : moins de 2 min, sinon la porte ne passe pas. Il fait de même avec 200 cours complets.
4. Il importe un fichier **mixte** qu'il a lui-même préparé (valides, invalides, doublons) : le rapport doit être exact au compteur près, chaque erreur à son chemin JSON, et seuls les éléments valides doivent être en base. Un fichier à la version 2 doit être rejeté en bloc.
5. Il rejoue au moins ces chemins d'erreur : 6e échec de connexion ; réponse vide ; double soumission ; enseignant hors de sa classe ; brouillon ouvert par son URL ; PIN oublié ; classe pleine ; second import du même type pendant qu'un premier tourne.
6. Il vérifie le HTML servi à l'élève et à l'enseignant avec les outils du navigateur : aucune proposition correcte hors de la correction de l'élève, et aucun code de classe dans les pages de l'élève.
7. Il consigne dans `journal.md` ce qu'il a fait, observé et mesuré.
