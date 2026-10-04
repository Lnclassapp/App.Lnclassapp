# Plan d'exécution — Comprendre où en est la classe sur un exercice

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Entrées : [memo](memo.md) · [PRD](prd.md) · [ADR-0079](../../decisions/adr/0079-lecture-de-la-comprehension-d-un-exercice-assigne.md) · [UDR-0072](../../decisions/udr/0072-comprehension-d-un-exercice-assigne.md)

**Préalable (programme `refonte-application`)** : l'ADR-0079 et l'UDR-0072 sont au statut `Proposé`. Ils passent à `Accepté` avec la validation de ce plan par le porteur, **avant** le Lot 0. Ils consomment des décisions déjà acceptées : ADR-0033, ADR-0048, ADR-0067 et ADR-0072.

**Ce que le chantier ne crée pas** : aucune migration, aucune table, aucun port, aucun use case, aucune route. C'est de la lecture pure (CQRS, ADR-0026), sous une policy existante.

## Graphe

```
Lot 0 — SOCLE (séquentiel, court)
  règles de domaine · lecture socle des scores · tokens · helper · partiels partagés · locales
  ↓
  ├─► Lot A « badges et cercle au bord bas, page classe »          ┐ en parallèle,
  └─► Lot B « section Compréhension de la page de suivi »          ┘ fichiers disjoints
        ↓ (A et B mergés)
      Lot C « preuve : parcours système et budget »
```

---

## Lot 0 — Socle

- **Couche**       : domaine + infrastructure (lecture socle) + ui partagée (tokens, helper, partiels, locales)
- **Fichiers**     : `app/domain/entities/assessment/comprehension.rb`
                     `app/infrastructure/queries/assessment/assignment_scores.rb`
                     `app/helpers/assessment/comprehension_helper.rb`
                     `app/views/assessment/comprehension/_circle.html.erb`
                     `app/views/assessment/comprehension/_badge_counts.html.erb`
                     `app/assets/stylesheets/application.tailwind.css` *(partagé : tokens)*
                     `config/locales/assessment/comprehension.fr.yml` *(partagé)*
                     `test/domain/entities/assessment/comprehension_test.rb`
                     `test/infrastructure/queries/assessment/assignment_scores_test.rb`
                     `test/helpers/assessment/comprehension_helper_test.rb`
                     `test/design/dark_mode_test.rb` *(partagé)*
- **Dépend de**    : — (ADR-0079 et UDR-0072 acceptés)
- **Test associé** : `test/domain/entities/assessment/comprehension_test.rb` · `test/infrastructure/queries/assessment/assignment_scores_test.rb` · `test/helpers/assessment/comprehension_helper_test.rb`
- **Done quand**   : les règles de domaine passent aux bornes du PRD §4 « Règles de domaine » (catégories 49/50/69/70 ; séries 30-60-90, 60-60-60, 30-90-40, 90-40, 100-100, 50-59, 50-60, 80-90-81, 80-90-80, un seul essai ; égalités ; 4 et 5 élèves). La lecture socle exclut la remédiation, une autre classe, une session commencée, un élève parti ou anonymisé, et désigne le meilleur essai le plus récent à égalité. `bin/rails runner "puts Entities::Assessment::Comprehension.name, Queries::Assessment::AssignmentScores.name"` répond. Les quatre tokens existent dans les deux thèmes.

**Contrats gelés par le Lot 0** (les lots A et B les consomment, ne les modifient pas) :

```ruby
# Entities::Assessment::Comprehension — ADR-0079 §6, tel quel
PROGRESS_MARGIN = 10 ; MIN_DONE_FOR_READING = 5 ; CATEGORIES = %i[struggling fragile acquired]
.category_for(best) → Symbol   .trend_for(scores) → nil | Symbol   .dominant(counts) → nil | Symbol   .readable?(done) → Boolean

# Queries::Assessment::AssignmentScores — lecture socle, une requête quel que soit le nombre d'assignations
StudentScores = Data.define(:student_id, :scores, :best_session_id)
# scores : score_percent des sessions faites, ordre (completed_at, id) ; best_session_id : session de score max, la plus récente à égalité
.for(classroom_id:, assignment_ids:) → { assignment_id => [StudentScores] }   # absente = aucun fait
# « fait » et « présent » : réutilise Queries::Classroom::AssignmentFollowUpQuery.present_students (même définition, ADR-0072 §4.4)

# Partiels : assessment/comprehension/_circle  locals: (category:, done:, present:, size: :sm)
#            assessment/comprehension/_badge_counts  locals: (counts:)   # { bronze:, silver:, gold:, diamond: }
# Helper   : Assessment::ComprehensionHelper — UDR-0072 §3.2, toutes les méthodes
# Locales  : assessment.comprehension.* — UDR-0072 §3.7, toutes les clés (celles de la section comprises)
```

---

