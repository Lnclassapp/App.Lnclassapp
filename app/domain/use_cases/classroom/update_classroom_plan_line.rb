# 🧠 DOMAINE · UseCases::Classroom::UpdateClassroomPlanLine
# Rôle : l'équipe change les nombres public et privé d'une ligne du barème ; seuls les nombres changés sont écrits et tracés
# ADR  : 0026, 0028, 0058
module UseCases
  module Classroom
    class UpdateClassroomPlanLine
      def initialize(classroom_plan:, taxonomy:, audit_log:, transaction:, policy:, clock:)
        @classroom_plan = classroom_plan
        @taxonomy = taxonomy
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # Une ligne : un niveau du premier cycle (sans série), ou un couple niveau × série liée du second cycle.
      # dto : Dtos::Classroom::ClassroomPlanLineInput. → Result(DefaultClassroomPlan::Line) | :forbidden | :not_found | :invalid
      def call(actor:, level_slug:, series_slug:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        level, series = line_of(@taxonomy.lookup, level_slug, series_slug)
        return Shared::Result.failure(:not_found) if level.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        current = @classroom_plan.plan
        changes = dto.counts.filter_map do |school_type, count|
          from = current.count(school_type:, level_id: level.id, series_id: series&.id)
          [ Entities::Classroom::ClassroomPlan::Entry.new(school_type:, level_id: level.id, series_id: series&.id, count:), from ] if from != count
        end
        write(actor, level, series, changes) if changes.any?
        Shared::Result.success(Entities::Classroom::DefaultClassroomPlan::Line.new(level:, series:, counts: dto.counts))
      end

      private

      # → [niveau, série | nil], ou [nil] pour une ligne que le référentiel ne connaît pas.
      def line_of(lookup, level_slug, series_slug)
        level = lookup.level(level_slug)
        return [ nil ] if level.nil? || level.first_cycle? != series_slug.nil?
        return [ level, nil ] if series_slug.nil?

        series = lookup.find_series(series_slug)
        series && lookup.pair?(level.id, series.id) ? [ level, series ] : [ nil ]
      end

      def write(actor, level, series, changes)
        now = @clock.now
        @transaction.call do
          @classroom_plan.save(entries: changes.map(&:first), at: now)
          changes.each do |entry, from|
            @audit_log.record(action: "classroom_plan.changed", actor_id: actor.user_id, at: now, subject_type: "Level",
                              subject_id: level.id, metadata: { school_type: entry.school_type, level: level.slug,
                                                                series: series&.slug, from:, to: entry.count, source: "manual" })
          end
        end
      end
    end
  end
end
