# 🧠 DOMAINE · UseCases::Classroom::AssignResource
# Rôle : l'enseignant de la classe, ou l'équipe, assigne un exercice publié du niveau de la classe ; l'échéance est le prochain
#        jour de séance de l'auteur, calculée et figée ici ; les jours cochés à cette étape s'enregistrent dans la même transaction
# ADR  : 0026, 0028, 0035, 0048, 0072
module UseCases
  module Classroom
    class AssignResource
      # La classe accompagne l'assignation : l'écran nomme la ressource et la classe.
      Assigned = Data.define(:assignment, :classroom)

      # Annule les jours écrits quand l'assignation est refusée à l'écriture (concurrence perdue).
      class Refused < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("assignation refusée")
        end
      end

      def initialize(classrooms:, assignments:, session_days:, transaction:, policy:, session_days_policy:, clock:)
        @classrooms = classrooms
        @assignments = assignments
        @session_days = session_days
        @transaction = transaction
        @policy = policy
        @session_days_policy = session_days_policy
        @clock = clock
      end

      # dto : Dtos::Classroom::AssignmentInput ; dto.weekdays (non nil) = étape « Quels jours ? » remplie (ADR-0072 §4.3).
      # → Result(Assigned) | :not_found (classe, ou ressource absente ou non lisible) | :forbidden (y compris des jours
      #   envoyés par qui n'en a pas : l'équipe) | :invalid (type, ou aucun jour coché) | :conflict (already_assigned | other_level)
      def call(actor:, dto:)
        classroom = @classrooms.find_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # Les jours écrits sont toujours ceux de l'acteur : l'équipe n'en a pas et n'écrit pas ceux d'un enseignant.
        if dto.weekdays
          days_allowed = @session_days_policy.call(actor:, classroom:)
          return days_allowed if days_allowed.failure?
        end

        # Un contenu non publié, ou dont un parent ne l'est plus, ne s'assigne pas (ADR-0035).
        resolved = @assignments.resolve_assignable(type: dto.assignable_type, key: dto.assignable_key)
        return Shared::Result.failure(:not_found) if resolved.nil? || !resolved.readable?
        # UDR-0013, amendement du 2026-10-01 : la règle de lecture de l'élève ; un contenu d'un autre niveau ne s'assigne pas.
        return Shared::Result.failure(:conflict, errors: { base: [ :other_level ] }) unless same_level?(classroom, resolved)

        create(actor, classroom, resolved.assignable, dto.weekdays)
      end

      private

      def same_level?(classroom, resolved)
        Entities::Catalog::LevelAudience.new(pairs: [ [ classroom.level_id, classroom.series_id ] ]).covers?(**resolved.course_level)
      end

      # L'index partiel actif tranche une concurrence perdue : le repository la traduit aussi en :conflict.
      def create(actor, classroom, assignable, weekdays)
        if @assignments.active_for(classroom_id: classroom.id, assignable:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_assigned ] })
        end

        now = @clock.now
        created = @transaction.call do
          @session_days.replace(teacher_id: actor.user_id, classroom_id: classroom.id, weekdays:, at: now) if weekdays
          write(actor, classroom, assignable, now).tap { raise Refused, it if it.failure? }
        end
        Shared::Result.success(Assigned.new(assignment: created.value, classroom:))
      rescue Refused => e
        e.result
      end

      # Figée ici, jamais recalculée : la date locale d'Abidjan (clock = Time.zone), nil sans jours (ADR-0072 §4.3).
      def write(actor, classroom, assignable, now)
        due_on = @session_days.for(teacher_id: actor.user_id, classroom_id: classroom.id).next_after(now.to_date)
        @assignments.create(assignment: Entities::Classroom::Assignment.new(
          id: nil, public_id: nil, classroom_id: classroom.id, assignable:, status: "active",
          assigned_by_id: actor.user_id, assigned_at: now, archived_at: nil, due_on:
        ))
      end
    end
  end
end
