# Journal — Dettes du chantier « réorganisation équipe / enseignant »

> Rempli **pendant** le chantier, pas reconstitué à la fin. C'est ici que se capitalise ce qui ne rentre ni dans un ADR ni dans un commit.

## Décisions prises en cours de route

| Date | Décision | Pourquoi | Promue en ADR ? |
|---|---|---|---|
| 2026-10-04 | Un chantier, quatre lots, un bug par lot, chacun avec son test rouge | Le porteur demande les quatre ensemble ; aucun fichier en commun, sauf le jeu de mesure, dont les deux lots passent en série | — |
| 2026-10-04 | Bug 4 : sous filtre DRENA, les lignes des établissements sont lues **avec** les chiffres, dans la même entrée de cache en vue « année » ; la recherche et les pages se font sur ces lignes | Deux entrées de cache remplies à deux instants ne s'alignent pas ; tout lire en direct referait payer le coût que le cache de l'année évite (il croît avec les sessions de l'année, filtre ou non) | Amendement du 2026-10-04 de l'ADR-0062 |

## Ce qui a dérapé

Les impasses, les hypothèses fausses, le temps perdu et sa cause. **Cette section est la plus utile du fichier** : c'est la seule trace de ce qu'il ne faut pas refaire.

- **Budget du pilotage sur 7 jours, mesuré à la limite sur ce conteneur.** Le premier `PERF=1` sur le jeu réparé (lot B, avant le lot D) a donné le pilotage national 7 jours à 294,8 ms p95 et la page filtrée à 302,8 ms, contre ≈ 190 ms et 179 ms sur les machines des chantiers `cache-ecrans-lourds` et `reorganisation-equipe-enseignant`.
  - Le code du pilotage national n'a pas changé : c'est la machine, neuve et bruitée.
  - Sur cinq séries du même script (`bench_dashboard.rb`, base de développement semée par `seed_dataset.rb`), le national 7 jours varie de 294 à 403 ms en p95, de 252 à 295 ms en p50.
  - La comparaison du lot D se lit donc en **p50, avant / après sur le même jeu, en alternance** (voir ci-dessous), pas contre le seuil absolu.
- **Le seuil du test de budget ne tranche pas ici.** Une même série peut passer ou casser à quelques millisecondes près. Le test garde son seuil ; la mesure qui fait foi pour ce chantier est l'A/B.

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

### Mesure du lot D — avant / après, même jeu, même machine

`bin/rails runner bench_dashboard.rb` sur la base de développement semée par `script/perf/seed_dataset.rb` (312 065 sessions, 55 260 devoirs). Lecture comme le contrôleur : les chiffres, puis la page d'établissements de la plus grande DRENA. 25 lectures après 3 d'échauffement, séries alternées `git stash`.

| Lecture | Avant (p50, 3 séries) | Après (p50, 3 séries) |
|---|---|---|
| Pilotage national 7 jours (code inchangé, témoin) | 252 – 263 ms | 276 – 295 ms |
| Page filtrée 7 jours | 234 – 241 ms | 225 – 248 ms |
| Page filtrée « année », entrée chaude | 115 – 130 ms | **24 – 27 ms** |
| Page filtrée « année », à froid | 373 – 379 ms | 352 – 381 ms |

- La page filtrée 7 jours ne coûte pas plus : une requête de lignes de plus dans les chiffres, mais ni recherche de la DRENA, ni total, ni page en SQL.
- La page filtrée « année » gagne un facteur 5 à chaud : le tableau, lu en direct avant, entre dans l'entrée de cache.

`PERF=1 test/performance/school/heavy_screens_budget_test.rb`, après le lot D (p95, budget 300 ms) :
- pilotage filtré 7 jours de la plus grande DRENA : **237,9 ms** ;
- pilotage filtré « année », entrée chaude : **22,6 ms** ;
- à froid, noté et non budgété : 447,5 ms en national, 507,3 ms filtré.

Le test échoue sur le pilotage **national** 7 jours, à 397,8 ms : son code n'a pas changé, et il mesurait 294,8 ms une heure plus tôt sur le même conteneur (voir « Ce qui a dérapé »).

### Challenger — rejoué dans l'application (2026-10-04)

Rôle distinct, serveur de développement sur la base semée (développement + jeu de mesure), navigateur piloté (Playwright) :
- **Bug 1 — PASS.**
  - Première assignation de « Reconnaître la membrane » à « Tle D 1 » : modale des jours (lundi, jeudi), puis toast « Reconnaître la membrane ajouté à Tle D 1, à rendre lundi 5 oct. ». Un seul point, et le flux Turbo n'en contient pas deux.
  - La bascule affiche « Pour lun. 5 oct. ».
  - Retrait, puis réassignation en un clic : même toast.
  - L'élève lit « À rendre demain ».
- **Bug 3 — PASS.**
  - Énoncés sans balise, côté enseignant et côté élève.
  - Le cours « La cellule » reste en texte riche (paragraphe, deux formules KaTeX).
- **Bug 2 — PASS.** Le jeu de mesure compte uniquement des devoirs `Exercise` (55 260) et 312 065 sessions. Ses 18 902 énoncés et leurs explications sont sans balise.
- **Bug 4 — PASS**, sur Abidjan 2 (17 établissements, 5 274 élèves) :
  1. Avant tout changement, les chiffres du haut égalent la somme du tableau, sur les quatre colonnes.
  2. Un élève est ajouté à Marcory.
  3. Rechargement dans les 5 minutes, en vue « année » : 5 274 en haut, 5 274 au tableau. Égaux, tous deux à l'ancien compte, comme décidé.
  4. Recherches « marcory », « Lycée », « college » et « zzzz » : totaux et lignes cohérents.
  5. En 7 et 30 jours, en direct : 5 275 = 5 275.
  6. Après l'expiration : 5 275 = 5 275 en « année ».
  7. L'élève est supprimé ensuite.
- **Non vérifié par le challenger** :
  - **Le journal du serveur** : la lecture de `log/development.log` lui a été refusée par l'outil de permissions. Seule preuve indirecte : aucune réponse ≥ 400 observée par ses scripts, et chaque page a rendu le contenu attendu.
  - **Une vraie deuxième page d'établissements** : aucune DRENA du jeu n'en a plus de 25, et créer des établissements temporaires a été refusé. La pagination reste prouvée par les tests (RE-09 dans `drena_schools_query_test.rb` et `dashboards_controller_test.rb`).

## Dette laissée derrière

Ce qu'on a consciemment choisi de ne pas faire, et ce qu'il faudra reprendre.

| Quoi | Pourquoi reporté | Chantier de suivi |
|---|---|---|
| Les bases de développement déjà semées gardent leurs deux énoncés en `<p>` | Les seeds sont idempotents par nom ; ces données ne sortent jamais du poste du développeur | `bin/rails db:reset` |
| La fabrique de test `create_exercise` écrit ses énoncés en `<p>Question n</p>` | Données de test seulement ; six assertions comparent cette chaîne telle quelle. Les corriger ne change rien à l'application | Finitions, avec les tests qui la citent |
| Toast d'assignation : la ligne se coupe dans le nom de la classe (« Tle D / 1 ») | Constat du challenger, hors des quatre bugs ; une espace insécable suffirait | Finitions |
| Pendant les 5 minutes du cache de l'année, « Inscrits récents » (toujours en direct) peut déjà montrer un élève que les chiffres et le tableau ne comptent pas encore | Comportement décidé (ADR-0062, amendement du 2026-09-29 : aucune donnée personnelle dans le cache) ; constat du challenger | — |
| Le budget `PERF=1` du pilotage sur 7 jours est à la limite sur ce conteneur, même pour le national inchangé | Machine plus lente et bruitée ; aucun écart dû au chantier (A/B) | Rejouer `PERF=1` sur la machine de recette ; en cas de dépassement, chantier `optimize` (ADR-0062) |

## Clôture

| | |
|---|---|
| **Livré le** | 2026-10-04, sur `Develop` (sans PR, décision du porteur) |
| **PR** | — |
| **ADR produits** | Amendement du 2026-10-04 de l'ADR-0062 (établissements et chiffres en une lecture, `CACHE_VERSION` 2) |
| **UDR produits** | Note d'amendement dans l'UDR-0068 (règle 8 tenue en vue « année ») |
| **Preuve** | Un test rouge par bug, puis vert ; suite complète 3 586 tests, 0 échec, couverture 100 % lignes et branches ; 63 tests système du pilotage, de la classe, des exercices et des accueils ; rubocop, brakeman, gardes au vert ; challenger : les quatre reproductions rejouées dans l'application, PASS ; A/B du pilotage filtré (journal) |