## Lot A — Badges et cercle au bord bas d'un exercice, page classe

- **Couche**       : infrastructure + ui (aucun domaine nouveau, aucun contrôleur modifié)
- **Fichiers**     : `app/infrastructure/queries/assessment/comprehension_summary_query.rb`
                     `app/infrastructure/queries/classroom/classroom_overview_query.rb`
                     `app/views/classroom/classrooms/_assigned_exercises.html.erb`
                     `test/infrastructure/queries/assessment/comprehension_summary_query_test.rb`
                     `test/infrastructure/queries/classroom/classroom_overview_query_test.rb`
                     `test/controllers/classroom/classrooms_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/assessment/comprehension_summary_query_test.rb` · `test/controllers/classroom/classrooms_controller_test.rb`
- **Done quand**   : sur la page d'une classe, l'enseignant voit au bord bas de chaque exercice assigné les quatre badges à gauche (Bronze jamais omis, zéro atténué) et, à droite, le cercle de la catégorie dominante avec « 6/25 ». Le cercle est gris sous 5 faits. L'équipe voit la même chose. Les comptes « faits / en retard / pas encore faits » sont inchangés. Le nombre de requêtes ne dépend pas du nombre d'exercices assignés.

Contenu attendu :
- `ComprehensionSummaryQuery.for(classroom_id:, assignment_ids:)` → `{ assignment_id => Summary }`, avec `Summary = Data.define(:category, :badge_counts)`.
  - `category` : `Comprehension.dominant`, ou `nil` si non lisible.
  - `badge_counts` : `Grading.badge_for(best)` compté par palier, les quatre clés toujours présentes.
  - Une seule lecture, par `AssignmentScores.for`.
- `ClassroomOverviewQuery::AssignmentRow` gagne `comprehension` (un `Summary`), `nil` sans `show_follow_up`, exactement comme `counts`.
- Vue : UDR-0072 §3.4.

Critères du PRD couverts :
- « badges et cercle au bord bas » ;
- « cercle gris sous 5 élèves » ;
- « seules les sessions de l'assignation comptent » (côté page classe) ;
- « élèves partis ou anonymisés exclus » ;
- « la page classe reste lisible pour l'équipe et muette pour l'élève » ;
- « les comptes existants ne bougent pas » (page classe).

---

## Lot B — Section « Compréhension » de la page de suivi

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/comprehension_detail_query.rb`
                     `app/controllers/classroom/assignment_follow_ups_controller.rb`
                     `app/views/assessment/comprehension/_section.html.erb`
                     `app/views/classroom/assignment_follow_ups/show.html.erb`
                     `test/infrastructure/queries/assessment/comprehension_detail_query_test.rb`
                     `test/controllers/classroom/assignment_follow_ups_controller_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/infrastructure/queries/assessment/comprehension_detail_query_test.rb` · `test/controllers/classroom/assignment_follow_ups_controller_test.rb`
- **Done quand**   : sur la page de suivi d'un exercice assigné, l'enseignant voit la section « Compréhension » :
  - le grand cercle et « 18/25 » ;
  - la synthèse « N en progrès · N sans évolution · N en baisse » ;
  - les trois catégories avec leur nombre d'élèves.

  En touchant une catégorie, il voit le taux de chaque question (jamais au-dessus de 100 %, « — » sans tentative) et ses élèves avec meilleur score et signe. L'adresse porte `?category=`, une catégorie inconnue est ignorée, et la page marche sans JavaScript. L'élève, un autre enseignant et la direction reçoivent 403. Les trois chiffres et les rendus en retard sont inchangés.

Contenu attendu :
- `ComprehensionDetailQuery#call(classroom_public_id:, assignment_public_id:, category:)` renvoie un `Detail`, ou `nil` si l'assignation est inconnue ou archivée. La query résout elle-même les identifiants internes, comme `AssignmentFollowUpQuery` : le contrôleur ne touche jamais l'ORM.
  - `Detail = Data.define(:done, :present, :category, :readable, :category_counts, :trend_counts, :selected, :questions, :students)`.
  - `category_counts` : `{ struggling:, fragile:, acquired: }`.
  - `trend_counts` : `{ progress:, flat:, decline: }`.
  - `selected` : la catégorie demandée si valide, sinon la dominante, sinon `:struggling`.
  - `questions` : `[QuestionRate(number, content, rate_or_nil)]`, dans l'ordre de `position`, lus sur les `best_session_id` des élèves de `selected`.
  - `students` : `[StudentRow(display_name, best, trend)]` de `selected`, triés par nom.
- Contrôleur : après `FollowAssignmentPolicy` et le chargement du suivi, il lit `params[:category]` sur la liste blanche `Comprehension::CATEGORIES` et charge `@comprehension`. `AssignmentFollowUpQuery` n'est pas modifiée : ce fichier n'est dans aucun lot, et s'il faut le changer, il remonte au Lot 0.
- Vues : UDR-0072 §3.5 et §3.6.

