# Compléments d'inventaire — contexte borné **catalog**

> Mission n°3 de [`prompt-exploration.md`](../prompt-exploration.md) (partie 3). Exploration **en lecture seule** du dépôt, branche `Teamprocess`, `HEAD` = `684ae16` ; le dernier commit touchant `app/`, `config/routes.rb` ou `db/schema.rb` est `2449373` (`git log -1 -- app/ config/routes.rb db/schema.rb`) : le code est bien celui qu'a inventorié [`catalog.md`](catalog.md).
> Périmètre : taxonomie (niveaux, séries, `level_series`, matières), cours, fiches (`Essential`), imports JSON de cours et de fiches, validation collaborative, pages niveau et matière. **DRENA, écoles, rôles et personnel d'école sont exclus** (mission n°2) ; ils ne sont mentionnés que pour signaler un écart.
> Décisions confrontées : ADR-0011, ADR-0012, ADR-0020, ADR-0022, UDR-0001, [`glossaire.md`](../../../guide/glossaire.md), [`conventions.md`](../../../guide/conventions.md).
> Ce document **constate**. Il ne tranche aucune contradiction et ne recommande aucune implémentation.

**Légende des états** : ✅ marche · ⚠️ fragile ou partiellement cassé · ❌ cassé · 💀 jamais exécutable (code mort, ou aucun point d'entrée)

---

## 1. Catalogue des features avec identifiant

| ID | Feature | Acteur | État | Tables | Routes | Source |
|---|---|---|---|---|---|---|
| CA-01 | Parcourir le catalogue des cours publiés | tout connecté | ⚠️ | `courses`, `levels`, `materials`, `series`, `essentials` | `GET /courses` | `inventaire/catalog.md#A` (« Consulter le catalogue des cours ») |
| CA-02 | Filtrer le catalogue par niveau ou matière (paramètres d'URL) | tout connecté | ⚠️ | `courses` | `GET /courses?level_id=&material_id=` | nouveau (corrige `catalog.md#A`) |
| CA-03 | Charger la suite du catalogue (pagination infinie) | tout connecté | 💀 | `courses` | `GET /courses.turbo_stream?page=` | `inventaire/catalog.md#A` |
| CA-04 | Consulter un cours et la liste de ses fiches | tout connecté | ✅ | `courses`, `essentials`, `exercises`, `action_text_rich_texts` | `GET /courses/:id` | `inventaire/catalog.md#A` (« Consulter un cours ») |
| CA-05 | Créer un cours | `team` | ⚠️ | `courses`, `action_text_rich_texts` | `GET /courses/new`, `POST /courses` | `inventaire/catalog.md#A` (« Créer un cours ») |
| CA-06 | Modifier un cours | `team` | ❌ | `courses` | `GET /courses/:id/edit`, `PATCH\|PUT /courses/:id` | `inventaire/catalog.md#A` (« Modifier un cours ») |
| CA-07 | Supprimer un cours (cascade) | `team` | ✅ | `courses`, `essentials`, `exercises`, `questions`, `answers`, `knowledge_gaps`, `classroom_assignments` | `DELETE /courses/:id` | `inventaire/catalog.md#A` (« Supprimer un cours ») |
| CA-08 | Importer des cours en masse depuis des fichiers JSON (asynchrone) | `team` | ⚠️ | `courses`, `essentials`, `exercises`, `questions`, `answers`, `levels`, `materials`, `series`, `level_series`, `action_text_rich_texts` | `POST /courses/import_json` | `inventaire/catalog.md#A` (« Importer des cours en masse ») |
| CA-09 | Pré-remplir le formulaire cours ou fiche par collage de JSON (« Import JSON Express ») | `team` | 💀 | — | — (formulaires de CA-05 et CA-12) | `inventaire/catalog.md#A` (« Import JSON Express ») |
| CA-10 | Lister les fiches d'un cours (page dédiée + modale de création) | tout connecté | ⚠️ | `courses`, `essentials` | `GET /courses/:course_id/essentials` | `inventaire/catalog.md#A` (« Lister les fiches d'un cours ») |
| CA-11 | Consulter une fiche, avec la progression de l'élève sur ses exercices | tout connecté | ✅ | `essentials`, `courses`, `exercises`, `exercise_sessions`, `exercise_badges`, `action_text_rich_texts` | `GET /essentials/:id` | `inventaire/catalog.md#A` (« Consulter une fiche ») |
| CA-12 | Créer une fiche dans un cours | tout connecté (aucun contrôle de rôle) | ❌ | `essentials` | `GET /courses/:course_id/essentials/new`, `POST /courses/:course_id/essentials` | `inventaire/catalog.md#A` (« Créer une fiche ») |
| CA-13 | Modifier une fiche | tout connecté (aucun contrôle de rôle) | ❌ | `essentials` | `GET /essentials/:id/edit`, `PATCH\|PUT /essentials/:id` | `inventaire/catalog.md#A` (« Modifier une fiche ») |
| CA-14 | Supprimer une fiche (cascade) | tout connecté (aucun contrôle de rôle) | ✅ | `essentials`, `exercises`, `questions`, `answers`, `knowledge_gaps`, `classroom_assignments` | `DELETE /essentials/:id` | `inventaire/catalog.md#A` (« Supprimer une fiche ») |
| CA-15 | Importer des fiches dans un cours depuis un JSON (synchrone) | tout connecté (aucun contrôle de rôle) | 💀 | `essentials` | `POST /courses/:course_id/essentials/import_json` | `inventaire/catalog.md#A` (« Importer des fiches ») |
| CA-16 | Lister les niveaux | tout connecté | ✅ | `levels`, `level_series` | `GET /levels` | `inventaire/catalog.md#B` (« Gérer les niveaux ») |
| CA-17 | Consulter l'« Espace Niveau » (séries associées + carrousel des cours) | tout connecté | ⚠️ | `levels`, `level_series`, `series`, `courses` | `GET /levels/:id` | `inventaire/catalog.md#B` (« Gérer les niveaux ») |
| CA-18 | Créer, modifier, supprimer un niveau | `team` | ⚠️ | `levels`, `level_series`, `courses`, `classrooms` (cascade) | `GET /new-level`, `POST /levels`, `GET /levels/:id/edit`, `PATCH\|PUT /levels/:id`, `DELETE /levels/:id` | `inventaire/catalog.md#B` (« Gérer les niveaux ») |
| CA-19 | Associer des séries à un niveau (cases à cocher du formulaire niveau) | `team` | ✅ | `level_series` | `POST /levels`, `PATCH /levels/:id` | `inventaire/catalog.md#B` (« Gérer les niveaux ») |
| CA-20 | Lister les matières | tout connecté | ⚠️ | `materials` | `GET /materials` | `inventaire/catalog.md#B` (« Gérer les matières ») |
| CA-21 | Consulter une page matière (carrousel « Mes Cours ») | tout connecté | ⚠️ | `materials`, `courses` | `GET /materials/:id` | `inventaire/catalog.md#B` (« Gérer les matières ») |
| CA-22 | Créer, modifier, supprimer une matière | `team` | ⚠️ | `materials`, `courses`, `teachers` (nullify) | `GET /new-material`, `POST /materials`, `GET /materials/:id/edit`, `PATCH\|PUT /materials/:id`, `DELETE /materials/:id` | `inventaire/catalog.md#B` (« Gérer les matières ») |
| CA-23 | Lister et consulter les séries (pages dédiées) | `team` | ❌ | `series` | `GET /series`, `GET /series/:id` | `inventaire/catalog.md#B` (« Gérer les séries ») |
| CA-24 | Créer, modifier, supprimer une série | `team` | ⚠️ | `series`, `level_series`, `courses` et `classrooms` (nullify) | `GET /new-series`, `POST /series`, `GET /series/:id/edit`, `PATCH\|PUT /series/:id`, `DELETE /series/:id` | `inventaire/catalog.md#B` (« Gérer les séries ») |
| CA-25 | Administrer la taxonomie depuis l'onglet « Setup » de l'espace équipe (listes + formulaires en turbo-frame) | `team` | ⚠️ | `levels`, `materials`, `series` | `GET /teams/setup` (écran couvert par la mission n°5, `TR`) | nouveau |
| CA-26 | Reconnaître la matière d'un cours à son icône et sa couleur (carte-vitrine UDR-0001) | tout connecté | ✅ | `materials` | toutes les pages qui rendent `components/courses/_course_card` | nouveau |
| CA-27 | Affecter un cours à ses classes depuis la page du cours | `teacher` | 💀 | `classroom_assignments` | `GET /courses/:id` (pied de carte) | nouveau |
| CA-28 | Valider collaborativement une fiche ou un exercice (exactitude / conformité, ADR-0011) | `teacher` | 💀 | aucune (`community_validations` n'existe pas ; `essentials.validated_at` / `validated_by` jamais écrites) | aucune | `inventaire/catalog.md#D` |
| CA-29 | Voir le bandeau « Validation collaborative — Conforme au programme » sur chaque fiche et chaque exercice | tout connecté, élèves compris | ⚠️ | — | `GET /essentials/:id`, `GET /exercises/:id` | nouveau (corrige `catalog.md#D`) |

**Total : 29 features**, dont **5 absentes de l'inventaire** (CA-02, CA-25, CA-26, CA-27, CA-29 — fiches complètes en §2). CA-03 et CA-19 étaient décrites dans l'inventaire comme des règles d'autres features ; elles reçoivent ici un identifiant propre pour la traçabilité.

---

## 2. Features absentes de l'inventaire

### CA-02 — Filtrer le catalogue par niveau ou matière

- **Acteur** : tout utilisateur connecté.
- **Parcours** : `GET /courses?level_id=<id>&material_id=<id>`. **Aucun contrôle de filtre dans la page** : `@levels` et `@materials` sont chargés (`app/controllers/catalog/courses_controller.rb:47-49`) mais `app/views/catalog/courses/index.html.erb` ne les utilise nulle part. Deux liens seulement construisent l'URL filtrée :
  - « Voir tout » sur la page matière, visible pour `team` uniquement (`app/views/catalog/materials/show.html.erb:62-66`) — `level_id` y vaut toujours `nil`, car `@student_level` n'est jamais affecté ;
  - le lien de la page niveau réservé à l'enseignant (`app/views/catalog/levels/show.html.erb:77-78`), **jamais affiché**, car `@teacher_material` n'est jamais affecté par `LevelsController#show`.
- **Règles métier** :
  - Les filtres **fonctionnent** : `params.permit(:level_id, :material_id).to_h` (`courses_controller.rb:42`) renvoie un `ActiveSupport::HashWithIndifferentAccess` (vérifié par exécution : `ActionController::Parameters.new("level_id" => "1").permit(:level_id).to_h[:level_id]` → `"1"`). `Repositories::Catalog::CourseRepository#find_all` lit donc bien `filters[:level_id]` (`app/infrastructure/repositories/catalog/course_repository.rb:19-20`).
  - Les filtres s'ajoutent au scope `published` (`course_repository.rb:18`) : un brouillon reste invisible même filtré.
  - Le filtre `series_id` existe (`course_repository.rb:21`, sémantique `series_id IN (NULL, valeur)` — `app/infrastructure/orm/course.rb:38`) mais n'est pas autorisé par le `permit` : inatteignable.
- **Données** : `courses` (+ `levels`, `materials`, `series` en lecture).
- **État** : ⚠️ — le filtrage marche, mais n'a quasiment aucun point d'entrée dans l'UI.
- **À refaire différemment** : ne pas charger des listes de filtres qu'aucune vue n'affiche ; ne pas laisser un filtre exister côté dépôt sans qu'aucun appelant puisse l'alimenter (`series_id`).

### CA-25 — Administrer la taxonomie depuis l'onglet « Setup » de l'espace équipe

- **Acteur** : `team` (`before_action :authenticate_team!`, `app/controllers/teams/dashboard_controller.rb:12`).
- **Parcours** : `GET /teams/setup` → onglets niveaux, séries, matières, DRENA, messages (`app/views/teams/dashboard/setup/_levels.html.erb`, `_series.html.erb`, `_materials.html.erb`). Chaque onglet liste les éléments et ouvre le formulaire de création dans un turbo-frame (`new_level_path` → frame `new_level`, `_levels.html.erb:10` ; `new_series_path` → frame `new_series`, `_series.html.erb:10` ; `new_material_path` → frame `dom_id(Entities::Material.new)`, `_materials.html.erb:10`). Les boutons « Annuler » / « Fermer » des formulaires série renvoient à `teams_setup_path(tab: 'series')` (`app/views/catalog/series/_form.html.erb:28`). **C'est le seul endroit de l'application qui liste les séries** (voir CA-23).
- **Règles métier** :
  - Les listes viennent de `UseCases::Identity::GetTeamsDashboard#get_setup_data` (`app/domain/use_cases/identity/get_teams_dashboard.rb:57-71`), qui lit `LevelRepository#all_levels`, `MaterialRepository#all_materials`, `SeriesRepository#all_series` — **trois caches de 12 h** (`catalog/levels/all`, `catalog/materials/all`, `catalog/series/all`), distincts des caches `catalog_levels` / `catalog_materials` / `catalog_series` utilisés par `/levels`, `/materials` et les formulaires (voir §3, C-09).
  - Les DRENA de l'onglet sont lues directement en ORM (`dashboard_controller.rb:72`) — hors périmètre, signalé seulement.
- **Données** : `levels`, `level_series`, `materials`, `series`.
- **État** : ⚠️ — le parcours nominal en Turbo marche (les `create.turbo_stream.erb` existent pour niveaux, séries, matières) ; les redirections HTML de secours de la série pointent vers une page sans template (CA-23).
- **À refaire différemment** : ne pas faire d'un tableau de bord le seul lieu de consultation d'une ressource ; ne pas servir la même liste par deux caches concurrents.

### CA-26 — Reconnaître la matière d'un cours à son icône et sa couleur

- **Acteur** : tout utilisateur connecté.
- **Parcours** : toute carte de cours rendue par `app/views/components/courses/_course_card.html.erb` — catalogue (`catalog/courses/_course.html.erb:5`), page niveau, page matière, fil équipe (`teams/feed/content/_courses.html.erb`), onglet académie de l'équipe, pages classe (`classroom/classrooms/show.html.erb`, `schoolstaff/classrooms/show.html.erb`).
- **Règles métier** :
  - **Couleur** : `subject_palette_for(course.material.name)` (`_course_card.html.erb:9`) cherche la **première** expression régulière de `SUBJECT_PALETTE` qui correspond au **nom** de la matière (`app/helpers/application_helper.rb:294-329`), sinon `SUBJECT_FALLBACK` (ardoise). Ce n'est **pas** la colonne `materials.category`.
  - **Icône** : `material_icon(course.material)` (`application_helper.rb:120-141`) teste un **autre** jeu d'expressions sur `shortname` (ou `name` à défaut), en minuscules : `math`, `physique|chim|pc`, `svt`, `philo`, `fran`, `histoire|géographie|hg`, `edhc|civique|démocratie` ; sinon une initiale.
  - Couleurs réelles : mathématiques bleu, français ambre, histoire-géo vert, SVT émeraude, **physique-chimie violet** (`application_helper.rb:303-304`), anglais ciel, espagnol rose, EPS orange, arts rose vif, civique indigo, philosophie violet, économie sarcelle, informatique cyan.
  - Chip « niveau + série », nom de la matière, titre en `font-extrabold text-slate-900`, aperçu du sous-titre (ou du contenu) sur 2 lignes, « Ouvrir le cours ». Survol : `-translate-y-1.5`, ombre renforcée, badge `scale-110`. Toute la carte est un lien.
  - Les essentiels ne sont **pas** affichés sur la carte (conforme UDR-0001).
- **Données** : `materials.name`, `materials.shortname`.
- **État** : ✅
- **À refaire différemment** : ne pas dériver l'identité visuelle d'une matière de deux tables d'expressions régulières indépendantes sur du texte libre ; `category` existe et n'y participe pas.

### CA-27 — Affecter un cours à ses classes depuis la page du cours

- **Acteur** : `teacher`.
- **Parcours** : prévu en pied de carte sur `GET /courses/:id` : un bouton par classe de l'enseignant (`app/views/catalog/courses/show.html.erb:68-81`, partiel `classroom/classroom_courses/_classroom_button`).
- **Règles métier** : la condition d'affichage est `teacher? && defined?(@teacher_classrooms) && @teacher_classrooms.present?` (`show.html.erb:68`). **Aucun contrôleur n'affecte `@teacher_classrooms`** (`grep -rn "@teacher_classrooms" app/controllers` → aucun résultat).
- **Données** : `classroom_assignments` (via le contexte classroom).
- **État** : 💀 — le pied de carte n'est jamais rendu. L'affectation reste possible par les écrans du contexte classroom (mission n°2).
- **À refaire différemment** : ne pas conditionner une action métier à une variable d'instance que rien ne renseigne ; décider explicitement si l'affectation se fait depuis le catalogue ou depuis la classe.

### CA-29 — Voir le bandeau « Validation collaborative — Conforme au programme »

- **Acteur** : **tout** utilisateur connecté, élèves compris.
- **Parcours** : sur chaque fiche (`app/views/catalog/essentials/show.html.erb:66`) et chaque exercice (`app/views/assessment/exercises/show.html.erb:157`), le partiel `community_validations/_card` est rendu **sans condition**. Il affiche « Validation collaborative », une pastille « Enseignants » et la mention **« Conforme au programme »** (`app/views/community_validations/_card.html.erb`).
- **Règles métier** : aucune — le texte est statique. Le seul appel conditionné (`components/_exercise_card.html.erb:73`, via `show_community_validation?`) renvoie toujours `false` (`application_helper.rb:80-84`).
- **Données** : aucune.
- **État** : ⚠️ — le rendu fonctionne, mais l'information affichée est fausse : aucun contenu n'a jamais été validé (CA-28 est 💀).
- **À refaire différemment** : n'afficher aucune garantie de qualité que le système ne sait pas produire.

---

## 3. Corrections de l'inventaire

### Sondage des règles chiffrées de `catalog.md`

| # | Règle de l'inventaire | Verdict | Preuve |
|---|---|---|---|
| S-1 | `levels.name` max 20 en base, formulaire « Maximum 10 caractères » | ✅ exacte | `db/schema.rb:250` ; `app/views/catalog/levels/_form.html.erb:15` |
| S-2 | `materials.name` max 25 en base, formulaire « Maximum 50 caractères » | ✅ exacte | `db/schema.rb:264` ; `app/views/catalog/materials/_form.html.erb:15` |
| S-3 | Scope `published` = `"publié"` ou `"published"` | ✅ exacte | `app/infrastructure/orm/course.rb:36` |
| S-4 | Import : `status` défaut `"draft"`, `exercise_type` défaut `"fixation"`, `published` forcé à `true`, `question_type` défaut `"single_choice"`, `is_correct` défaut `false` | ✅ exacte | `course_repository.rb:130`, `:172`, `:178`, `:193`, `:187` |
| S-5 | `essentials.name` max 150, unique `(course_id, name)` | ✅ exacte | `db/schema.rb:147`, `:153` |
| S-6 | `shortname` obligatoire, max 10 | ✅ exacte | `app/domain/dtos/material_dto.rb:22` ; `db/schema.rb:266` |
| S-7 | Cache 12 h, invalidation sur le **nouveau** nom/slug d'un niveau | ✅ exacte | `level_repository.rb:57-60` (lit `record.slug` / `record.name` après `save`) |
| S-8 | `category` défaut `other` | ❌ incomplète | voir C-07 |
| S-9 | Filtres `level_id` / `material_id` « silencieusement ignorés » | ❌ fausse | voir C-01 |
| S-10 | `friendly_id_slugs` alimenté pour toutes les tables | ❌ fausse | voir C-11 |

### Corrections et compléments

| # | L'inventaire dit | Constat vérifié | Preuve |
|---|---|---|---|
| C-01 | Les filtres `level_id`, `material_id` de `/courses` sont ignorés (hash à clés String contre clés Symbol). | **Faux.** `Parameters#to_h` renvoie un `HashWithIndifferentAccess` ; les filtres s'appliquent (vérifié par exécution). Le vrai défaut : aucun contrôle de filtre dans la page (CA-02). | `courses_controller.rb:42` ; `course_repository.rb:19-20` ; `catalog/courses/index.html.erb` (aucune référence à `@levels` / `@materials`) |
| C-02 | Créer un cours : « Série facultative ». | **La série n'est jamais sélectionnable** à la création manuelle : `set_collections` affecte `@series = []`. Le select n'offre que « Toutes les séries ». Seul l'import peut rattacher un cours à une série. | `courses_controller.rb:193` ; `catalog/courses/_form.html.erb:119-123` |
| C-03 | Créer un cours : parcours `GET /courses/new`. | **Aucun point d'entrée UI.** `new_course_path` n'apparaît que dans `catalog/courses/_empty_state.html.erb:15`, rendu uniquement par `destroy.turbo_stream.erb:9-11` sous la condition `@courses_empty`, jamais affectée. La page vide de `/courses` rend un autre partiel (`shared/empty_state`, `index.html.erb:24`). | `grep -rn "new_course_path" app` |
| C-04 | Le nom de cours est unique en base ; l'import « échoue là où il croit réussir ». | Plus grave : **aucune validation d'unicité côté modèle**. Un doublon de nom (création manuelle) lève `ActiveRecord::RecordNotUnique` → erreur 500, pas un message de formulaire. À l'import, l'exception n'est pas capturée dans la transaction globale : **tout le fichier est annulé** et le job échoue. Même comportement pour un doublon `(course_id, name)` de fiche, en saisie comme dans un JSON. | `orm/course.rb:32` ; `orm/essential.rb:31` ; `course_repository.rb:123`, `:200` |
| C-05 | Import : seul un `create!` de taxonomie annule tout le fichier. | Deux autres causes : un `exercise_type` hors `fixation`/`evaluation` ou un `question_type` hors des 4 valeurs lève `ArgumentError` à l'affectation d'enum → **tout le fichier annulé**. Un nom de niveau > 20 ou de matière > 25 caractères fait de même (erreur PostgreSQL de longueur). | `orm/exercise.rb:33` ; `orm/question.rb:25-30` ; `course_repository.rb:132-133`, `:172`, `:193` |
| C-06 | Import : l'échec d'un cours est collecté sans `raise`. | Exact, et **les niveaux, matières, séries et liens `level_series` créés à la volée pour ce cours restent en base** : la transaction se termine normalement. Le résultat (`imported_count`, `skipped_count`, `errors`) est jeté par le job. Un JSON malformé lève `JSON::ParserError`, non capturé : le job échoue, le fichier est supprimé. | `course_repository.rb:132-141`, `:200-205` ; `app/jobs/import_courses_json_job.rb:18`, `:22`, `:24` |
| C-07 | `category` défaut `other`. | **Faux pour une matière créée à la main** : `save_material` affecte `category: material_entity.category`, qui vaut `nil` (aucun champ de formulaire) → la colonne reçoit `NULL`, le défaut SQL `2` ne s'applique pas. Seules les matières créées par import (`Orm::Material.create!(name:)`) reçoivent `other`. | `material_repository.rb:43` ; `materials_controller.rb:59` ; `course_repository.rb:133` |
| C-08 | `category` « sert pourtant à la palette de couleurs des cartes de cours ». | **Faux.** La palette dépend du **nom** de la matière (expressions régulières) ; `category` ne sert qu'aux filtres « Littérature / Sciences » des sujets d'examen (contexte assessment). | `application_helper.rb:327-329` ; `_course_card.html.erb:9` ; `students/exam_subjects/index.html.erb:95-98` |
| C-09 | Matières : « cache 12 h avec la même faiblesse d'invalidation que les niveaux » ; deux jeux de clés. | Pire : la clé `catalog_materials` **n'est jamais invalidée**. Une matière créée ou renommée n'apparaît ni dans `/materials` ni dans le select du formulaire de cours pendant 12 h (`solid_cache_store` en production). Il y a en outre **trois** familles de clés : `catalog_*` (lecture formulaires), `catalog/*/all` (repositories) et `catalog/*/{slug,name,id}/…`. | `app/infrastructure/queries/catalog_form_query.rb:26` ; `material_repository.rb:47-49`, `:60-62` ; `config/environments/production.rb:50` |
| C-10 | Supprimer un niveau : cascade sur cours et classes. | Exact au niveau ORM, **et doublé en base** : clés étrangères `on_delete: :cascade` de `courses` vers `levels` et `materials`, d'`essentials` vers `courses`, d'`exercises` vers `essentials`, de `knowledge_gaps` vers `essentials`. Un `DELETE` SQL direct détruit la même descendance. | `db/schema.rb:579-580`, `:583`, `:588`, `:590` |
| C-11 | `friendly_id_slugs` : « historique alimenté pour toutes les tables ci-dessus ; résolution des anciennes URL ». | **Faux.** `Sluggable` déclare `friendly_id :name, use: :slugged`, sans module `:history` ; aucun modèle du dépôt n'utilise `:history`. La table n'est jamais écrite ; après renommage, l'ancienne URL renvoie « introuvable ». De plus, les recherches passent par `find_by(slug:)`, pas par `.friendly`. | `app/models/concerns/sluggable.rb:20` ; `grep -rn history app/infrastructure/orm app/models` → vide ; `catalog_form_query.rb:38` |
| C-12 | Séries : `update` « lit un champ inexistant → 500 » ; même défaut pour `create`. | `create` : exact (`@series_item = result.series` → `nil`, puis `nil.errors`). `update` : **pas de 500** — `result.series || Entities::Series.new(dto.to_h)` retombe sur une entité neuve ; mais cette entité n'a pas d'`id`, donc le formulaire réaffiché poste vers `series_index_path` : **le renvoi crée une nouvelle série** au lieu de modifier. Suppression Turbo : `turbo_stream.remove Entities::Series.new(id: params[:id])` cible `series_<slug>`, alors que la carte porte `series_<id>` : la carte reste affichée. | `series_controller.rb:48`, `:72` ; `catalog/series/_form.html.erb:5` ; `catalog/series/destroy.turbo_stream.erb:3` ; `catalog/series/_series.html.erb:5`, `:19` |
| C-13 | Validation collaborative : « deux partiels décoratifs ». | Le partiel `_card` est rendu **sans condition, à tous, élèves compris**, sur chaque fiche et chaque exercice, avec la mention « Conforme au programme » (CA-29). | `essentials/show.html.erb:66` ; `assessment/exercises/show.html.erb:157` |
| C-14 | Lister les fiches : bouton « Nouvelle Habilité » visible pour un enseignant. | La page `/courses/:course_id/essentials` **n'a aucun lien entrant** (`course_essentials_path` n'apparaît que comme URL de formulaire). Le seul bouton de création visible y est réservé à `current_teacher` ; la page cours (`show`) n'offre **aucune** création de fiche à `team`. Dans l'UI, seul un enseignant qui connaît l'URL peut tenter de créer une fiche. | `essentials/index.html.erb:18` ; `essentials/_empty_state.html.erb:17` ; `essentials/_form.html.erb:7` ; `courses/show.html.erb:86-105` |
| C-15 | Limites de longueur fausses dans les formulaires. | Complément : aucune validation de longueur côté modèle pour `levels.name` (20), `materials.name` (25) et `courses.subtitle` (150). Un dépassement produit une erreur PostgreSQL → 500, pas un message. | `orm/level.rb:28` ; `orm/material.rb:27` ; `orm/course.rb:32-33` ; `db/schema.rb:119`, `:250`, `:264` |
| C-16 | `courses.essentials_count` n'est jamais mis à jour ; « toute UI qui l'affiche affiche 0 ». | Confirmé côté modèle (`belongs_to :course` sans `counter_cache`). Une vue élève l'affiche (`students/feed/content/_courses.html.erb:70`) ; `StudentClassroomQuery` le recalcule en SQL (`student_classroom_query.rb:23`), mais la source du fil élève n'a pas été tracée (§6). | `orm/essential.rb:20` |
| C-17 | Consulter un cours : « menu Modifier / Supprimer réservé à `team?` ». | Exact. Complément : le pied de carte d'affectation aux classes pour l'enseignant n'est jamais rendu (CA-27). | `courses/show.html.erb:68` |
| C-18 | Créer une fiche : « en Turbo Stream, l'utilisateur voit une erreur ». | Confirmé et précisé : en HTML, `result.course` renvoie `nil` (OpenStruct) → `nil.slug` ; en Turbo Stream, `@course` n'est pas affecté dans la branche de succès → `nil.essentials` dans le gabarit. La fiche est déjà enregistrée dans les deux cas. | `essentials_controller.rb:94` ; `essentials/create.turbo_stream.erb:8` |
| C-19 | Modifier un cours / une fiche : la sauvegarde lève avant d'écrire. | Confirmé et localisé : `ManageResource#find_entity` relit via `CourseRepository`, qui renvoie `Entities::Catalog::Course` (sans `status`, `level_id`…) ou `Entities::Catalog::Essential` (sans `subtitle`, `course_id`…) ; `save_course` appelle `course_entity.status` et `save_essential` appelle `essential_entity.subtitle` → `NoMethodError` avant tout `save`. | `manage_resource.rb:81-87` ; `course_repository.rb:26-29`, `:40`, `:82`, `:270-290` ; `app/domain/entities/catalog/course.rb:16` ; `app/domain/entities/catalog/essential.rb:15` |

---

## 4. Écarts avec les décisions

| Sujet | Source A dit | Source B dit | Qui devrait trancher |
|---|---|---|---|
| Lecture du catalogue | **ADR-0022 §2.C et §3** : les contrôleurs appellent `UseCases::Catalog::BrowseCatalog` et `ViewCourse` ; ils ne font plus de requêtes. | **ADR-0012 §3.1** : les lectures sortent du domaine, les contrôleurs appellent directement des Queries, les use cases « passe-plats » sont supprimés. Le code fait les deux : `GetCatalog` pour `/courses` (`courses_controller.rb:36`), `Queries::CatalogQuery` pour `show` (`:55`). | ADR remplaçant explicitement l'un des deux (contradiction ADR contre ADR) |
| Import de cours | **ADR-0012 §3.3** : `UseCases::ImportCatalogData` + `Strategies::[Resource]ImportStrategy`, cours compris. | **ADR-0020 §2.1** : l'import de cours passe par une méthode de repository dédiée (`bulk_import_courses`). Le code suit ADR-0020 ; `CourseImportStrategy` est morte (aucun appelant). | ADR remplaçant explicitement §3.3 de l'ADR-0012 pour les cours |
| Technique d'insertion en masse | **ADR-0020 §2.1** : `insert_all!` / `upsert_all` pour `ImportCoursesJsonJob`. | Code : aucune `insert_all` dans le catalogue ; construction d'un arbre imbriqué puis `course.save` cours par cours, callbacks compris (`course_repository.rb:150-200`). `insert_all!` n'existe que dans `classroom_repository.rb`. | Mise à jour de l'ADR-0020 (constat « appliqué » faux pour les cours) |
| Forme des entités du catalogue | **ADR-0022 §2.A** : `Course` porte `status`, `published_at` et les références ; `Essential` porte `course_id`, `validated_at`. | `Entities::Catalog::Course` n'a ni `status`, ni `published_at`, ni `*_id` ; `Entities::Catalog::Essential` n'a que `id`, `name`, `slug` (`entities/catalog/course.rb:16`, `essential.rb:15`). Des entités `Entities::Course` / `Entities::Essential` à la racine, complètes, coexistent — cause des bugs CA-06 et CA-13. | ADR-0022 (à compléter ou remplacer) |
| Contrats des ports | **ADR-0022 §2.B** : `find_by_slug`, `find_published`, `save` ; `TaxonomyRepositoryPort#all_levels`, `#materials_for_level`, `#series_for_level`. | `Ports::Catalog::CourseRepositoryPort` déclare `find_all`, `find_by_slug`, `save`, `delete` qui lèvent `NotImplementedError` ; l'implémentation expose `find_course_by_slug`, `save_course`… (`course_repository.rb:17-61`). `TaxonomyRepositoryPort` expose `get_all_levels`, `get_series_for_level`, `get_all_materials`, sans `materials_for_level`. | ADR-0022 |
| Règle de visibilité d'un cours | **ADR-0022 §3** : la vérification du statut `published_at` appartient à l'entité `Course`. | Le filtre vit dans un scope ORM sur `status` (`orm/course.rb:36`) ; `published_at` n'est jamais écrit ; seules `/courses` filtre (cours, niveau, matière non filtrés — `catalog_query.rb:23-69`). | ADR (vocabulaire des statuts + portée de la visibilité) |
| ViewObjects | **ADR-0012 §3.1** (statut « Accepté — *appliqué* ») : les Queries retournent des `ViewObjects` fortement typés. | Aucun `ViewObjects::` dans `app/` ; `CatalogQuery` renvoie des `OpenStruct` contenant des enregistrements ActiveRecord passés tels quels aux vues (`catalog_query.rb:27-40`). | Mise à jour du statut de l'ADR-0012 |
| Nom du CRUD générique | **ADR-0012 §3.2** : `UseCases::ManageCatalogResource`. | Code : `UseCases::Catalog::ManageResource` (`manage_resource.rb:16-18`). | Mise à jour de l'ADR-0012 |
| Affectation par sac d'attributs | [`securite.md`](../securite.md) #8 : « le domaine n'accepte jamais un sac d'attributs ». | `ManageResource#execute_update` fait `entity.send("#{key}=", value) if entity.respond_to?` pour toute ressource du catalogue (`manage_resource.rb:44-46`) — même motif, non cité par `securite.md`. | Registre des contradictions (le constat de `securite.md` est à étendre) |
| Autorisation des fiches | `securite.md` liste les trous d'autorisation bloquants ; `catalog.md` règle 11 constate que tout compte connecté peut créer, modifier, supprimer, importer des fiches. | `securite.md` ne mentionne pas ce trou (`grep -n -i essential securite.md` → vide) ; `EssentialsController` n'a que `authenticate_user!` (`essentials_controller.rb:12`). | ADR du modèle d'autorisation (registre des décisions de fondation) |
| Validation collaborative | **ADR-0011** (Accepté) est rédigé au passé : « nous avons isolé », « nous avons utilisé une relation `validatable_type` », « s'intègre parfaitement aux `Orm::Essential` et `Orm::Exercise` actuels ». | Aucune table, entité, use case, contrôleur ni route (`catalog.md#D`, vérifié : `grep -rn CommunityValidation app` → partiels uniquement) ; un bandeau affirme pourtant « Conforme au programme » (CA-29). | ADR-0011 (statut à revoir) |
| Namespace de la validation collaborative | **ADR-0011 §2** : `Entities::CommunityValidation`, `SubmitCommunityValidation` à la racine. | **conventions.md:57** : tout est namespacé par contexte borné ; un fichier à la racine d'`entities/` est du legacy. | ADR remplaçant l'ADR-0011 ou conventions (ADR contre conventions) |
| « Enseignants certifiés » | **ADR-0011 §1** : seuls des enseignants **certifiés** valident. | Le glossaire ne définit aucune certification ; aucune colonne ni rôle ne la porte (`teachers` sans attribut de certification). | ADR + entrée de glossaire |
| Nom de l'`Essential` à l'écran | **Glossaire §3** : « Fiche essentielle ». | UI : « Habilité » (sic, `essentials/new.html.erb:15`, `essentials_controller.rb:60`), « Habiletés » (`courses/show.html.erb:89`) ; **ADR-0022** : « Notions clés » ; **UDR-0001** : « essentiels (habiletés) » ; `feature_listing.md:21-22` : « habilletés ». | UDR de vocabulaire + glossaire |
| Propriété de la taxonomie et du contenu | **Glossaire §1** : `Team` « possède DRENA, niveaux, matières, écoles, exercices ». UI du statut `draft` : « Visible uniquement par vous » (`courses_helper.rb`, `status_description`). | `levels.team_id` et `materials.team_id` ne sont jamais renseignés ; `series`, `courses`, `essentials` n'ont pas de propriétaire ; le `team_id` de l'import est ignoré (`import_courses_json_job.rb:14`). | ADR (modèle de propriété du contenu) |
| Exemple de niveau | **Glossaire §2** : « 6ème, 3ème, Terminale ». | Le générateur de classes attend exactement `Tle` (`catalog.md#C`) ; l'exemple d'import affiché écrit `"Tle"` (`courses/_import_form.html.erb:41`). | Glossaire / référentiel de taxonomie (signalé pour la mission n°2) |
| I18n | **conventions.md:12** et CLAUDE.md règle 3 : l'interface passe par `t(".key")`. | Zéro appel `t(".…")` dans `app/views/catalog/{courses,essentials,levels,materials,series}` ; tous les messages flash sont en dur dans les contrôleurs. | Constat pour la vague (pas de décision nouvelle : la convention s'applique) |
| Doublons d'entités et alias | **conventions.md:57** ; ADR-0014 (namespaces). | Les contrôleurs du catalogue instancient les entités **racine** (`Entities::Course`, `Entities::Level`…) et un alias `Repositories::CourseRepository` défini au boot (`config/initializers/repositories_aliases.rb:12`, utilisé `courses_controller.rb:37`). | Constat (legacy déjà déclaré dans `conventions.md:236`) |
| Préchargement des essentiels sur la liste | **UDR-0001 §4** : le contrôleur n'a plus besoin de précharger `.essentials` pour l'index. | `find_all` fait `includes(:essentials)` et mappe chaque essentiel (`course_repository.rb:18`, `:280`). | UDR-0001 (constat « conséquence » non appliqué) |
| Réutilisation de la carte de cours | **UDR-0001 §3-4** : `components/courses/_course_card` est réutilisé **partout** où un cours est listé. | Fil élève, page classe élève et fil enseignant ont leur propre balisage (`students/feed/content/_courses.html.erb`, `students/classroom/show.html.erb`, `teachers/feed/content/_courses.html.erb`). | UDR-0001 |
| Contenu de la carte | **UDR-0001 §3** : « La carte est une vitrine : titre + badge de matière. » | La carte affiche aussi niveau + série, nom de la matière, aperçu du texte et « Ouvrir le cours » (`_course_card.html.erb:24-59`). L'UDR n'interdit explicitement que la liste des essentiels : l'écart est d'interprétation. | UDR-0001 (préciser) |
| Couleurs de matière | **UDR-0001 §2** : « Vert pour SVT, Bleu pour Physique ». | Physique-chimie en violet (`application_helper.rb:303-304`) ; le bleu est aux mathématiques (`:295-296`). | UDR-0001 |
| DRENA et écoles dans `Catalog::` | **ADR-0023** : l'organisation scolaire est un contexte à part. | Les routes DRENA / écoles sont dans `scope module: "catalog"` (`config/routes.rb:50-63`). Déjà relevé par `catalog.md` ; hors périmètre, signalé seulement. | Mission n°2 / ADR-0023 |
| Tables de liaison classe ↔ contenu | `feature_listing.md:23-24` : tables `classroom_courses` et `classroom_essentials`. | **ADR-0007** et glossaire §5 : une table unique `classroom_assignments`. Signalé seulement (mission n°2). | Mise à jour de `feature_listing.md` |

