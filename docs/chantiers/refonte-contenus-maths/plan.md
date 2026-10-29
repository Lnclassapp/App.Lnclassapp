# Plan d'exécution — Refonte des contenus de mathématiques

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Décisions : [PRD](prd.md), ADR-XXXX-fiche-de-revision-par-notion-et-figures-parametrees, UDR-XXXX-fiche-de-revision-en-quatre-blocs-et-corrige-de-l-equipe.

## Graphe

```
Lot 0 — SOCLE (séquentiel) : colonnes, entités, ports, schéma v3, routes, partial de figure
  ↓
  ├─► Lot A  Importer une leçon v3            ┐
  ├─► Lot B  Lire la fiche de révision         │
  ├─► Lot C  Corrigé de l'équipe               ├─ vague 2, en parallèle
  ├─► Lot D  Figure sous le sujet d'exercice   │
  ├─► Lot F1 Figures : contrôleur + 2 sortes   │
  └─► Lot V  Contrôle hors ligne et prompt     ┘
        ↓
  ├─► Lot F2 Figures : 3 autres sortes (dépend de F1)         ┐ vague 3
  └─► Lot R  Retraits (dépend de A, B, C)                     ┘
        ↓
  ├─► Lot P1 Leçons de 3e, 1 à 5  (dépend de A, V, F2)        ┐ vague 4
  └─► Lot P2 Leçons de 3e, 6 à 10 + démo (dépend de A, V, F2) ┘
```

Ordre intra-lot (code) : test rouge → `app/domain/` → `app/infrastructure/` → `app/controllers/` → vues. En-tête HITL sur tout fichier créé dans `app/`.

---

## Lot 0 — Socle