Critères du PRD couverts :
- « synthèse et catégories » ;
- « taux par question pour une catégorie » ;
- « meilleur essai à égalité » ;
- « liste des élèves d'une catégorie » ;
- « catégorie dans l'adresse » ;
- « refus » ;
- « les comptes existants ne bougent pas » (page de suivi).

---

## Lot C — Preuve : parcours système et budget

- **Couche**       : tests système + mesure
- **Fichiers**     : `test/system/classroom/comprehension_test.rb`
                     `script/perf/measure_screens.rb`
- **Dépend de**    : Lot A, Lot B
- **Test associé** : `test/system/classroom/comprehension_test.rb`
- **Done quand**   : dans un navigateur réel, un enseignant fait le parcours complet :
  - il ouvre sa classe et voit les badges et le cercle d'un exercice ;
  - il ouvre le suivi et choisit « Fragile » ;
  - il voit les taux et les élèves, puis recharge la page sans perdre la catégorie.

  Un élève qui force l'adresse du suivi reçoit 403. `script/perf/measure_screens.rb` mesure la page classe et la page de suivi sous **100 ms p95** et **150 Ko** de HTML au volume de l'ADR-0067. Les chiffres sont reportés dans `prd.md` §7.

Critères du PRD couverts : « budget de l'écran », et le parcours nominal et un chemin d'erreur rejoués de bout en bout.

---

## Vérification de collision

> Faite le 2026-10-04. Le `uniq -d` brut ne renvoie que des fichiers de test cités deux fois **dans un même lot** (champs `Fichiers` et `Test associé`). Recompté lot par lot, il ne reste **aucune collision entre lots**. Les fichiers partagés sont tous au Lot 0.

| Fichier | Lot propriétaire |
|---|---|
| `app/assets/stylesheets/application.tailwind.css` | Lot 0 |
| `config/locales/assessment/comprehension.fr.yml` | Lot 0 |
| `test/design/dark_mode_test.rb` | Lot 0 |
| `app/views/assessment/comprehension/_circle.html.erb` | Lot 0 (rendu par A et B) |
| `app/views/assessment/comprehension/_badge_counts.html.erb` | Lot 0 (rendu par A) |
| `app/helpers/assessment/comprehension_helper.rb` | Lot 0 (utilisé par A et B) |
| `app/infrastructure/queries/assessment/assignment_scores.rb` | Lot 0 (lu par A et B) |
| `app/infrastructure/queries/classroom/assignment_follow_up_query.rb` | **aucun** : lu, jamais modifié ; s'il doit l'être, il remonte au Lot 0 |
| `config/routes.rb`, `config/routes/classroom.rb` | **aucun** : pas de route nouvelle |
| `test/support/factories/*.rb` | **aucun** : les fabriques existantes suffisent (`create_exercise_session`, `create_attempt`, `create_assignment`) ; un besoin nouveau remonte au Lot 0 |
| `script/perf/measure_screens.rb` | Lot C |

## Dispatch

```
Vague 1 : Lot 0                 → 1 agent, séquentiel, sur feature/rapports-exercices
Vague 2 : Lot A ‖ Lot B         → 2 agents, worktrees isolés
Vague 3 : Lot C                 → 1 agent, après merge de A et B
```

```bash
git worktree add ../lnclass-rapports-exercices-lot-a -b feature/rapports-exercices-lot-a feature/rapports-exercices
git worktree add ../lnclass-rapports-exercices-lot-b -b feature/rapports-exercices-lot-b feature/rapports-exercices
```

Chaque agent de lot reçoit :
- le chemin **absolu** de son worktree ;
- son lot recopié en entier ;
- les liens vers le PRD, l'ADR-0079 et l'UDR-0072 ;
- l'ordre intra-lot : **test rouge → domaine → infrastructure → delivery → UI**.

Deux consignes l'accompagnent :
- chemins absolus, `git -C <worktree>` ;
- **interdiction de toucher un fichier hors de son champ `Fichiers`** : s'il en a besoin, il s'arrête et remonte.

Chaque fichier créé dans `app/` porte l'en-tête HITL. Les lots sont mergés dans `feature/rapports-exercices`, avec une seule PR vers `Develop` : [Lnclassapp/App.Lnclassapp#164](https://github.com/Lnclassapp/App.Lnclassapp/pull/164).

## Portes de sortie

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

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.
>
> Ici, il rejoue chaque critère du PRD §4 dans l'application, sur une classe préparée avec les séries de la §4. Il vérifie notamment :
> - le cercle gris à 4 faits et coloré à 5 ;
> - un taux de question qui reste sous 100 % après un deuxième essai ;
> - le 403 d'un élève sur l'adresse du suivi ;
> - le mode sombre ;
> - le budget mesuré par `script/perf/measure_screens.rb`.
