# ADR-0067 : Chaque écran a un budget de temps serveur et de HTML, vérifié au volume de la feuille de route
<!-- index
titre: Chaque écran a un budget de temps serveur et de HTML, vérifié au volume de la feuille de route
statut: Accepté *(2026-09-29)* — *complète 0051, 0062*
problematique: p95 serveur < 300 ms pour le pilotage, < 100 ms ailleurs, HTML brut < 150 Ko ; jeu `script/perf/dataset.rb` (40 000 élèves, 312 000 sessions) ; test `PERF=1` du SQL des trois queries lourdes et `script/perf/measure_screens.rb` pour la page ; hors CI. Chantier `cache-ecrans-lourds`.
-->

| | |
|---|---|
| **Statut** | Accepté (décidé par le porteur le 2026-09-29) |
| **Date** | 2026-09-29 |
| **Chantier** | [`docs/chantiers/cache-ecrans-lourds`](../../chantiers/cache-ecrans-lourds/memo.md) |
| **Complète** | [ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) (budget de poids du JavaScript et du CSS) · [ADR-0062](./0062-indicateurs-de-pilotage-lus-en-direct.md) (seuil de reprise du pilotage à 300 ms, amendé le même jour) |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'[ADR-0051](./0051-navigateurs-supportes-et-budget-de-poids.md) fixe un budget de **poids** pour ce que le navigateur télécharge une fois : 60 Ko gzip de JavaScript, 30 Ko gzip de CSS, vérifiés en CI. Il ne dit rien de ce que chaque page coûte **à chaque requête** : le temps du serveur et le HTML qu'il envoie. Le seul chiffre écrit était le **seuil de reprise de 300 ms** du pilotage (ADR-0062 §5).

Le chantier `cache-ecrans-lourds` a mesuré 28 écrans au volume de la feuille de route (500 établissements, 34 500 classes, 40 000 élèves, 312 000 sessions). Quatre écrans dépassaient ce qu'on peut accepter d'une page servie à un téléphone en 3G : le pilotage (361 à 429 ms en p95), sa recherche (293 ms), « Travail des élèves » de la direction (240 ms). Deux listes pesaient plus de 500 Ko de HTML brut. Sans budget écrit, « lent » restait une impression, et aucune régression ne se voyait avant la production.

## 2. Moteurs de décision

1. Un chiffre par famille d'écrans, qu'une machine peut vérifier : un budget que personne ne mesure n'existe pas (ADR-0051).
2. Mesurer **au volume visé**, pas sur trois lignes de fixture : le coût de ces écrans croît avec les données.
3. Ne pas ralentir la CI de tous les jours : semer 312 000 sessions prend deux minutes.
4. Ne pas introduire de cache tant qu'un index ou une requête mieux écrite suffit (ADR-0062, option C).

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Pas de budget, mesurer à la demande | Rien à maintenir | C'est la situation qui a laissé quatre écrans dépasser 200 ms sans que personne le voie |
| B — Budget vérifié à chaque CI | Une régression casse la CI | Il faut semer le jeu complet à chaque exécution (≈ 2 min), et le temps d'une CI partagée varie trop pour un seuil en millisecondes |
| **C — Budget écrit, vérifié par un test `PERF=1` et par le script de mesure, joués avant chaque recette et par tout chantier qui touche un écran budgété** | Même jeu, même méthode que la mesure « avant » ; la CI reste rapide | Retenue. Coût : une régression se voit à la recette, pas au commit |

## 4. Décision

> **Nous budgétons chaque écran en temps serveur p95 et en HTML brut, au volume du jeu de mesure, et nous vérifions ces budgets par un test `PERF=1` et par `script/perf/measure_screens.rb`.**

| Famille d'écrans | Budget p95 serveur | HTML brut |
|---|---|---|
| Pilotage de l'équipe (`/teams/dashboard`, toutes périodes, filtre DRENA compris) | **< 300 ms** | < 150 Ko |
| Tous les autres écrans (recherches, direction, listes, élèves, enseignants) | **< 100 ms** | **< 150 Ko** |

