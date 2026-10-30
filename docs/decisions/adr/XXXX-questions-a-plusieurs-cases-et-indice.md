# ADR-XXXX : Une question peut avoir plusieurs cases, notées case par case, et un indice dont l'ouverture se voit sur la copie
<!-- index
titre: Questions à plusieurs cases, points répartis par case, indice enregistré
statut: Accepté
problematique: Les exercices des maquettes demandent plusieurs valeurs dans une même question et proposent un indice, ce que ni la fiche ni les copies notées ne savent faire.
-->

| | |
|---|---|
| **Statut** | Proposé |
| **Date** | 2026-10-30 |
| **Chantier** | `docs/chantiers/je-m-entraine-dans-la-fiche` |
| **Remplace** | — (amende ADR-0115 §4 : le score se calcule sur des fractions de points, et `fill_blank`, `select` et `numeric` acceptent plusieurs `___`) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

Les maquettes (Thalès, Lentilles, Texte argumentatif) écrivent « AN (cm) = ___  MN (cm) = ___ » dans une seule question, ou une phrase à deux connecteurs à choisir. Elles proposent aussi un bouton « Indice ». Aujourd'hui, une question a une seule case : `fill_blank` et `select` refusent plus d'un `___`, et `numeric` n'a qu'une valeur. Aucune question n'a d'indice.

Le porteur veut ces deux choses pour tous les exercices, dans la fiche comme dans les interrogations et les devoirs (2026-10-30) :

- **Cases (grills 7 à 9)** : plusieurs cases pour `numeric`, `select` et `fill_blank`, une question gardant un seul type. Les points se répartissent par case, et une case juste sur deux vaut la moitié des points.
- **Indice (grills 10 et 11)** : dans une copie notée, l'indice ne coûte rien, mais l'enseignant voit qu'il a été ouvert.

Une copie se rend d'un bloc (`SubmitExerciseCopy`) : `question_attempts` n'existe qu'au rendu. Une ouverture d'indice, qui a lieu avant, ne peut donc pas s'y écrire.

## 2. Moteurs de décision

1. Aucun exercice en production ne change de note (ADR-0115 §2.2).
2. La note sur 20 reste lue sur un seul score (ADR-0106).
3. L'indice d'une copie notée ne se lit que si son ouverture est enregistrée : un texte déjà dans la page se lirait sans être compté.
4. Pas de type nouveau : une case est un `___` d'un type existant.

## 3. Options envisagées

| Option | Pourquoi elle tenait la route | Pourquoi elle a été écartée |
|---|---|---|
| A — Une case = une question, affichées côte à côte | Aucun changement de modèle | Écartée par le porteur (grill 7) : la phrase « AN = … MN = … » se lit d'un bloc et se corrige d'une explication |
| B — Tout ou rien par question | La note ne change pas de calcul | Écartée (grill 8) : la moitié du travail juste vaudrait 0 |
| C — **Une colonne `blank` sur `answers`, les réponses par case dans `question_attempts`, une fraction de points par question** | Une case à la fois, les questions existantes ont toutes `blank = 0` | **Retenue** |
| D — Points par case saisis à l'import | Barème fin | Plus de saisie et de validation, pour un besoin non exprimé. La répartition égale suffit |
| E — Indice dans la page, ouverture signalée par JavaScript | Pas de requête | Lisible sans être compté, ce qui contredit le moteur 3 |

## 4. Décision

> **Nous numérotons les cases d'une question par l'ordre de ses `___`, de 0 à 5, et rattachons chaque réponse à sa case (`answers.blank`, défaut 0).**

- `numeric` : une réponse correcte par case. L'unité et la tolérance de la question valent pour toutes ses cases. Des unités différentes s'écrivent en deux questions.
- `fill_blank` : 1 à 5 réponses acceptées par case.
- `select` : 2 à 10 propositions par case, dont une seule correcte.
- Une question à une case n'a pas besoin de `___` pour `numeric`, comme aujourd'hui. Avec plusieurs cases, le nombre de `___` est égal au nombre de cases, et chaque case a ses réponses. Au plus 6 cases par question.
- Les autres types n'acceptent qu'une case, et l'import refuse `blank` > 0 pour eux.

> **Nous enregistrons la réponse de chaque case et son verdict : `question_attempts.blank_responses` (text[]) et `blank_results` (boolean[]).** `correct` reste « toutes les cases justes ». `response_text` et `selected_answer_ids` gardent la réponse d'une question à une case, et rien ne change pour elle.

> **Nous calculons le score sur des fractions de points : une question rapporte `points × cases justes / cases`.** Une question à une case rapporte `points` ou 0, exactement comme aujourd'hui. Le calcul se fait en `Rational` et le pourcentage est arrondi vers le bas une seule fois, à la fin : aucun arrondi intermédiaire, donc pas de « 1 point sur 3 cases » qui tombe mal. Lacunes, maîtrise, badge et meilleure note se lisent sur ce score.

