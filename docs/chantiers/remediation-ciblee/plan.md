# Plan d'exécution — Remédiation ciblée

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> **Plan écrit selon les recommandations du [memo](memo.md#ce-que-le-grill-a-révélé).** Il ne démarre qu'après validation de Q1 à Q12 par le porteur ; une réponse contraire le modifie d'abord.

## Graphe

```
Lot 0 — sans objet (aucun contrat partagé, aucun fichier partagé : voir ci-dessous)

  ├─► Lot A « élève : la fiche propose et démarre l'exercice »   ┐
  ├─► Lot B « élève : le résultat dit l'effet sur la fiche »     ├─ en parallèle, fichiers disjoints
  └─► Lot C « enseignant : fiches à revoir de la classe »        ┘
          ↓ (A, B, C fusionnés)
      Lot D « preuve bout en bout »
```

**Pourquoi pas de Lot 0.** Il n'y a ni migration, ni route, ni port, ni entité partagée (ADR-0101). Chaque règle pure n'a qu'un lecteur : `RemediationPick` sert le Lot A, `GapOutcome` le Lot B. Les fichiers de traduction sont découpés par vue (`catalog/essentials.fr.yml`, `assessment/session_results.fr.yml`, `classroom/classrooms.fr.yml`, …). Aucun ne se retrouve dans deux lots. `config/routes.rb`, les layouts et la navigation ne changent pas.

**Commits.** Un commit par lot, documentation du lot comprise (CLAUDE.md, sobriété). Une seule PR `feature/remediation-ciblee` → `Develop`.

---

## Lot A — L'élève : la fiche propose un exercice choisi et le démarre d'un tap

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/entities/assessment/remediation_pick.rb` *(nouveau)*
                     `app/infrastructure/queries/catalog/essential_detail_query.rb`
                     `app/views/catalog/essentials/show.html.erb`
                     `app/views/communication/help/show.html.erb`
                     `config/locales/catalog/essentials.fr.yml`
                     `config/locales/communication/help.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/remediation_pick_test.rb` *(nouveau)* : fixation autre que la source ; autre que la source sans fixation ; source seule ; source de type fixation écartée ; liste vide
                     `test/infrastructure/queries/catalog/essential_detail_query_test.rb` : `GapRow#exercise` (source lue par `source_session_id`, exercice archivé exclu, aucun exercice → `nil`)
                     `test/controllers/catalog/essentials_controller_test.rb` : formulaire POST vers `exercise_sessions_path` de l'exercice proposé, « Exercice proposé : … », « 15/20 », jamais « 75 % »
                     `test/controllers/communication/help_controller_test.rb` : « 10/20 » et « 15/20 »
- **Done quand**   : une élève dont la fiche est à revoir touche « Refaire un exercice » et se retrouve dans une session `remediation` d'un exercice de fixation autre que celui raté ; l'encart et l'aide disent « 15/20 »

---

## Lot B — L'élève : le résultat dit ce qu'il advient de sa fiche

- **Couche**       : domaine + infrastructure + ui
- **Fichiers**     : `app/domain/entities/assessment/gap_outcome.rb` *(nouveau)*
                     `app/infrastructure/queries/assessment/session_result_query.rb`
                     `app/views/assessment/session_results/show.html.erb`
                     `app/views/assessment/session_results/_gap_outcome.html.erb` *(nouveau)*
                     `config/locales/assessment/session_results.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/gap_outcome_test.rb` *(nouveau)* : `:opened`, `:lifted` (`remediated` et `self_corrected`), `:still_pending`, `nil` (sans lacune ; lacune levée par une autre session)
                     `test/infrastructure/queries/assessment/session_result_query_test.rb` : `gap_outcome` pour chaque cas, en une requête de plus au plus
                     `test/controllers/assessment/session_results_controller_test.rb` : ligne rendue pour le propriétaire, absente pour l'enseignant et l'équipe ; « Félicitations ! » et « Encore à revoir » ensemble à 70 % en remédiation
- **Done quand**   : sur son résultat, l'élève lit « Cette fiche passe à revoir » à 30 %, « Encore à revoir : vise 15/20 » à 70 % en remédiation, « Fiche levée ! » à 80 % ; l'enseignant ne lit aucune de ces lignes

---

## Lot C — L'enseignant : les fiches à revoir de sa classe

- **Couche**       : infrastructure + delivery + ui
- **Fichiers**     : `app/infrastructure/queries/assessment/classroom_gaps_query.rb` *(nouveau)*
                     `app/controllers/classroom/classrooms_controller.rb`
                     `app/controllers/classroom/classroom_essentials_controller.rb`
                     `app/views/classroom/classrooms/show.html.erb`
                     `app/views/classroom/classrooms/_gaps.html.erb` *(nouveau)*
                     `app/views/classroom/classroom_essentials/show.html.erb`
                     `app/views/classroom/classroom_essentials/_gaps.html.erb` *(nouveau)*
                     `config/locales/classroom/classrooms.fr.yml`
                     `config/locales/classroom/classroom_essentials.fr.yml`
- **Dépend de**    : —
- **Test associé** : `test/infrastructure/queries/assessment/classroom_gaps_query_test.rb` *(nouveau)* : `summary` (tri, cours filtrés, fiche dépubliée exclue) et `detail` (ordre des deux groupes, levées de l'année seulement, `self_corrected` dans « levées »), élève parti, élève anonymisé ; nombre de requêtes constant à 1 et à 30 élèves
                     `test/controllers/classroom/classrooms_controller_test.rb` : bloc présent avec 2 élèves, absent sans lacune ; autre matière invisible pour l'enseignant, visible pour l'équipe
                     `test/controllers/classroom/classroom_essentials_controller_test.rb` : noms, « depuis le », « 3 essais sous la moyenne » dès 2 échecs ; aucun `public_id` d'élève dans le HTML ; refus inchangés (autre enseignant, direction, élève)
- **Done quand**   : l'enseignant voit sur la page de sa classe « Théorème de Thalès · 2 élèves », l'ouvre, et lit qui est à revoir et qui a levé la fiche cette année ; requêtes et p95 mesurés et notés au PRD §7

---

## Lot D — Preuve bout en bout

- **Couche**       : tests système
- **Fichiers**     : `test/system/assessment/remediation_test.rb` *(nouveau)*
                     `script/ci/test_timings.yml` *(régénéré par `script/ci/record_timings`)*
- **Dépend de**    : Lot A, Lot B, Lot C
- **Test associé** : `test/system/assessment/remediation_test.rb` : **un seul** parcours réel dans Chromium. L'élève échoue (« passe à revoir »), retrouve la fiche sur son accueil, touche « Refaire un exercice », réussit (« Fiche levée ! »), et la fiche quitte l'accueil. Puis l'enseignant voit l'élève dans « Fiche levée ».
- **Done quand**   : la porte V5 de la feuille de route est franchie (« le parcours **réel** de l'élève crée et résout les lacunes, et lance la remédiation ») ; la garde `test/guards/system_budget_test.rb` passe, ou le porteur accorde une rallonge

---

## Vérification de collision

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/entities/assessment/remediation_pick.rb` | A |
| `app/infrastructure/queries/catalog/essential_detail_query.rb` | A |
| `app/views/catalog/essentials/show.html.erb` | A |
| `app/views/communication/help/show.html.erb` | A |
| `config/locales/catalog/essentials.fr.yml` | A |
| `config/locales/communication/help.fr.yml` | A |
| `app/domain/entities/assessment/gap_outcome.rb` | B |
| `app/infrastructure/queries/assessment/session_result_query.rb` | B |
| `app/views/assessment/session_results/show.html.erb` | B |
| `app/views/assessment/session_results/_gap_outcome.html.erb` | B |
| `config/locales/assessment/session_results.fr.yml` | B |
| `app/infrastructure/queries/assessment/classroom_gaps_query.rb` | C |
| `app/controllers/classroom/classrooms_controller.rb` | C |
| `app/controllers/classroom/classroom_essentials_controller.rb` | C |
| `app/views/classroom/classrooms/show.html.erb`, `_gaps.html.erb` | C |
| `app/views/classroom/classroom_essentials/show.html.erb`, `_gaps.html.erb` | C |
| `config/locales/classroom/classrooms.fr.yml` | C |
| `config/locales/classroom/classroom_essentials.fr.yml` | C |
| `test/system/assessment/remediation_test.rb`, `script/ci/test_timings.yml` | D |
| `config/routes.rb`, layouts, navigation | personne (inchangés) |
| `test/support/factories/assessment.rb` | **à surveiller** : si deux lots doivent l'étendre, l'extension remonte dans un commit préalable de la branche de chantier, avant A, B et C |

## Risques

- **Fabriques irréalistes** (leçon de `progres-eleve`, D1) : une session ouverte après un échec doit être `remediation`. Les tests des Lots A à C créent les sessions par `StartExerciseSession` ou par une fabrique qui respecte cette règle.
- **Budget système** (ADR-0069 §9) : un seul test système nouveau, qui joue des sessions courtes (2 questions).
- **Budget de la page de classe** (ADR-0067, 100 ms) : une requête de plus, mesurée au Lot C sur le jeu de l'ADR-0067. Ce jeu ne sème que des sessions `standard` : on applique la même correction de copie que `remediation-comptee-faite` avant la mesure.

## Portes de sortie

- [ ] Q1 à Q12 répondues ; ADR-0101 et UDR-0119 à 0121 passées « Accepté »
- [ ] Tous les lots sont `Done`
- [ ] Un rôle distinct de l'auteur a **exécuté** le résultat : tests lancés, parcours élève puis enseignant refait dans l'application
- [ ] Captures envoyées au porteur, non commitées : fiche, résultat (3 états), page de classe, fiche dans la classe, à 390 px et sur ordinateur, en clair et en sombre
- [ ] `bin/ci-quiet` au vert, verdict collé dans la PR (CI GitHub coupée, ADR-0069)
- [ ] Revue par sous-agents sur le diff final (une policy n'est pas touchée, mais une page nominative l'est) : `security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`
- [ ] Commit de clôture : `script/docs/build_index` pour les index ADR/UDR ; `docs/chantiers/README.md` mis à jour une fois ; feuille de route (AS-16, AS-17 livrées ; V5 close) ; ADR-0043 marqué « amendé par 0101 » ; `journal.md` complété