---

## 5. Couverture

### Tables

| Table | Rattachée à | Remarque |
|---|---|---|
| `courses` | CA-01 à CA-08, CA-17, CA-21, CA-27 | `published_at`, `import_data`, `essentials_count` jamais écrits par le catalogue (`catalog.md` règles 9 et 14, vérifié) |
| `essentials` | CA-04, CA-08, CA-10 à CA-15 | `validated_at`, `validated_by`, `import_data` jamais écrits (CA-28) |
| `levels` | CA-01, CA-08, CA-16 à CA-19, CA-25 | `team_id` jamais écrit |
| `series` | CA-08, CA-17, CA-19, CA-23 à CA-25 | — |
| `level_series` | CA-08, CA-17, CA-19 | — |
| `materials` | CA-01, CA-08, CA-20 à CA-22, CA-25, CA-26 | `team_id` jamais écrit ; `category` à `NULL` en saisie manuelle (C-07) |
| `friendly_id_slugs` | **morte** | Jamais écrite : aucun modèle n'utilise `:history` (`sluggable.rb:20`, C-11). Couverte par aucun ID. |
| `action_text_rich_texts` | CA-04, CA-05, CA-08, CA-11 | Contenu riche de `courses.content` et `essentials.content` (`orm/course.rb:24`, `orm/essential.rb:22`) |
| `active_storage_attachments` / `_blobs` (pour `image_cover` de `courses` et `essentials`) | **mort pour le catalogue** | `has_one_attached :image_cover` déclaré (`orm/course.rb:25`, `orm/essential.rb:23`) mais `image_cover` absent des `permit` (`courses_controller.rb:198`, `essentials_controller.rb:190`) et de l'import ; les vues affichent un placeholder (`courses/show.html.erb:49-55`). Autres usages d'Active Storage : hors périmètre. |
| `exercises`, `questions`, `answers` | CA-08 (écriture par import), CA-07 / CA-14 (cascade) | Propriétaire : mission n°4 (`AS`) |
| `exercise_sessions`, `exercise_badges` | CA-11 (lecture de la progression) | Propriétaire : mission n°4 |
| `knowledge_gaps` | CA-07, CA-14, CA-18, CA-22 (cascade) | Propriétaire : mission n°4 |
| `classroom_assignments` | CA-07, CA-14 (cascade), CA-27 | Propriétaire : mission n°2 |
| `classrooms` | CA-18 (cascade à la suppression d'un niveau), CA-24 (nullify) | Propriétaire : mission n°2 |
| `teachers` | CA-22 (`material_id` remis à `NULL`), CA-17 (filtre par matière) | Propriétaire : mission n°1 |
| `community_validations` | **n'existe pas** | CA-28 |

### Routes (`config/routes.rb:29-73`, bloc `scope module: "catalog"`, hors DRENA/écoles)

| Route | ID |
|---|---|
| `GET /courses` | CA-01, CA-02 |
| `GET /courses` (format `turbo_stream`, `?page=`) | CA-03 — 💀 : `@pagy = OpenStruct.new(next: nil)` (`courses_controller.rb:51`), le lien n'est jamais rendu |
| `POST /courses/import_json` | CA-08 |
| `GET /courses/new`, `POST /courses` | CA-05 |
| `GET /courses/:id` | CA-04, CA-27 |
| `GET /courses/:id/edit`, `PATCH /courses/:id`, `PUT /courses/:id` | CA-06 |
| `DELETE /courses/:id` | CA-07 |
| `GET /courses/:course_id/essentials` | CA-10 |
| `GET /courses/:course_id/essentials/new`, `POST /courses/:course_id/essentials` | CA-12 |
| `POST /courses/:course_id/essentials/import_json` | CA-15 |
| `GET /essentials/:id` | CA-11, CA-29 |
| `GET /essentials/:id/edit`, `PATCH /essentials/:id`, `PUT /essentials/:id` | CA-13 |
| `DELETE /essentials/:id` | CA-14 |
| `/essentials/:essential_id/exercises…`, `POST …/exercises/import_content_engine`, `…/exercise_sessions` | hors périmètre — contrôleurs `/assessment/…` (mission n°4) |
| `GET /levels` | CA-16 |
| `GET /levels/:id` | CA-17 |
| `GET /new-level`, `POST /levels`, `GET /levels/:id/edit`, `PATCH\|PUT /levels/:id`, `DELETE /levels/:id` | CA-18, CA-19 |
| `GET /materials` | CA-20 |
| `GET /materials/:id` | CA-21 |
| `GET /new-material`, `POST /materials`, `GET /materials/:id/edit`, `PATCH\|PUT /materials/:id`, `DELETE /materials/:id` | CA-22 |
| `GET /series`, `GET /series/:id` | CA-23 |
| `GET /new-series`, `POST /series`, `GET /series/:id/edit`, `PATCH\|PUT /series/:id`, `DELETE /series/:id` | CA-24 |

### Code sans route rattaché

| Élément | ID | Preuve |
|---|---|---|
| Encarts « Import JSON Express » (`course-json-import`, `essential-json-import` absents de `app/javascript/controllers/`) | CA-09 | `courses/_form.html.erb:9`, `essentials/_form.html.erb:9` |
| `components/_import_form.html.erb` (import de fiches), `components/_import_card.html.erb`, `components/_import_inline.html.erb` | CA-15 / morts | aucun `render` (`grep -rn "import_form\|import_card\|import_inline" app/views`) |
| `community_validations/_card`, `_success`, `show_community_validation?` | CA-28, CA-29 | `application_helper.rb:80-84` |
| `Strategies::CourseImportStrategy`, `UseCases::Catalog::CreateCourse`, `Repositories::CatalogRepository`, `Queries::CatalogQuery#get_catalog` | morts (liste de `catalog.md` §4, confirmée) | aucun appelant |

---

## 6. Ce que je n'ai pas pu déterminer

- **Si le job d'import de cours lit le même disque que le serveur web en production.** Le contrôleur écrit dans `tmp/imports/` puis met le job en file ; le job sort sans rien dire si le fichier n'existe pas (`import_courses_json_job.rb:15`). Solid Queue tourne dans Puma seulement si `SOLID_QUEUE_IN_PUMA` est défini (`config/puma.rb:38`) ; la topologie Railway réelle (un ou plusieurs services) n'est pas dans le dépôt.
- **L'état réel des données** : combien de matières ont `category = NULL` (C-07), quels noms de niveaux et séries existent, si des niveaux parasites ont été créés par import. `db/seeds.rb` ne contient pas de données métier.
- **Le code de réponse exact de `GET /series` et `GET /series/:id`** (gabarit absent) : erreur de gabarit manquant certaine, statut HTTP (406 ou 500) non vérifié en exécution.
- **La source des cours du fil élève** (`students/feed/content/_courses.html.erb:70`, qui affiche `essentials_count`) : si elle lit la colonne, le compteur affiche 0 ; si elle passe par `StudentClassroomQuery`, il est juste. Tracé par la mission n°5.
- **L'intention de l'ADR-0011 sur les « enseignants certifiés »** et sur la portée (fiches seulement, ou aussi exercices, questions, cours).
- **La sémantique voulue de `archived`**, de `published_at` et de `import_data` (déjà non déterminées par `catalog.md`, rien de nouveau trouvé).
- **Si les filtres de `/courses` ont un jour eu une UI** : aucune trace dans les vues actuelles ; l'historique Git n'a pas été fouillé au-delà de `2449373`.
- **Si la mention de performance de l'ADR-0020 (« import des programmes quasiment instantané ») a été mesurée** : aucune trace de mesure dans le dépôt, et le code des cours n'utilise pas `insert_all`.