> **Nous ajoutons un indice facultatif par question (`questions.hint`, 500 caractères), et l'ouverture d'un indice dans une copie notée est un fait de la copie (`exercise_sessions.hinted_question_ids`, bigint[]).**

- `POST /exercise_sessions/:public_id/hints` (`question_id`) → `UseCases::Assessment::OpenHint`. L'élève doit être l'auteur d'une copie en cours (`SubmitAttemptPolicy`), et la question doit être de l'exercice et avoir un indice. Sinon : 404, rien d'enregistré.
- L'ajout est idempotent : `array_append` seulement si l'identifiant est absent, sous le verrou de la session. Dix ouvertures donnent une seule mention.
- Le texte de l'indice n'est **jamais** dans la page de la copie avant ce POST : la réponse est un Turbo Stream qui le place.
- La note ne change pas. La page de résultat de l'élève, la copie lue par l'enseignant et le suivi montrent « Indice ouvert » sur la question.
- Dans la fiche (ADR-XXXX-entrainement-de-notion-corrige-sans-trace), l'indice est dans la page et rien n'est enregistré.

## 5. Conséquences

### 🟢 Positives

- Les exercices des maquettes s'écrivent tels quels, dans la fiche comme dans les devoirs.
- Aucun exercice existant ne change de note ni de forme d'import : `blank` vaut 0 par défaut et `hint` est facultatif.
- L'enseignant sait quelles questions ont demandé un indice.

### 🔴 Coûts consentis

- Une migration sur quatre tables : `answers.blank`, `question_attempts.blank_responses` et `blank_results`, `questions.hint`, `exercise_sessions.hinted_question_ids`.
- Trois classes de règles (`Numeric`, `Select`, `FillBlank`) jugent case par case. Leur partial de saisie, le partial du résultat et le corrigé de l'équipe doivent montrer chaque case.
- Une route de plus dans la copie notée, et une requête par indice ouvert.
- `correct` d'une tentative ne suffit plus à compter les points : tout calcul de note passe par `Grading.points_percent`, jamais par `count(&:correct)` (déjà exigé par l'ADR-0115 §5).
- Un indice ouvert ne coûte rien : un élève peut l'ouvrir partout. Le porteur l'accepte, puisque l'enseignant le voit.

## 6. Notes d'implémentation

```ruby
# app/domain/entities/assessment/grading.rb — remplace points_percent(graded) de l'ADR-0115
# graded : [[points (BigDecimal), part juste (Rational, de 0 à 1)]] des seules questions corrigées automatiquement.
def self.points_percent(graded)
  total = graded.sum(Rational(0)) { |points, _| points.to_r }
  return 0 if total.zero?

  (graded.sum(Rational(0)) { |points, share| points.to_r * share } * 100 / total).floor
end
```

```ruby
# app/domain/use_cases/assessment/close_exercise_session.rb — graded
.map { |question| [ question.points, Entities::Assessment::Grading.share(question, attempts[question.id]) ] }

# app/domain/entities/assessment/grading.rb
# Une case : 1 si juste, 0 sinon. Plusieurs : cases justes / cases. Sans tentative : 0.
def self.share(question, attempt)
  return Rational(0) if attempt.nil?
  return Rational(attempt.correct == true ? 1 : 0) if question.blanks == 1

  Rational(attempt.blank_results.count(true), question.blanks)
end
```

```ruby
# db/migrate/…_add_blanks_and_hints.rb
add_column :answers, :blank, :integer, limit: 2, null: false, default: 0
add_check_constraint :answers, "blank BETWEEN 0 AND 5", name: "answers_blank_range"
add_column :question_attempts, :blank_responses, :string, array: true, null: false, default: []
add_column :question_attempts, :blank_results, :boolean, array: true, null: false, default: []
add_column :questions, :hint, :string, limit: 500
add_column :exercise_sessions, :hinted_question_ids, :bigint, array: true, null: false, default: []
```

## 7. Comment vérifier que la décision est respectée

- `test/domain/entities/assessment/grading_test.rb` : 2 cases sur 2 points, une juste → 50 %. 1 point sur 3 cases, deux justes → 66 %. Une question à une case → les mêmes valeurs qu'avant.
- `test/infrastructure/grading_regression_test.rb` (CA-12) : les notes des copies des fixtures, recalculées après la migration, sont identiques.
- `test/domain/entities/assessment/question_kinds/*_test.rb` : verdict case par case, `structure_errors` (cases sans réponse, nombre de `___` différent du nombre de cases, `blank` > 0 sur un type à une case).
- `test/controllers/assessment/hints_controller_test.rb` : 404 sur une copie rendue ou celle d'un autre élève ; deux ouvertures → `hinted_question_ids` à un seul élément ; le HTML de la copie ne contient pas le texte de l'indice avant le POST.