- **p95 serveur** : temps de la requête dans le processus Rails, toute la pile Rack traversée, **sans** réseau ni rendu navigateur ; Rails en mode production (eager load, gabarits compilés).
- **HTML brut** : corps de la réponse avant compression. Le poids compressé est déjà faible (≤ 20 Ko) ; ce budget vise le temps de rendu serveur et l'analyse du DOM par un téléphone d'entrée de gamme.
- **Volume de référence** : le jeu de `script/perf/dataset.rb` (graine fixe) : 500 établissements dont 80 adoptants, 34 531 classes, 4 150 enseignants, 40 000 élèves, 211 cours, 54 778 devoirs, 311 957 sessions sur 60 jours ; l'établissement mesuré pour la direction est le plus grand (77 classes, 4 235 élèves).
- **Méthode** : 3 requêtes de chauffe, 30 mesurées, 3 exécutions, médiane des 3 ; machine peu chargée (la charge d'autres processus fausse le p95).

Un écran qui dépasse son budget ouvre un chantier `optimize`. L'ordre des leviers reste celui de l'ADR-0062 : **index d'abord, requête réécrite ensuite, cache en dernier recours**, et un cache s'ADR.

**Leviers appliqués par ce chantier** (aucun contrat changé, aucune vue modifiée) :

1. `exercise_sessions (classroom_assignment_id, student_id) INCLUDE (score_percent) WHERE status = 'completed' AND kind = 'standard'`, et `StudentWorkQuery#totals_by` qui part des adhésions présentes des classes (mêmes définitions, ADR-0065 §4). *Remplacé le 2026-10-04 par le même index sans condition sur `kind` : voir la note en fin d'ADR.*
2. Les index de période annoncés par l'ADR-0062 : `exercise_sessions (started_at, student_id)`, `exercise_sessions (completed_at) INCLUDE (student_id, score_percent) WHERE status = 'completed'`, `users (created_at, id)`, `classroom_assignments (assigned_at)` ; puis une seule lecture groupée des élèves placés du pilotage au lieu de quatre (mêmes définitions).
3. L'extension `pg_trgm` et cinq index GIN trigrammes sur les expressions de recherche (amendement de l'ADR-0062).
4. En dernier recours, pour la seule vue « année » du pilotage : ses agrégats gardés 5 minutes dans Solid Cache (second amendement de l'ADR-0062, décision du porteur).

## 5. Conséquences

### 🟢 Positives

- « Lent » devient un nombre, écran par écran, avec un jeu et une méthode que n'importe qui rejoue (`docs/chantiers/cache-ecrans-lourds/journal.md#protocole`).
- Le budget complète celui de l'ADR-0051 : le navigateur paie le poids une fois, le serveur et le téléphone paient le HTML à chaque page.
- Une query CQRS qui dépasse seule le budget de sa page casse le test `PERF=1`, sans attendre la production.

### 🔴 Coûts consentis

- **La CI ne vérifie pas les budgets.** Ils se vérifient avant la recette et dans les chantiers qui touchent ces écrans. Une régression entre deux recettes peut passer.
- **Le test `PERF=1` tourne en environnement de test** (Bullet, journal SQL, pas d'eager load) : il est plus lent que la production, donc pessimiste. À sa création, il était rouge sur le pilotage « année » (368 ms) ; il est vert depuis le cache de 5 minutes de cette vue, qui est mesurée à chaud (le froid est affiché, pas budgété).
- **Le test `PERF=1` ne voit que le SQL** des trois queries lourdes (pilotage, recherche, Travail des élèves). Le temps de rendu et le HTML ne se vérifient que par le script, et à la main.
- **Deux écrans sont hors budget HTML à la date de l'ADR** : la liste des établissements (578 Ko) et le catalogue (474 à 550 Ko). Leur correction (modale unique, fragment des cartes) attend la fin des lots UX qui touchent ces vues ; le fragment introduira un cache et donc un ADR. *Mise à jour du 2026-10-05 (chantier `politique-cache`, lots E3 et E4, décision du porteur) : le catalogue se lit par pages de 24 cartes chargées au défilement, sans cache de fragment (63 à 75 Ko, p95 35 à 55 ms). Les confirmations des établissements et des DRENA sont lues à la demande : établissements 222 Ko et p95 90 ms (le temps tient, le poids non), DRENA 121 Ko.*
- **Le pilotage « année » ne tient son budget qu'avec un cache.** Son coût croît avec les sessions de l'année scolaire (28 jours au 29 septembre, 270 en mai) : après les index, il restait à 304 ms en p95. Le porteur a retenu le 2026-09-29 de garder ses chiffres **5 minutes** ([ADR-0062, second amendement du 2026-09-29](./0062-indicateurs-de-pilotage-lus-en-direct.md#amendement-du-2026-09-29-second--les-chiffres-de-lannée-scolaire-sont-gardés-5-minutes)) : le budget porte sur l'entrée chaude ; la lecture froide, une fois par 5 minutes au plus, est mesurée et notée. Elle devra être remesurée avec un an de sessions.
- Les index ajoutés coûtent en écriture : `exercise_sessions` porte trois index de plus, `users` trois, `schools` trois, `classroom_assignments` un, maintenus à chaque session, inscription ou devoir. Ce coût **n'a pas été mesuré** ; les tests de performance d'import (`PERF=1`) restent le garde-fou des écritures massives.
- Le temps réseau entre Rails et PostgreSQL n'est pas dans le budget : sur Railway, un écran de 20 requêtes perd davantage qu'un écran de 7.

## 6. Notes d'implémentation

```ruby
# test/performance/school/heavy_screens_budget_test.rb — PERF=1, base de test, jeu complet semé puis VACUUM ANALYZE
PILOTAGE_MS = 300
SCREEN_MS = 100
budgets = {
  "pilotage 7 j" => [ PILOTAGE_MS, -> { dashboard("7d", today) } ],
  "pilotage année" => [ PILOTAGE_MS, -> { dashboard("year", today) } ],
  "recherche « kou »" => [ SCREEN_MS, -> { Queries::Identity::AccountSearchQuery.new.call(term: "kou") } ],
  "Travail des élèves" => [ SCREEN_MS, -> { Queries::School::StudentWorkQuery.new.classrooms(school_id: @focus) } ]
}
```

```bash
# La page entière, en mode production, sur la base de développement semée (protocole complet : journal du chantier)
bin/rails runner script/perf/seed_dataset.rb
RAILS_ENV=production … bin/rails runner script/perf/measure_screens.rb   # PERF_ONLY=dashboard,admin pour restreindre
```

## 7. Comment vérifier que la décision est respectée

- `PERF=1 PARALLEL_WORKERS=1 bin/rails test test/performance/school/heavy_screens_budget_test.rb` : le p95 SQL des trois queries lourdes, au volume de référence, sous le budget de leur page (la vue « année » à chaud ; son froid est affiché).
- `script/perf/measure_screens.rb` : p95 et Ko de chaque écran ; le tableau « après » du chantier qui touche un écran budgété est comparé à ce tableau-ci.
- `test/infrastructure/queries/trigram_search_indexes_test.rb` (dans la CI) : les expressions des recherches restent servies par leurs index trigrammes.
- Rien ne vérifie automatiquement le budget HTML : il se lit dans la colonne « Ko » du script.

## Note du 2026-10-04 — levier 1 : l'index des sessions rendues compte la remédiation

*Chantier de correction [`remediation-comptee-faite`](../../chantiers/remediation-comptee-faite/plan.md). La décision (budgets, méthode, ordre des leviers) est inchangée.*

- Une session de remédiation rattachée à un devoir est désormais « rendue » pour la direction ([ADR-0072, complément du 2026-10-04 (ter)](./0072-assignation-d-exercices-et-echeance-a-la-prochaine-seance.md)). L'index du levier 1 est remplacé, **sous le même nom** `index_exercise_sessions_handed_in` : `exercise_sessions (classroom_assignment_id, student_id) INCLUDE (score_percent) WHERE status = 'completed'`. Migration `20261004190000_count_remediation_in_handed_in_index` : construit `CONCURRENTLY` sous un nom provisoire, ancien index retiré `CONCURRENTLY`, puis renommé ; aucune étape ne bloque les écritures.
- `StudentWorkQuery#totals_by` et `DepartedStudentsQuery#totals` le lisent en *Index Only Scan* (0 *heap fetch*), sans parcours séquentiel de `exercise_sessions`. `AssignmentFollowUpQuery`, qui filtre encore `kind = 'standard'` sur `Develop`, reste servie par lui : sa condition implique celle de l'index.
- Mesuré sur une copie du jeu de référence (312 283 sessions) où les 14 698 sessions terminées qu'ADR-0043 aurait ouvertes en remédiation le sont (le jeu de `script/perf/dataset.rb` n'en sème aucune). Médiane de 3 exécutions de `measure_screens.rb`, avant → après : « Travail des élèves » p95 230 → 244 ms ; page d'une classe p95 53 → 58 ms ; requêtes et Ko inchangés (11 et 71,4 Ko ; 9 et 42,5 Ko). La requête des totaux, en A/B alterné sur les mêmes données : p50 74,3 → 76,3 ms. Détail et protocole : [`plan.md` du chantier](../../chantiers/remediation-comptee-faite/plan.md#mesures).
- **Écarts constatés, antérieurs à ce chantier** : « Travail des élèves » est **hors budget** (p95 230 ms avant toute modification, budget 100 ms), « Enseignants » de la direction pèse 441 Ko de HTML (budget 150 Ko), et « Anciens élèves », jamais mesurée jusqu'ici, prend **8,7 s** (la requête de la liste, pas celle des totaux). Ils sont notés au journal du chantier pour un chantier `optimize`.
