# 🧠 DOMAINE · UseCases::Classroom::AssignExerciseBatch
# Rôle : l'enseignant de la classe envoie de 1 à 10 exercices en un devoir : une assignation ordinaire par exercice, toutes du même
#        envoi, échéance au prochain jour de séance de l'auteur ; un exercice déjà assigné à la classe est écarté et nommé
# ADR  : 0035, 0048, 0072, sujets-de-devoir (ajout du 2026-10-30)
module UseCases
  module Classroom
    class AssignExerciseBatch
      # created : Array<Assignment> dans l'ordre choisi ; skipped : Array<Assignable> déjà assignées (actives) à la classe.
      Sent = Data.define(:classroom, :created, :skipped)

      MAX_EXERCISES = 10
      # Les identifiants viennent du navigateur : une liste plus longue que cela n'est pas une sélection, elle n'est pas lue.
      MAX_SUBMITTED = 50
      PUBLIC_ID_LENGTH = 14

      def initialize(classrooms:, assignments:, session_days:, policy:, session_days_policy:, clock:)
        @classrooms = classrooms
        @assignments = assignments
        @session_days = session_days
        @policy = policy
        @session_days_policy = session_days_policy
        @clock = clock
      end

      # exercise_public_ids : ce que le navigateur a envoyé, jamais cru (inconnus, doublons, liste trop longue, valeurs qui ne sont pas du texte).
      # → Result(Sent) | :not_found (classe) | :forbidden (droits, classe archivée) | :invalid (de 1 à 10 exercices :
      #   base: [:invalid_count] ; un exercice inconnu ou non publié : base: [:unknown_exercise] ; aucun jour de séance : weekdays: [:blank]) |
      #   :conflict (base: [:other_level]). Un refus n'écrit rien : le choix et les droits se vérifient avant l'écriture de l'envoi.
      def call(actor:, classroom_public_id:, exercise_public_ids:)
        classroom = @classrooms.find_by_public_id(public_id: classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?

        keys = keys_of(exercise_public_ids)
        return Shared::Result.failure(:invalid, errors: { base: [ :invalid_count ] }) unless keys&.size&.between?(1, MAX_EXERCISES)

        due_on = due_on_for(actor, classroom)
        return due_on if due_on.is_a?(Shared::Result)

        assignables = readable_assignables(classroom, keys)
        return assignables if assignables.is_a?(Shared::Result)

        send_batch(actor, classroom, assignables, due_on)
      end

      private

      # → Array<String> sans doublon, dans l'ordre reçu | nil (ce n'est pas une liste, ou elle est trop longue).
      def keys_of(submitted)
        return unless submitted.is_a?(Array) && submitted.size <= MAX_SUBMITTED

        submitted.grep(String).map(&:strip).reject(&:empty?).uniq
      end

      # UDR enseignant §3.13 : un enseignant sans jours pour la classe ne reçoit pas d'échéance muette ; il les donne en assignant un
      # exercice (la modale). L'équipe, que la policy des jours refuse, envoie sans échéance (ADR-0072 §4.3).
      def due_on_for(actor, classroom)
        days = @session_days.for(teacher_id: actor.user_id, classroom_id: classroom.id)
        teacher = @session_days_policy.call(actor:, classroom:).success?
        return Shared::Result.failure(:invalid, errors: { weekdays: [ :blank ] }) if teacher && days.none?

        days.next_after(@clock.now.to_date)
      end

      # Chaque exercice : publié, parents publiés (ADR-0035), du niveau de la classe (UDR-0013, amendement du 2026-10-01).
      def readable_assignables(classroom, keys)
        resolved = keys.map { @assignments.resolve_assignable(type: "Exercise", key: it) }
        return Shared::Result.failure(:invalid, errors: { base: [ :unknown_exercise ] }) if resolved.any? { it.nil? || !it.readable? }
        return Shared::Result.failure(:conflict, errors: { base: [ :other_level ] }) unless resolved.all? { same_level?(classroom, it) }

        resolved.map(&:assignable)
      end

      def same_level?(classroom, resolved)
        Entities::Catalog::LevelAudience.new(pairs: [ [ classroom.level_id, classroom.series_id ] ]).covers?(**resolved.course_level)
      end

      def send_batch(actor, classroom, assignables, due_on)
        now = @clock.now
        batch_public_id = SecureRandom.base58(PUBLIC_ID_LENGTH)
        assignments = assignables.map do |assignable|
          Entities::Classroom::Assignment.new(id: nil, public_id: nil, classroom_id: classroom.id, assignable:, status: "active",
                                              assigned_by_id: actor.user_id, assigned_at: now, archived_at: nil, due_on:, batch_public_id:)
        end
        created = @assignments.create_batch(assignments:)
        return created if created.failure?

        Shared::Result.success(Sent.new(classroom:, created: created.value.created, skipped: created.value.skipped))
      end
    end
  end
end
