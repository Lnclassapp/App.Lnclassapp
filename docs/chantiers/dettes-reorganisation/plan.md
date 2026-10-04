# Plan d'exécution — Dettes du chantier « réorganisation équipe / enseignant »

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).

Quatre bugs, quatre lots, sans Lot 0 : aucun contrat partagé. Chaque lot suit le contrat d'exécution du cycle bugfix :

1. Écrire le test de reproduction.
2. Le voir **rouge pour la bonne raison** (message lu).
3. Corriger à la cause.
4. Repasser au vert.
5. Relancer la suite du contexte.

Un test qui passe du premier coup ne reproduit rien : il est jeté et réécrit plus bas dans la pile.

## Graphe

```
Lot A — toast « oct.. »            ┐
Lot B — jeu de mesure refusé       ├─ indépendants
  ├─► Lot C — énoncés en HTML      │  (C touche aussi script/perf/dataset.rb : après B)
  └─► Lot D — une seule lecture    ┘  (D mesure son budget sur le jeu de B)
```

Un seul exécutant, en série A → B → C → D : les lots sont petits, et C et D attendent B.

---

## Lot A — Le toast d'assignation finit par un seul point

- **Couche** : delivery + ui
- **Fichiers** :
  - `app/helpers/due_date_helper.rb` : `due_closing`, la date longue en fin de phrase, son point abréviatif tenant lieu de point final
  - `app/controllers/classroom/assignments_controller.rb` : `toggle_message` passe par `helpers.due_closing`
  - `config/locales/classroom/assignments.fr.yml` : `done_due` sans point final, porté par la date
  - `test/controllers/classroom/assignments_controller_test.rb`
  - `test/helpers/due_date_helper_test.rb`
- **Dépend de** : —
- **Test associé** :
  - **Reproduction** : `test/controllers/classroom/assignments_controller_test.rb`. Lundi 5 octobre 2026, échéance jeudi 8 ; le toast vaut littéralement « Méiose ajouté à 6ème 1, à rendre jeudi 8 oct. ». Il échoue d'abord sur « oct.. ».
  - **Cas symétrique** : en mai, « … à rendre jeudi 6 mai. ».
  - **Helper** : les deux formes.
- **Done quand** : le toast d'une échéance d'octobre finit par un seul point, celui d'une échéance de mai par un point ; aucune autre chaîne d'échéance ne change.

---

## Lot B — Le jeu de mesure ne crée que des devoirs d'exercice

- **Couche** : outillage (script de mesure)
- **Fichiers** :
  - `script/perf/dataset.rb` : `seed_assignments` crée 10 devoirs d'exercice par classe peuplée (au lieu de 7 exercices, 2 fiches et 1 cours) ; même volume de devoirs
  - `test/db/perf_dataset_test.rb` *(nouveau)*
- **Dépend de** : —
- **Test associé** :
  - **Reproduction** : `test/db/perf_dataset_test.rb`. `PerfDataset.seed_assignments` sur une classe et un petit catalogue (un cours, deux fiches, des exercices) n'écrit que des devoirs `Exercise`. Il échoue d'abord sur `PG::CheckViolation` (`classroom_assignments_type_values`). Il tourne dans la suite unitaire, donc dans la CI.
  - **Preuve à l'échelle** : `PERF=1 COVERAGE=0 bin/rails test test/performance/school/heavy_screens_budget_test.rb` sème le jeu et passe ses budgets.
- **Done quand** : le test de budget sème le jeu complet et rend ses mesures.

---

## Lot C — Les énoncés semés sont du texte brut

- **Couche** : données (seeds) + outillage
- **Fichiers** :
  - `db/seeds/development.rb` : énoncés sans `<p>`
  - `script/perf/dataset.rb` : `seed_questions`, énoncé et explication sans `<p>`
  - `test/db/seeds_test.rb`
  - `test/db/perf_dataset_test.rb`
- **Dépend de** : Lot B (même script, même fichier de test)
- **Test associé** :
  - **Reproduction** : `test/db/seeds_test.rb`. Joué en développement (`Rails.env = "development"`, après les seeds de test), `development.rb` écrit des énoncés sans balise, et le contenu du cours reste du texte riche. Il échoue d'abord sur `"<p>La membrane plasmique délimite la cellule.</p>"`.
  - `test/db/perf_dataset_test.rb` : `PerfDataset.seed_questions` écrit des énoncés et des explications sans balise. Il échoue d'abord sur `<p>`.
- **Done quand** : sur une base neuve (`bin/rails db:reset`), l'exercice « Reconnaître la membrane » affiche « La membrane plasmique délimite la cellule. » sans balise.

---

## Lot D — Sous filtre DRENA, les établissements et les chiffres sont une seule lecture