- **Couche**       : infrastructure + domaine (contrats) + routes + partial partagé
- **Fichiers**     : `db/migrate/<horodatage>_add_revision_sheet_to_catalog.rb` (ajoute `essentials.sheet` jsonb, `courses.figures` jsonb `[]`, `courses.sheet_theme` + contrainte, `exercises.figure_key` ; ne supprime rien)
                     `db/schema.rb`
                     `app/domain/entities/catalog/notion_sheet.rb`
                     `app/domain/entities/catalog/figure.rb`
                     `app/domain/entities/catalog/figure_kinds.rb` (liste fermée des 5 sortes et bornes de leurs paramètres)
                     `app/domain/entities/catalog/import_kind.rb` (`COURSE_TREE_VERSION = 3`, `legacy_versions: []`)
                     `app/domain/ports/catalog/content_tree_writer_port.rb` (nœuds v3 : `NotionNode` avec `sheet`, `CourseNode#figures/#sheet_theme`, `ExerciseNode#figure_key` ; `replace_draft(course_id:, tree:)`)
                     `app/domain/ports/catalog/course_repository_port.rb` (`status_for_update(id:)` : statut de la leçon et de ses contenus, sous verrou)
                     `config/schemas/lnclass.course-tree.v3.json`
                     `config/routes/teams.rb` (ajoute `GET courses/:slug/answer-key`)
                     `app/views/catalog/figures/_figure.html.erb` (cadre, valeurs Stimulus, description de repli ; options `frame: :sheet | :app`)
                     `test/support/factories/revision_sheet.rb` (fabrique d'une leçon v3 valide, partagée par tous les lots)
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/catalog/notion_sheet_test.rb` · `test/domain/entities/catalog/figure_test.rb` · `test/infrastructure/schemas/course_tree_v3_schema_test.rb`
- **Done quand**   : la migration passe sur une base vide et l'existante ; une leçon v3 de la fabrique est acceptée par le schéma et les entités, chaque règle de l'ADR §4.1 (étapes, bornes de figure, sorte inconnue) refusée par son test ; l'application démarre et la page d'une leçon actuelle s'affiche comme avant

---

## Lot A — Importer une leçon v3 (CA-1 à CA-11)

- **Couche**       : domaine + infrastructure + ui (aide d'import)
- **Fichiers**     : `app/domain/use_cases/catalog/import_course_tree.rb`
                     `app/domain/entities/catalog/content_node.rb` (≥ 5 questions, `explanation` obligatoire, figures citées)
                     `app/infrastructure/repositories/catalog/content_tree_writer.rb` (écriture v3, `replace_draft` en transaction, leçon `FOR UPDATE`)
                     `app/infrastructure/repositories/catalog/course_repository.rb`
                     `app/views/teams/imports/kinds/_course_tree.html.erb`
                     `config/locales/catalog/imports.fr.yml`
                     `test/domain/use_cases/catalog/import_course_tree_test.rb`
                     `test/infrastructure/repositories/catalog/content_tree_writer_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/catalog/import_course_tree_test.rb` (CA-1 à CA-9) · `test/infrastructure/repositories/catalog/content_tree_writer_test.rb` (CA-10, CA-11)
- **Done quand**   : dans l'espace équipe, importer la leçon v3 de la fabrique crée leçon, notions et 7 exercices en brouillon ; réimporter la même leçon en brouillon la remplace (même adresse) ; la publier puis réimporter donne un refus qui la nomme ; un fichier v2 est refusé « format retiré »

---

## Lot B — Lire la fiche de révision (CA-12, CA-14)

- **Couche**       : infrastructure (query) + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/revision_sheet_query.rb`
                     `app/domain/entities/catalog/revision_preview.rb` (coupe des 150 mots sur les blocs du gabarit)
                     `app/views/catalog/courses/_revision_sheet.html.erb`
                     `app/views/catalog/revision_sheets/_sheet.html.erb`
                     `app/helpers/catalog/course_sheet_text_helper.rb` (sans lexique)
                     `app/assets/stylesheets/course_sheet.css` (ton `pitfall`, `.sheet-figure-canvas`)
                     `config/locales/catalog/revision_sheets.fr.yml`
                     `test/infrastructure/queries/catalog/revision_sheet_query_test.rb`
                     `test/domain/entities/catalog/revision_preview_test.rb`
                     `test/integration/catalog/revision_sheet_test.rb`
                     `test/system/catalog/revision_sheet_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/catalog/revision_sheet_test.rb` (CA-12, CA-14) · `test/system/catalog/revision_sheet_test.rb` (Voir plus, 390 px)
- **Done quand**   : un élève de 3e ouvre une leçon v3 publiée et voit, sur le cahier Seyès au thème de la leçon, chaque notion avec ses 4 blocs dans l'ordre, les étapes numérotées et l'exemple aux mêmes numéros ; la description de la figure à sa place ; un brouillon lui répond 404 ; captures 390 px et ordinateur envoyées au porteur

---

## Lot C — Corrigé de l'équipe (CA-15, CA-16)

- **Couche**       : infrastructure (query) + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/catalog/lesson_answer_key_query.rb`
                     `app/controllers/teams/answer_keys_controller.rb`
                     `app/views/teams/answer_keys/show.html.erb`
                     `app/views/catalog/courses/_role_actions.html.erb` (« Corrigé » ajouté, « Importer des notions » retiré)
                     `config/locales/teams/answer_keys.fr.yml`
                     `test/infrastructure/queries/catalog/lesson_answer_key_query_test.rb`
                     `test/controllers/teams/answer_keys_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/controllers/teams/answer_keys_controller_test.rb` (CA-15, CA-16)
- **Done quand**   : depuis le menu ⋮ d'une leçon en brouillon, un membre de l'équipe ouvre « Corrigé » et lit chaque exercice dans l'ordre de « Prépare interros » avec bonnes réponses et corrections ; un élève et un enseignant reçoivent 404 sur la même adresse ; captures envoyées

---

## Lot D — Figure sous le sujet d'un exercice (CA-13, côté exercice)

- **Couche**       : infrastructure (queries) + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/exercise_detail_query.rb`
                     `app/infrastructure/queries/assessment/session_play_query.rb`
                     `app/views/assessment/exercises/show.html.erb`
                     `app/views/assessment/exercise_sessions/show.html.erb`
                     `test/infrastructure/queries/assessment/exercise_detail_query_test.rb`
                     `test/integration/assessment/exercise_figure_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/integration/assessment/exercise_figure_test.rb`
- **Done quand**   : un exercice dont le fichier cite une figure l'affiche sous son sujet, sur la page de l'exercice et sur la copie en cours ; un exercice sans figure n'a pas d'emplacement vide

---

## Lot F1 — Figures interactives : contrôleur, `geometry`, `number_line` (CA-13)

- **Couche**       : ui (JavaScript)
- **Fichiers**     : `app/javascript/controllers/figure_controller.js` (liste blanche des 5 sortes, curseurs, repli)
                     `app/javascript/lib/figures/svg.js` (création de nœuds par `createElementNS`, couleurs lues dans les variables CSS)
                     `app/javascript/lib/figures/geometry.js`
                     `app/javascript/lib/figures/number_line.js`
                     `test/javascript/figures_structure_test.rb` (sortes = liste de l'ADR, aucun `innerHTML`, aucune couleur en dur)
                     `test/system/catalog/figure_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/system/catalog/figure_test.rb` · `test/javascript/figures_structure_test.rb`
- **Done quand**   : sur une leçon de démonstration, une figure de Thalès (`geometry`) se déplace au doigt et au clavier en recalculant les rapports, une droite graduée affiche un intervalle ; sans JavaScript, la description seule ; le JS commun ne grossit pas (budget ADR-0114) ; captures 390 px et ordinateur

---

## Lot F2 — Figures interactives : `coordinate_plane`, `stat_chart`, `solid` (CA-13)

- **Couche**       : ui (JavaScript)
- **Fichiers**     : `app/javascript/lib/figures/coordinate_plane.js`
                     `app/javascript/lib/figures/stat_chart.js`
                     `app/javascript/lib/figures/solid.js`
                     `test/system/catalog/figure_kinds_test.rb`
- **Dépend de**    : Lot F1
- **Test associé** : `test/system/catalog/figure_kinds_test.rb`
- **Done quand**   : un repère avec vecteur réglable au curseur, un diagramme en bâtons et un circulaire, une pyramide et un cône en perspective cavalière s'affichent et réagissent à leurs curseurs ; captures envoyées

---

## Lot V — Contrôle hors ligne et prompt de rédaction (CA-18)

- **Couche**       : outillage + documentation de production
- **Fichiers**     : `script/contenus/valider.rb` (v3 : mêmes règles et mêmes raisons que l'import ; contrôles de rédaction en avertissement : correction qui cite « Étape n », mots interdits)
                     `test/script/contenus/valider_test.rb`
                     `docs/contenus/prompt-redaction.md` (v3, gabarit, ≥ 5 questions, corrections qui suivent la méthode, figures paramétrées)
                     `docs/contenus/prompt-redaction-lot.md`
                     `docs/contenus/README.md`
- **Dépend de**    : Lot 0
- **Test associé** : `test/script/contenus/valider_test.rb` (CA-18)
- **Done quand**   : le script refuse chacune des fautes de CA-3 à CA-9 avec la même raison que l'import, et accepte la leçon de la fabrique ; le prompt produit, sur un essai, un fichier que le script accepte

---

## Lot R — Retraits (CA-17)

- **Couche**       : infrastructure + domaine + delivery + ui (suppressions)
- **Fichiers**     : `db/migrate/<horodatage>_drop_course_sheets_and_essential_images.rb` (supprime `course_sheets`, `essential_images`, le texte riche des notions, les kinds `course_sheet` et `essentials` des rapports)
                     `db/schema.rb` *(après Lot 0, séquentiel)*
                     suppressions : `app/domain/use_cases/catalog/{import_course_sheet,import_essentials,upload_essential_image,read_essential_image}.rb`, `app/domain/entities/catalog/{course_sheet,sheet_document}.rb`, `app/domain/ports/catalog/{course_sheet_repository_port,essential_image_store_port}.rb`, `app/infrastructure/repositories/catalog/{course_sheet_repository,essential_image_store}.rb`, `app/infrastructure/orm/{course_sheet,essential_image}.rb`, `app/infrastructure/queries/catalog/course_sheet_query.rb`, `app/jobs/catalog/{import_course_sheet_job,import_essentials_job,purge_orphan_essential_images_job}.rb`, `app/controllers/catalog/{course_sheets,essential_images}_controller.rb`, `app/controllers/teams/essential_images_controller.rb`, `app/views/catalog/course_sheets/`, `app/views/catalog/essentials/_body_image.html.erb`, `app/views/teams/imports/kinds/_essentials.html.erb`, `app/javascript/controllers/course_sheet/`, `app/javascript/lib/course_sheet/`, `config/schemas/lnclass.course-tree.v{1,2}.json`, `config/schemas/lnclass.course-sheet.v1.json`, `config/locales/catalog/course_sheets*.fr.yml`, `db/seeds/data/course_sheets/`, `db/seeds/demo/fiches_de_cours.rb`, et leurs tests (`test/**/course_sheet*`, `test/views/catalog/course_sheets/`, `test/helpers/catalog/course_sheet_lens_helper_test.rb`, tests des use cases retirés)
                     `app/assets/stylesheets/course_sheet.css` (classes retirées, UDR §4) *(après Lot B, séquentiel)*
                     `config/routes/catalog.rb` · `config/routes/teams.rb` *(routes d'images de notions ; `courses/:course_slug/fiche` → redirection gardée)*
                     `config/initializers/imports.rb`
                     `test/design/design_tokens_test.rb` (exception limitée à `course_sheet.css` et `catalog/revision_sheets/`)
                     `test/infrastructure/orm/models_test.rb`
                     `test/db/course_sheets_constraints_test.rb` (supprimé)
                     `test/db/retired_tables_test.rb`
- **Dépend de**    : Lot A, Lot B, Lot C
- **Test associé** : `test/db/retired_tables_test.rb` (CA-17) · `test/routing/retired_routes_test.rb`
- **Done quand**   : l'écran d'import ne propose plus « Fiche de cours » ni « Notions » ; les anciennes adresses d'images de notions répondent 404 ; aucune référence aux classes, fichiers ou tables retirés (`bin/ci-quiet` vert) ; la page d'une leçon v3 s'affiche inchangée

---

## Lot P1 — Leçons de 3e, 1 à 5 (CA-19)

- **Couche**       : contenus
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/mathematiques/{calcul-litteral,proprietes-de-thales-dans-un-triangle,racines-carrees,triangle-rectangle,calcul-numerique}.json`
- **Dépend de**    : Lot A, Lot V, Lot F2
- **Test associé** : `test/integration/catalog/pilot_lessons_test.rb` (CA-19, lancé par P2 sur les 10 fichiers ; P1 lance le script de contrôle sur ses 5)
- **Done quand**   : les 5 fichiers passent le script de contrôle, la relecture IA indépendante (calculs refaits) ne trouve aucune erreur de fond, chacun s'importe en brouillon et sa fiche s'affiche avec ses figures

---

## Lot P2 — Leçons de 3e, 6 à 10, et démonstration (CA-19)

- **Couche**       : contenus + données de démonstration
- **Fichiers**     : `docs/contenus/lecons-traitees/3eme/mathematiques/{angles-inscrits,vecteurs,equations-et-inequations-dans-r,pyramides-et-cones,statistique}.json`
                     `db/seeds/demo/lecons_completes.rb` (n'importe plus que les fichiers v3)
                     `test/integration/catalog/pilot_lessons_test.rb`
- **Dépend de**    : Lot A, Lot V, Lot F2 (et Lot P1 pour le test qui lit les 10 fichiers)
- **Test associé** : `test/integration/catalog/pilot_lessons_test.rb` (CA-19)
- **Done quand**   : les 10 leçons de 3e passent le script et s'importent en brouillon sur une base vide ; `bin/tester-pr <PR> --demo` les montre publiées ; captures de 2 leçons à 390 px et sur ordinateur

---

## Vérification de collision

> Doublons recherchés mécaniquement : seuls `db/schema.rb` et `config/routes/teams.rb` apparaissent deux fois (Lot 0 et Lot R), et `course_sheet.css` (Lot B et Lot R). Ces lots sont **séquentiels** (R dépend de A, B, C), pas parallèles : pas de collision.

| Fichier | Lot propriétaire |
|---|---|
| `db/migrate/*`, `db/schema.rb` | Lot 0, puis Lot R (vague 3) |
| `config/routes/teams.rb` | Lot 0, puis Lot R (vague 3) |
| `config/routes/catalog.rb` | Lot R |
| `config/schemas/lnclass.course-tree.v3.json` | Lot 0 |
| `app/domain/entities/catalog/import_kind.rb` | Lot 0 |
| `app/domain/ports/catalog/*` | Lot 0 (gelés) ; Lot R supprime deux ports morts |
| `app/views/catalog/figures/_figure.html.erb` | Lot 0 |
| `test/support/factories/revision_sheet.rb` | Lot 0 |
| `app/assets/stylesheets/course_sheet.css` | Lot B, puis Lot R |
| `app/views/catalog/courses/_role_actions.html.erb` | Lot C |
| `config/locales/catalog/imports.fr.yml` | Lot A |
| `config/locales/catalog/revision_sheets.fr.yml` | Lot B |
| `config/locales/teams/answer_keys.fr.yml` | Lot C |
| `app/javascript/controllers/figure_controller.js` | Lot F1 |
| `test/integration/catalog/pilot_lessons_test.rb` | Lot P2 |
| Aucun layout, aucune navigation, aucune fixture partagée touchés | — |

## Dispatch

```
Vague 1 : Lot 0                                   → 1 agent (executant-lot, Sonnet), séquentiel
Vague 2 : Lot A ‖ Lot B ‖ Lot C ‖ Lot D ‖ Lot F1 ‖ Lot V → 6 agents, worktrees isolés
Vague 3 : Lot F2 ‖ Lot R                          → 2 agents
Vague 4 : Lot P1 ‖ Lot P2                         → 2 agents rédacteurs + 1 relecteur IA indépendant par lot
```

Worktree d'un lot, depuis la branche de chantier une fois le Lot 0 mergé :

```bash
git worktree add ../lnclass-refonte-contenus-maths-lot-a -b feature/refonte-contenus-maths-lot-a feature/refonte-contenus-maths
```

Rappels transmis à chaque agent : chemins **absolus** (`git -C <worktree>`) ; **interdiction de toucher un fichier hors de son champ `Fichiers`** — s'il en a besoin, il s'arrête et remonte ; un port à changer rouvre le Lot 0.

Entre deux lots : tests des fichiers touchés et `bin/system-changed`. `bin/ci-quiet` une fois, sur le head final, après les revues. Sous-agents de revue (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) une fois sur le diff final (import, policy, route et use case touchés).

**Rattachement des critères** : CA-1 à CA-11 → A · CA-12, CA-14 → B · CA-13 → B (description), D (exercice), F1/F2 (figure) · CA-15, CA-16 → C · CA-17 → R · CA-18 → V · CA-19 → P1, P2. Aucun critère orphelin.

## Portes de sortie

- [x] `memo.md` complet, section `Hors périmètre` non vide
- [x] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [x] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [x] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [x] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] PR unique vers `Develop`, référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici : il importe une leçon de 3e en brouillon, la lit comme élève après publication (fiche, figure manipulée au doigt à 390 px), fait un exercice et lit sa correction ; puis il réimporte la leçon publiée et doit obtenir le refus, et importe un fichier v2 et doit obtenir « format retiré ».
