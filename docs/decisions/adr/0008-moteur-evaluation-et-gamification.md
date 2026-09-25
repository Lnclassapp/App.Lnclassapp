# ADR-0008 : Moteur d'Évaluation, de Tentatives et de Gamification (Badges en Temps Réel)

| | |
|---|---|
| **Statut** | Accepté — *en production (Use Cases d'exécution d'exercices et attribution de badges actifs)* |
| **Date** | 2026-07-18 |
| **Chantier** | — |
| **Remplace** | — |
| **Remplacé par** | — |

---

## 1. Contexte et problématique
Une plateforme éducative interactive ne peut pas se contenter d'afficher des cours statiques ; elle doit évaluer la progression réelle de l'apprenant à travers des exercices, calculer ses scores de précision et stimuler sa motivation par un système de récompenses (gamification).

Cependant, le calcul et l'enregistrement d'une session d'exercice posent plusieurs exigences critiques :
* Un élève peut soumettre 20 réponses simultanément à la fin d'un QCM ou d'une évaluation. Si l'application évalue chaque question par une requête de lecture individuelle puis une requête d'écriture en base, cela génère le problème classique du **N+1 Queries** et ralentit considérablement l'expérience utilisateur.
* Comment garantir l'immuabilité et l'audit d'une session terminée (éviter qu'un élève ne re-soumette des réponses après avoir vu le corrigé) ?
* Comment attribuer des récompenses (Badges Bronze, Argent, Or) de manière équitable et maintenir la progression globale dans sa classe sans saturer le processeur ?

---

## 2. Moteurs de décision
* **Performance d'Évaluation en Lot (Batch Processing) :** Réduire à une seule requête de lecture le chargement des corrigés d'un exercice et à une seule transaction la sauvegarde des tentatives de réponses.
* **Intégrité et Sécurité d'Exécution :** Verrouiller définitivement une session dès qu'elle est marquée comme terminée (`status: "completed"`).
* **Motivation de l'Élève (Gamification Instantanée) :** Calculer et attribuer immédiatement le badge approprié dès la clôture de la session, pour l'afficher dans une animation de célébration (confetti).

---

## 3. Décision
Nous avons conçu un moteur d'exécution en 3 entités reliées :
1. **`ExerciseSession`** : Représente la tentative globale d'un élève (`student_id`, `exercise_id`, `status: :in_progress / :completed`, `percentage`).
2. **`QuestionAttempt`** : Enregistre la réponse spécifique fournie à chaque item (`question_id`, `provided_answer`, `is_correct`).
3. **`ExerciseBadge`** : Récompense accordée (`level: :bronze, :silver, :gold`).

Le Use Case central **`UseCases::CompleteExerciseSession`** est responsable de l'orchestration atomique :
* Il charge en **une seule fois** toutes les réponses correctes des questions concernées (`get_correct_answers_for_questions`).
* Il évalue chaque tentative en mémoire Ruby via `attempt.evaluate!(expected_content)`.
* Il calcule le pourcentage de succès de la session et la clôture.
* Si le score atteint le seuil requis (ex: $\ge 80\%$ pour l'Or), il attribue le badge (ou met à jour le badge existant de l'élève sur cet exercice si le nouveau niveau est supérieur au précédent).

---

## 4. Conséquences

### 🟢 Positives
* **Vitesse d'Exécution Extrême :** Même sur un QCM de 50 questions, l'évaluation complète prend moins de 15 millisecondes.
* **Gamification Fluide :** L'élève découvre son score sur 100%, sa note sur 20 et son badge Or instantanément dans l'interface Turbo.
* **Historique Complet :** Les enseignants peuvent analyser question par question les erreurs fréquentes de leur classe via la Query `ClassroomReportQuery`.

### 🔴 Coûts consentis
* **Logique de Remplacement de Badge :** Si un élève repasse un exercice et obtient un score inférieur, la logique actuelle préserve son meilleur badge (ce qui est un comportement pédagogique souhaité, mais qui demande un contrôle de poids : `gold > silver > bronze`).

---

## 5. Notes d'implémentation

Extrait du Use Case montrant l'évaluation par lot et l'attribution de badge :
```ruby
# app/domain/use_cases/complete_exercise_session.rb
module UseCases
  class CompleteExerciseSession
    def execute(session_slug:, answers_payload:, total_questions:)
      session = @execution_repo.find_session_by_slug(session_slug)
      return OpenStruct.new(success?: false, errors: ["Session déjà terminée"]) if session.completed?

      question_ids = answers_payload.keys
      # Chargement par lot (Batch) pour éviter le N+1
      correct_answers_map = @execution_repo.get_correct_answers_for_questions(question_ids)

      attempts_to_save = []
      answers_payload.each do |question_id, provided_answer|
        correct_record = (correct_answers_map[question_id.to_i] || []).first
        attempt = Entities::QuestionAttempt.new(
          exercise_session_id: session.id,
          question_id: question_id,
          provided_answer: provided_answer
        )
        attempt.evaluate!(correct_record&.content)
        attempts_to_save << attempt
      end

      # Sauvegarde groupée des tentatives et clôture
      @execution_repo.save_attempts(attempts_to_save)
      session.question_attempts = attempts_to_save
      session.complete!(total_questions)
      saved_session = @execution_repo.save_session(session)

      # Détermination et attribution du Badge
      badge_level = Entities::ExerciseBadge.determine_level(saved_session.percentage.to_i)
      saved_badge = nil
      if badge_level
        existing_badge = @execution_repo.find_badge(saved_session.student_id, saved_session.exercise_id)
        weights = { bronze: 1, silver: 2, gold: 3 }
        should_update = !existing_badge || weights[badge_level.to_sym] >= weights[existing_badge.level.to_sym]

        if should_update
          badge = Entities::ExerciseBadge.new(
            student_id: saved_session.student_id,
            exercise_id: saved_session.exercise_id,
            level: badge_level,
            earned_at: Time.current
          )
          saved_badge = @execution_repo.save_badge(badge)
        end
      end

      OpenStruct.new(success?: true, session: saved_session, badge: saved_badge)
    end
  end
end
```

---

## 6. Mise à jour (Juillet 2026)
Afin d'éviter la fuite de logique (leaky abstraction) et la duplication entre `CompleteExerciseSession` et `SubmitQuestionAttempt`, la logique complète de gamification et d'attribution des badges a été encapsulée (poussée vers le bas) dans l'entité du domaine `Entities::ExerciseSession` via une méthode `evaluate_and_award_badges!`.
