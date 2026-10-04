# Journal — Dettes du chantier « réorganisation équipe / enseignant »

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Un chantier, quatre lots, un bug par lot, chacun avec son test rouge | Le porteur demande les quatre ensemble ; aucun fichier en commun, sauf le jeu de mesure, dont les deux lots passent en série | — |
| 2026-10-04 | Bug 4 : sous filtre DRENA, les lignes des établissements sont lues **avec** les chiffres, dans la même entrée de cache en vue « année » ; la recherche et les pages se font sur ces lignes | Deux entrées de cache remplies à deux instants ne s'alignent pas ; tout lire en direct referait payer le coût que le cache de l'année évite (il croît avec les sessions de l'année, filtre ou non) | Amendement du 2026-10-04 de l'ADR-0062 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- …

## Ce qu'on a appris sur la codebase

### Rapport root cause — bug 1, toast « oct.. »

- **Chaîne d'appels**, de `Classroom::AssignmentsController#create` jusqu'au texte :
  1. `respond_with_toggle` appelle `render_toggle`, qui appelle `toggle_message` (`app/controllers/classroom/assignments_controller.rb:93`).
  2. `toggle_message` fait `t(".done_due", date: l(due_on, format: :due_long))`.
  3. `due_long` (« %A %-d %b ») produit « jeudi 8 oct. ».
  4. La chaîne `done_due` (`config/locales/classroom/assignments.fr.yml:39`) ajoute son propre point final.
- **Cause** : la phrase pose un point final après une date qui peut déjà finir par le point abréviatif du mois. La date y est aussi formatée hors de `DueDateHelper`, que son en-tête désigne comme « seul endroit où [l'échéance] se formate ». La règle typographique (le point abréviatif tient lieu de point final) n'est appliquée nulle part.
- **Trou de test** :
  - `test/controllers/classroom/assignments_controller_test.rb:336` construit l'attendu avec le même gabarit, `tl("create.done_due", date: "jeudi 8 oct.")`. L'attendu contient donc lui-même « oct.. ».
  - Les tests système vérifient le toast par inclusion (`assert_toast`, `assert_selector text:`), et « oct. » est inclus dans « oct.. ».
  - Le test de reproduction compare donc au **texte littéral** de l'UDR-0062 §3.4.

### Rapport root cause — bug 2, jeu de mesure refusé par la base

- **Chaîne d'appels** :
  1. `School::HeavyScreensBudgetTest` (setup) appelle `PerfDataset.run`.
  2. `run` appelle `seed_assignments` (`script/perf/dataset.rb:252-253`), qui crée deux devoirs `Essential` et un `Course` par classe.
  3. `insert(Orm::ClassroomAssignment)` puis `insert_all!` se heurtent à la contrainte `classroom_assignments_type_values` (`assignable_type = 'Exercise'`), posée par la migration `20261003100000_restrict_classroom_assignments_to_exercises`.
- **Cause** : le jeu de mesure fabrique encore des devoirs de fiche et de cours, que le schéma refuse depuis le 2026-10-03.
- **Trou de test** : le jeu ne tourne que sous `PERF=1`, dans les tests `*_budget_test.rb`, exclus de `bin/ci` (`config/ci.rb:69`, ADR-0067). La migration a son propre test (`test/db/restrict_classroom_assignments_to_exercises_test.rb`), mais rien ne sème le jeu dans la CI. Le test de reproduction appelle `PerfDataset.seed_assignments` sur un petit catalogue, dans la suite unitaire (`test/db/`), donc dans la CI.

### Rapport root cause — bug 3, énoncés de démonstration en HTML

- **Chaîne d'appels** :
  1. `db/seeds.rb` (développement) charge `db/seeds/development.rb:52`, qui fait `exercise.questions.create!(content: "<p>#{content}</p>")`.
  2. À l'affichage, `_question_card` et `_questions_preview` rendent `<%= question.content %>` échappé, en `whitespace-pre-line`.
- **Cause** : les seeds écrivent du HTML dans un champ de texte brut. Le contenu des cours et des fiches est du texte riche (`has_rich_text`), l'énoncé d'une question ne l'est pas. Le jeu de mesure a le même défaut (`script/perf/dataset.rb:214`, énoncé et explication).
- **Trou de test** : `test/db/seeds_test.rb` vérifie seulement que `development.rb` **refuse** de tourner en test et en production. Rien ne le joue en développement. Le test de reproduction le joue avec `Rails.env = "development"`, dans la transaction du test.

### Rapport root cause — bug 4, écart de 5 minutes sous filtre DRENA

- **Chaîne d'appels** :
  1. `Teams::DashboardsController#respond_with_search` appelle `TeamDashboardQuery#call`. Pour la période `year`, celui-ci fait `@cache.fetch(…, expires_in: 5.minutes)` (`app/infrastructure/queries/school/team_dashboard_query.rb:54`), **avec ou sans filtre**.
  2. Sous filtre, `read_schools` appelle `DrenaSchoolsQuery#call`, toujours en direct.
- **Cause** : les deux lectures d'une même page ne datent pas du même instant. La query du tableau de bord garde l'année en cache sous filtre DRENA, alors que la page y ajoute une lecture en direct qui doit lui être égale (RE-08).
- **Trou de test** : le test RE-08 (`test/infrastructure/queries/school/drena_schools_query_test.rb:107`) lit la ligne DRENA avec un `NullStore` (ligne 20). Il compare deux lectures en direct et ne voit jamais le cache. Le test de reproduction utilise le cache réel (`:memory_store` en test) et change les données entre deux lectures.

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les bases de développement déjà semées gardent leurs deux énoncés en `<p>` | Les seeds sont idempotents par nom ; ces données ne sortent jamais du poste du développeur | `bin/rails db:reset` |

## Clôture

| | |
|---|---|
| **Livré le** | |
| **PR** | |
| **ADR produits** | |
| **UDR produits** | |
