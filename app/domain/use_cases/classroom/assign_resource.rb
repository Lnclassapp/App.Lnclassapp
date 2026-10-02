# 🧠 DOMAINE · UseCases::Classroom::AssignResource
# Rôle : l'enseignant de la classe, ou l'équipe, assigne un contenu publié du niveau de la classe ; une ligne par assignation
# ADR  : 0026, 0028, 0035, 0048
module UseCases
  module Classroom
    class AssignResource
      # La classe accompagne l'assignation : l'écran nomme la ressource et la classe.
      Assigned = Data.define(:assignment, :classroom)

      def initialize(classrooms:, assignments:, policy:, clock:)
        @classrooms = classrooms
        @assignments = assignments
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Classroom::AssignmentInput.
      # → Result(Assigned) | :not_found (classe, ou ressource absente ou non lisible) | :forbidden | :invalid
      #   | :conflict (base: already_assigned | other_level)
      def call(actor:, dto:)
        classroom = @classrooms.find_by_public_id(public_id: dto.classroom_public_id)
        return Shared::Result.failure(:not_found) if classroom.nil?

        allowed = @policy.call(actor:, classroom:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        # Un contenu non publié, ou dont un parent ne l'est plus, ne s'assigne pas (ADR-0035).
        resolved = @assignments.resolve_assignable(type: dto.assignable_type, key: dto.assignable_key)
        return Shared::Result.failure(:not_found) if resolved.nil? || !resolved.readable?
        # UDR-0013, amendement du 2026-10-01 : la règle de lecture de l'élève ; un contenu d'un autre niveau ne s'assigne pas.
        return Shared::Result.failure(:conflict, errors: { base: [ :other_level ] }) unless same_level?(classroom, resolved)

        create(actor, classroom, resolved.assignable)
      end

      private

      def same_level?(classroom, resolved)
        Entities::Catalog::LevelAudience.new(pairs: [ [ classroom.level_id, classroom.series_id ] ]).covers?(**resolved.course_level)
      end

      # L'index partiel actif tranche une concurrence perdue : le repository la traduit aussi en :conflict.
      def create(actor, classroom, assignable)
        if @assignments.active_for(classroom_id: classroom.id, assignable:)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_assigned ] })
        end

        created = @assignments.create(assignment: Entities::Classroom::Assignment.new(
          id: nil, public_id: nil, classroom_id: classroom.id, assignable:, status: "active",
          assigned_by_id: actor.user_id, assigned_at: @clock.now, archived_at: nil
        ))
        return created if created.failure?

        Shared::Result.success(Assigned.new(assignment: created.value, classroom:))
      end
    end
  end
end
