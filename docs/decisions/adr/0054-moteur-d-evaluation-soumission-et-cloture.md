# ADR-0054 : Moteur d'évaluation — un use case de soumission, un de clôture, une tentative immuable par question et par session

| | |
|---|---|
| **Statut** | Accepté |
| **Date** | 2026-09-25 |
| **Chantier** | `docs/chantiers/refonte-application` — décision de fondation **F-34**, bloque la V1 (Lot C) |
| **Remplace** | [ADR-0008](./0008-moteur-evaluation-et-gamification.md) §3 (statuts et correction) et §6 (`evaluate_and_award_badges!`) |
| **Remplacé par** | — |

---

## 1. Contexte et problématique

L'ADR-0008 fait tout passer par `CompleteExerciseSession`, compare les **contenus** des réponses et prévoit les statuts `in_progress`/`completed`. Le code fait autrement (**C-42**) : il passe par `SubmitQuestionAttempt`, compare des **identifiants**, et appelle une méthode `evaluate_and_award_badges!` qui n'existe pas. Les statuts du code et du glossaire sont `started`/`completed`/`abandoned` (**C-43**). La réponse de l'élève est stockée sous la forme `inspect` d'un tableau Ruby ; `answer_data` et `attempted_answer_ids` ne sont jamais écrits (**C-44**). `exercises.essential_id` est nullable, alors que tout exercice appartient à une fiche (**C-45**). Une même question peut être re-soumise, et les bonnes réponses ont fui par un cache de fragments (AS-39).

## 2. Moteurs de décision

1. Une réponse enregistrée ne change plus jamais, et une seule compte par question.
2. La correction ne dépend pas du texte des propositions, qu'on peut corriger après coup.
3. Score, badge et lacune sont décidés en un seul point.

## 3. Options envisagées

| Option | Pour | Contre |
|---|---|---|
| A — Clôture seule, correction en lot (ADR-0008) | Un seul use case | Pas de retour question par question |
| B — **Soumission par question + clôture unique** | Retour immédiat ; invariants en base | Deux use cases à coordonner |

## 4. Décision

> **Nous corrigeons chaque question à sa soumission par comparaison d'identifiants, nous stockons une tentative immuable par question et par session, et nous confions score, badge et lacune au seul use case de clôture.**

**Schéma** (contexte `assessment`) :

| Table | Colonnes et contraintes |
|---|---|
| `exercises` | `essential_id NOT NULL` (FK `restrict`) ; `exercise_type CHECK IN ('fixation','evaluation')` ; cycle de vie de l'ADR-0035 ; `public_id` |
| `questions` | `exercise_id NOT NULL` ; `question_type CHECK IN ('true_false','single_choice','multiple_correct_2','multiple_correct_3')` ; `position` |
| `answers` | `question_id NOT NULL` ; `correct boolean NOT NULL` ; `position` |
| `exercise_sessions` | `public_id` ; `student_id` FK `users` ; `exercise_id` ; `status CHECK IN ('started','completed','abandoned')` ; `question_count`, figé au démarrage ; `answered_count` ; `correct_count` ; `progress_percent` et `score_percent` (ADR-0033) ; `kind` et `knowledge_gap_id` (ADR-0043) ; `classroom_assignment_id` (ADR-0048) ; `started_at` ; `completed_at` |
| `question_attempts` | `exercise_session_id NOT NULL` ; `question_id NOT NULL` ; `selected_answer_ids bigint[] NOT NULL` ; `correct boolean NOT NULL` ; `answered_at NOT NULL` |

**Index** :

- unique `(exercise_session_id, question_id)` sur `question_attempts` : une tentative par question et par session ;
- unique partiel `(student_id, exercise_id) WHERE status = 'started'` sur `exercise_sessions` : une seule session ouverte par exercice.

Les colonnes `provided_answer`, `answer_data` et `attempted_answer_ids` n'existent plus.

**Use cases** :

