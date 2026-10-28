# Plan d'exécution — Corriger une copie comme en classe

> Le nombre d'agents n'est pas décidé ici : il est **égal au nombre de lots sans dépendance en attente**.
> Format des lots gelé dans [`guide/conventions.md`](../../guide/conventions.md#6-format-dun-lot).
> Références : [PRD](prd.md) · [ADR-XXXX-correction-complete-et-pause-de-recommencer](../../decisions/adr/XXXX-correction-complete-et-pause-de-recommencer.md) · [UDR-XXXX-resultat-corrige-comme-en-classe](../../decisions/udr/XXXX-resultat-corrige-comme-en-classe.md)

## Graphe

```
Lot 0 — SOCLE (séquentiel) : Appreciation, RestartPause, port recent_completions et son adaptateur, phrase de la pause
  ↓
  ├─► Lot A « le résultat corrigé comme en classe »   ┐
  └─► Lot B « la pause de Recommencer au démarrage »  ┘ en parallèle
```

Aucune migration, aucune route nouvelle.

---

## Lot 0 — Socle

- **Couche**       : domaine (entités, contrat) + infrastructure (adaptateur du port) + locale partagée
- **Fichiers**     : `app/domain/entities/assessment/appreciation.rb`
                     `app/domain/entities/assessment/restart_pause.rb`
                     `app/domain/ports/assessment/exercise_session_repository_port.rb` *(ajout de `recent_completions`)*
                     `app/infrastructure/repositories/assessment/exercise_session_repository.rb` *(ajout de `recent_completions`)*
                     `config/locales/assessment/restart_pause.fr.yml` *(nouveau : la phrase « Tu pourras recommencer à %{time}. », lue par A et B)*
                     `test/domain/entities/assessment/appreciation_test.rb`
                     `test/domain/entities/assessment/restart_pause_test.rb`
                     `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb`
- **Dépend de**    : —
- **Test associé** : `test/domain/entities/assessment/appreciation_test.rb` (CA-07 : seuils sur la note affichée, 79 % → « Très bien » ; questions en cause ; portée notion ou leçon ; rien à revoir au sans-faute)
                     `test/domain/entities/assessment/restart_pause_test.rb` (CA-13 à CA-16 au niveau de la règle : 3 copies d'affilée, bornes 29 min 59 s et 30 min, écart de 30 min qui casse la série, moins de 3 copies)
                     `test/infrastructure/repositories/assessment/exercise_session_repository_test.rb` (`recent_completions` : copies rendues seulement, abandonnées exclues, toutes sortes, par exercice, la plus récente d'abord, `limit` respecté)
- **Done quand**   : les deux entités et `recent_completions` sont testées au vert ; `bin/rails runner "puts Entities::Assessment::RestartPause.name, Entities::Assessment::Appreciation.name"` répond ; le contrat du port est gelé

Contrat gelé par le Lot 0 :

```ruby
# Entities::Assessment::Appreciation
Appreciation = Data.define(:level, :missed_numbers, :essential)
Appreciation.for(score_percent:, review:, essential:)
# level ∈ :very_good, :good, :fair, :rework, selon Grading.grade_on_20(score_percent)
# review : la correction du résultat ; une question est en cause si verdict faux ou sans réponse
# essential : nil pour un exercice de toute la leçon
# missed_numbers : numéros des questions en cause, croissants ; [] au sans-faute

# Entities::Assessment::RestartPause
RestartPause::SERIES  # 3
RestartPause.until(completions:, now:)   # → Time | nil

# Ports::Assessment::ExerciseSessionRepositoryPort
recent_completions(student_id:, exercise_id:, limit:)   # → [Time], copies completed, la plus récente d'abord
```

---

## Lot A — Le résultat corrigé comme en classe

- **Couche**       : domaine (policy) + delivery + ui
- **Fichiers**     : `app/domain/policies/assessment/reveal_correction_policy.rb`
                     `app/controllers/assessment/session_results_controller.rb`
                     `app/views/assessment/session_results/show.html.erb`
                     `app/views/assessment/session_results/_question_review.html.erb`
                     `app/views/assessment/session_results/kinds/_choice_review.html.erb`
                     `app/views/assessment/session_results/kinds/_fill_blank_review.html.erb` *(en-tête et local `owner` seulement)*
                     `app/views/assessment/session_results/kinds/_numeric_review.html.erb` *(idem)*
                     `app/views/assessment/session_results/kinds/_ordering_review.html.erb` *(idem)*
                     `app/views/assessment/session_results/kinds/_matching_review.html.erb` *(idem)*
                     `config/locales/assessment/session_results.fr.yml`
                     `test/domain/policies/assessment/reveal_correction_policy_test.rb`
                     `test/controllers/assessment/session_results_controller_test.rb`
                     `test/system/assessment/copy_correction_test.rb`
                     `test/system/assessment/session_result_test.rb` *(« Félicitations ! » et « Courage ! » deviennent l'appréciation)*
                     `test/integration/assessment/question_fill_blank_test.rb` *(la correction de l'élève montre désormais les réponses acceptées)*
                     `test/integration/assessment/question_numeric_test.rb` *(idem : la valeur attendue, au résultat seulement)*
                     `test/integration/assessment/question_ordering_test.rb` *(idem : le bon ordre)*
                     `test/integration/assessment/question_matching_test.rb` *(idem : les bonnes paires)*
                     `script/ci/test_timings.yml` *(durées des deux tests système)*
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/policies/assessment/reveal_correction_policy_test.rb` (CA-06)
                     `test/controllers/assessment/session_results_controller_test.rb` (CA-01, CA-02, CA-03, CA-05, CA-08, CA-09, CA-10, CA-11, CA-12, CA-18 côté résultat)
                     `test/integration/assessment/question_{fill_blank,numeric,ordering,matching}_test.rb` (CA-02 par type ; la feuille d'une copie en cours ne révèle toujours rien)
                     `test/system/assessment/copy_correction_test.rb` (CA-04 et le parcours : copie en cours sans bonne réponse, « Rendre ma copie », titre-appréciation, « À revoir », bonne réponse marquée ; un seul test système, budget de 15 s)
- **Done quand**   : un élève rend sa copie Thalès et lit « Bien », « À revoir : … questions 2 et 4 », puis, pour chaque question, son choix, la bonne réponse et l'explication. Son enseignant lit la même appréciation sans la phrase d'encouragement. Après une 3e copie d'affilée, le résultat dit « Tu pourras recommencer à … » au lieu de « Refaire l'exercice »

---

## Lot B — La pause de « Recommencer » au démarrage

- **Couche**       : domaine (use case) + delivery + ui
- **Fichiers**     : `app/domain/use_cases/assessment/start_exercise_session.rb`
                     `app/controllers/assessment/exercise_sessions_controller.rb`
                     `app/controllers/assessment/exercises_controller.rb`
                     `app/views/assessment/exercises/show.html.erb`
                     `config/locales/assessment/exercise_sessions.fr.yml`
                     `test/domain/use_cases/assessment/start_exercise_session_test.rb`
                     `test/controllers/assessment/exercise_sessions_controller_test.rb`
                     `test/controllers/assessment/exercises_controller_test.rb`
                     `test/integration/assessment/best_grade_after_retake_test.rb`
- **Dépend de**    : Lot 0
- **Test associé** : `test/domain/use_cases/assessment/start_exercise_session_test.rb` (CA-13 à CA-17 au niveau du use case : refus `:paused` sans abandon ni création, fin de pause, copie en cours toujours reprise, exercices distincts)
                     `test/controllers/assessment/exercise_sessions_controller_test.rb` (CA-13 par la requête : 303 vers l'exercice, alerte, aucune copie créée)
                     `test/controllers/assessment/exercises_controller_test.rb` (CA-18 côté exercice ; non-régression : aucune bonne réponse pour l'élève sur la page de l'exercice)
                     `test/integration/assessment/best_grade_after_retake_test.rb` (CA-19 : la meilleure note du devoir, inchangée)
- **Done quand**   : un élève qui vient de rendre 3 copies d'affilée ne peut plus en ouvrir une 4e, ni depuis la page de l'exercice ni depuis l'accueil. La page de l'exercice lui dit à quelle heure il pourra recommencer, et à cette heure le bouton revient

---

## Rattachement des critères d'acceptation

| CA | Lot | CA | Lot |
|---|---|---|---|
| CA-01 | A | CA-11 | A |
| CA-02 | A | CA-12 | A |
| CA-03 | A | CA-13 | 0 (règle) · B (refus) |
| CA-04 | A (système) | CA-14 | 0 · B |
| CA-05 | A | CA-15 | 0 · B |
| CA-06 | A | CA-16 | 0 (dépôt) · B |
| CA-07 | 0 | CA-17 | 0 (dépôt) · B |
| CA-08 | A | CA-18 | A (résultat) · B (exercice) |
| CA-09 | A | CA-19 | B |
| CA-10 | A | | |

Aucun critère orphelin.

---

## Vérification de collision

> Deux lots ne listent jamais le même fichier. Contrôle : `awk '/^## Vérification de collision/{exit} 1' plan.md | grep -oE '(app|test|config|db|lib|script)/[A-Za-z0-9_/.-]+\.(rb|erb|yml|js)' | sort | uniq -d`.
> Il ne sort que des fichiers de test cités deux fois **dans le même lot** (champs `Fichiers` et `Test associé`) : aucun fichier n'est partagé entre deux lots.

| Fichier | Lot propriétaire |
|---|---|
| `app/domain/ports/assessment/exercise_session_repository_port.rb` | Lot 0 |
| `app/infrastructure/repositories/assessment/exercise_session_repository.rb` | Lot 0 |
| `app/domain/entities/assessment/restart_pause.rb` (lu par A et B) | Lot 0 |
| `config/locales/assessment/restart_pause.fr.yml` (lu par A et B) | Lot 0 |
| `config/locales/assessment/session_results.fr.yml` | Lot A |
| `config/locales/assessment/exercise_sessions.fr.yml` | Lot B |
| `script/ci/test_timings.yml` (seul A ajoute un test système) | Lot A |
| `config/routes.rb`, `app/views/layouts/`, navigation, `db/` | aucun lot n'y touche |

Points d'attention :

- **La page de l'exercice** (`exercises/show`) affiche la pause : elle appartient au Lot B. Elle lit `RestartPause` et `recent_completions` du Lot 0 ; elle ne touche à aucune vue du Lot A.
- **Les tests qui figent l'ancienne règle** (« l'élève ne voit jamais la bonne réponse ») sont au Lot A : `question_*_test.rb` et `session_result_test.rb`. Leurs assertions sur la feuille d'une copie en cours restent ; seules celles du résultat de l'élève s'inversent. `answer_leak_test.rb` (page de l'exercice) ne change pas.
- **La page du résultat** affiche la pause : elle appartient au Lot A, qui calcule la fin de la pause dans `SessionResultsController`. Le refus réel est celui du Lot B.

## Dispatch

```
Vague 1 : Lot 0           → 1 agent, séquentiel
Vague 2 : Lot A ‖ Lot B   → 2 agents, worktrees isolés, branches depuis origin/Develop une fois la PR du Lot 0 fusionnée
```

```bash
git worktree add ../lnclass-correction-comme-en-classe-lot-a -b feature/correction-comme-en-classe-lot-a origin/Develop
git worktree add ../lnclass-correction-comme-en-classe-lot-b -b feature/correction-comme-en-classe-lot-b origin/Develop
```

Exécutants : `executant-lot` (Sonnet). Revues sur le diff final (`security-reviewer`, `silent-failure-hunter`, `pr-test-analyzer`) : une policy, un use case et une vue de correction changent. **Une PR par lot vers `Develop`** (décision du 2026-10-28, comme pour la refonte de la page de la leçon) :
- chaque lot part de `origin/Develop` à jour, sur sa branche `feature/correction-comme-en-classe-lot-<x>` ;
- A et B partent une fois la PR du Lot 0 fusionnée ;
- chaque PR contient la ligne de preuve de `bin/ci-quiet` et ses revues.
- la PR du Lot 0 part de `feature/correction-comme-en-classe` (branche `feature/correction-comme-en-classe-lot-0`) pour porter le cadrage ; elle numérote l'ADR et l'UDR (`script/docs/build_index --number`), puisque `Develop` refuse un `XXXX-`.

## Portes de sortie

- [ ] `memo.md` complet, section `Hors périmètre` non vide
- [ ] Grill fait : ≥ 1 ligne dans `Ce que le grill a révélé`
- [ ] `prd.md` : critères d'acceptation en Gherkin, tous testables
- [ ] ADR écrit si un port / une table / un contrat apparaît, nommé `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] UDR écrite pour **chaque** vue créée ou modifiée, nommée `XXXX-<slug>.md` (numéro et index posés à la clôture)
- [ ] `plan.md` : 4 champs par lot, tableau de collision rempli
- [ ] Lot 0 mergé et ports gelés avant tout lot parallèle
- [ ] Chaque critère d'acceptation a son test, écrit avant le code et rouge d'abord
- [ ] En-tête HITL sur chaque fichier créé dans `app/`
- [ ] Un rôle distinct a exécuté le parcours nominal + un chemin d'erreur
- [ ] Pureté domaine · rubocop · tests · brakeman : au vert
- [ ] Une PR par lot vers `Develop` (décision du 2026-10-28), chacune référençant chantier + ADR + UDR
- [ ] `journal.md` clos (dérapages, dette, chantiers de suivi)

## Challenger (phase 5)

> **Challenger empirique — non négociable.** Un rôle **distinct de celui qui a écrit le code** exécute : il lance les tests, ouvre l'application, refait le parcours nominal *et* un chemin d'erreur, mesure. **Il ne relit pas le code, il le met à l'épreuve.** Un reviewer qui lit du code ne prouve rien.

Pour ce chantier :
- **Parcours nominal** : rendre la copie Thalès avec 2 fautes, lire l'appréciation, « À revoir » et les bonnes réponses.
- **Chemin d'erreur** : rendre 3 copies d'affilée, puis tenter une 4e depuis l'accueil, et constater le refus et l'heure.