- **Couche** : infrastructure (queries) + delivery + décision
- **Fichiers** :
  - `app/infrastructure/queries/school/team_dashboard_query.rb` :
    - sous filtre DRENA, `figures` calcule aussi `school_rows`, les lignes de tous les établissements de la DRENA ; en vue « année », elles entrent dans la même entrée de cache ;
    - `CACHE_VERSION` passe à 2.
  - `app/infrastructure/queries/school/drena_schools_query.rb` :
    - `rows`, toutes les lignes triées, avec les définitions inchangées ;
    - `page`, la recherche (`TextSearch` sur les noms, en SQL) et les pages de 25 sur ces lignes ;
    - `call` disparaît.
  - `app/controllers/teams/dashboards_controller.rb` : `read_schools` met en pages `@dashboard.school_rows`.
  - `test/infrastructure/queries/school/drena_schools_query_test.rb`
  - `test/infrastructure/queries/school/team_dashboard_query_test.rb`
  - `test/performance/school/heavy_screens_budget_test.rb` : la page filtrée telle que le contrôleur la lit, en 7 jours et en année.
  - `docs/decisions/adr/0062-indicateurs-de-pilotage-lus-en-direct.md` : amendement du 2026-10-04.
  - `docs/decisions/udr/0068-configuration-et-pilotage-par-etablissement.md` : la phrase sur le cache.
- **Dépend de** : Lot B, pour mesurer le budget sur le jeu de mesure.
- **Test associé** :
  - **Reproduction** : `drena_schools_query_test.rb`, avec le cache réel (`:memory_store` en test).
    1. Lire la page filtrée en vue « année ».
    2. Placer un élève de plus dans un établissement de la DRENA ; un autre élève est inscrit à deux classes, dont une seule principale.
    3. Relire.
    - Attendu : les établissements font toujours le total des chiffres de la DRENA.
    - Le test échoue d'abord : les chiffres restent à l'ancien compte, le tableau non.
  - **Cas symétriques** :
    - 7 et 30 jours restent lus en direct, toujours égaux ;
    - la vue nationale « année » reste en cache (tests existants de `team_dashboard_query_test.rb`) ;
    - RE-07 à RE-10 (liste, inactifs comptés, pages, recherche) inchangés ;
    - le test du nombre de requêtes reste indépendant du volume.
  - **Budget** (`PERF=1`) : « pilotage filtré, plus grande DRENA » en 7 jours et en année (entrée chaude), sous 300 ms p95.
- **Done quand** : sur le pilotage filtré, en vue « Année scolaire », la somme des établissements égale les chiffres du haut, juste après un changement comme 5 minutes plus tard.

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/helpers/due_date_helper.rb` | A |
| `app/controllers/classroom/assignments_controller.rb` | A |
| `config/locales/classroom/assignments.fr.yml` | A |
| `script/perf/dataset.rb` | B, puis C (en série) |
| `test/db/perf_dataset_test.rb` | B, puis C (en série) |
| `db/seeds/development.rb` | C |
| `test/db/seeds_test.rb` | C |
| `app/infrastructure/queries/school/team_dashboard_query.rb` | D |
| `app/infrastructure/queries/school/drena_schools_query.rb` | D |
| `app/controllers/teams/dashboards_controller.rb` | D |
| `test/infrastructure/queries/school/*_query_test.rb` (deux fichiers) | D |
| `test/performance/school/heavy_screens_budget_test.rb` | D |
| ADR-0062, UDR-0068 | D |

## Portes de sortie (cycle bugfix, `docs/workflows/bugfix.md`)

- [x] Symptôme et étapes de reproduction écrits dans `memo.md`
- [x] Bug reproduit **à la main** dans l'application avant toute ligne de code (1 : texte du toast ; 2 : test de budget ; 3 : base de développement ; 4 : constat du challenger d'origine)
- [x] Rapport root cause rendu : fichier, ligne, chaîne d'appels, raison du trou de test (`journal.md`)
- [ ] Test de reproduction écrit **avant** le correctif (A, B, C, D)
- [ ] Test lancé et **rouge**, pour la bonne raison (message vérifié) (A, B, C, D)
- [ ] Correctif appliqué dans la couche de la **cause**, pas du symptôme
- [ ] Test au vert · suite du contexte borné au vert
- [ ] Cas symétrique vérifié : le chemin nominal voisin fonctionne toujours
- [x] Données déjà corrompues : réparées, ou dette explicitement notée au journal (bug 3, bases de développement)
- [ ] Challenger a rejoué les étapes de reproduction dans l'application
- [ ] Commit `fix(<contexte>): …` avec la ligne `Chantier:`
- [ ] `journal.md` : cause, trou de test comblé, effets de bord écartés