- **`Assessment::StartExerciseSession`** (policy `StartSessionPolicy`) : reprend la session `started` si elle existe, sinon en crée une. L'option `restart: true` fait passer la session ouverte à `abandoned` et en crée une nouvelle.
- **`Assessment::SubmitQuestionAttempt`** (policy : propriétaire, session `started`) :
  1. verrouille la session (`FOR UPDATE`) ;
  2. vérifie que les identifiants appartiennent à la question et que leur nombre correspond au type (1, 1, 2 ou 3) ; sinon, `:invalid` ;
  3. compare l'**ensemble** des identifiants choisis à l'ensemble des identifiants `correct` ;
  4. insère la tentative (question déjà répondue : `:conflict`) et met à jour `answered_count`, `correct_count` et `progress_percent` ;
  5. si `answered_count == question_count`, appelle `CloseExerciseSession` (injecté), dans la même transaction.
- **`Assessment::CloseExerciseSession`**, seul point qui pose `status = 'completed'`, `score_percent` et `completed_at`, puis décide du badge (ADR-0033) et de la lacune (ADR-0043).

**Immuabilité** : `Repositories::Assessment::QuestionAttemptRepository` n'expose ni mise à jour ni suppression. Une session `completed` ou `abandoned` refuse toute soumission (`:conflict`). Les réponses tentées ne sont jamais supprimées (ADR-0036).

**Bonnes réponses** : aucune vue ne rend `answers.correct` pour une question non tentée par l'élève (`Assessment::RevealAnswersPolicy`). Aucun cache de fragment ne contient de proposition marquée correcte (AS-39).

## 5. Conséquences

### 🟢 Positives

- C-42, C-43, C-44 et C-45 sont fermées, et la re-soumission est refusée par la base.
- Corriger le texte d'une proposition ne change aucun résultat passé.
- Un seul endroit décide du score, du badge et de la lacune.

### 🔴 Coûts consentis

- Une question mal corrigée ne se rejoue pas : on archive l'exercice et on en publie un correct.
- Ajouter un type de question demande d'amender cet ADR (liste fermée).
- `question_count` est figé : une question ajoutée après le démarrage n'entre pas dans la session en cours.

## 6. Notes d'implémentation

```ruby
# 🧠 DOMAINE · Entities::Assessment::Question
# Rôle : vérifie la forme d'une réponse et la corrige par identifiants
# ADR  : 0054
module Entities
  module Assessment
    Question = Data.define(:id, :question_type, :answer_ids, :correct_answer_ids) do
      EXPECTED = { true_false: 1, single_choice: 1, multiple_correct_2: 2, multiple_correct_3: 3 }.freeze

      def well_formed?(selected_ids) =
        selected_ids.uniq.size == EXPECTED.fetch(question_type) && (selected_ids - answer_ids).empty?

      def correct?(selected_ids) = selected_ids.sort == correct_answer_ids.sort
    end
  end
end
```

## 7. Comment vérifier que la décision est respectée

- Test de repository : deux tentatives pour la même question et la même session lèvent `RecordNotUnique`.
- Test de use case : soumettre à une session `completed` donne `:conflict` ; la dernière réponse clôt la session et pose `score_percent`.
- `grep -rn "status.*completed" app/domain/use_cases/assessment` ne trouve d'écriture que dans `close_exercise_session.rb`.
- Test système : le HTML d'une question non tentée ne contient aucun marqueur de bonne réponse.

## 8. Remplace, complète, amende

- **Remplace** l'ADR-0008 §3 (C-42, C-43) et §6.
- Le barème des badges est remplacé par l'ADR-0033. Le reste de l'ADR-0008 (correction sans N+1, verrouillage des sessions terminées) est conservé.
- **Corrige** le glossaire §4 (C-44, C-45) et l'architecture §2.7 (C-42), corrigés le 2026-09-25.

## 9. Points à confirmer par le porteur

- « Recommencer » abandonne la session ouverte ; aucun job n'abandonne les sessions inactives.
- Réponse stockée en tableau d'identifiants (`bigint[]`) plutôt qu'en `jsonb`.
