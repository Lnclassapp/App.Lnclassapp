# 🔌 INFRA · Queries::Assessment::ClassroomGapsQuery
# Rôle : fiches à revoir d'une classe (combien d'élèves) et, sur une fiche, qui est à revoir et qui l'a levée cette année
# ADR  : 0041, 0043, 0072 (§4.5), 0079, 0101 (§4.4) · UDR : 0121
module Queries
  module Assessment
    class ClassroomGapsQuery
      EssentialGaps = Data.define(:essential_slug, :essential_name, :course_slug, :pending_count)
      # pending : de la lacune la plus ancienne à la plus récente ; lifted : de la plus récente à la plus ancienne.
      Detail = Data.define(:pending, :lifted)
      PendingRow = Data.define(:display_name, :opened_on, :failed_sessions_count)
      LiftedRow = Data.define(:display_name, :resolved_on)

      SUMMARY_COLUMNS = [ "essentials.slug", "essentials.name", "courses.slug", Arel.sql("COUNT(*)") ].freeze
      DETAIL_COLUMNS = %w[knowledge_gaps.id knowledge_gaps.status users.first_name users.last_name knowledge_gaps.created_at
                          knowledge_gaps.resolved_at knowledge_gaps.failed_sessions_count].freeze

      # Fiches publiées, d'un cours publié parmi course_slugs (ceux que la page de classe affiche), où au moins un élève
      # présent a une lacune en attente ; par nombre d'élèves décroissant, puis par nom. Une requête.
      # show_roster : Access de ReadClassroomPolicy ; faux, rien n'est lu. → [EssentialGaps] | nil
      def summary(classroom_public_id:, course_slugs:, show_roster:)
        return unless show_roster

        gaps(classroom_public_id).where(status: "pending", courses: { slug: course_slugs })
                                 .group("essentials.id", "essentials.slug", "essentials.name", "courses.slug")
                                 .order(Arel.sql("COUNT(*) DESC"), "essentials.name", "essentials.id")
                                 .pluck(*SUMMARY_COLUMNS)
                                 .map { |slug, name, course_slug, count| EssentialGaps.new(slug, name, course_slug, count) }
      end

      # Les lacunes en attente de la fiche, quelle que soit leur date, et celles levées (remediated ou self_corrected,
      # sans distinction) pendant l'année scolaire de la classe (ADR-0041). Une requête. → Detail | nil
      def detail(classroom_public_id:, course_slug:, essential_slug:, school_year:, show_roster:)
        return unless show_roster

        scope = gaps(classroom_public_id).where(essentials: { slug: essential_slug }, courses: { slug: course_slug })
        rows = scope.where(status: "pending").or(scope.where(resolved_at: year_range(school_year))).pluck(*DETAIL_COLUMNS)
        pending, lifted = rows.partition { it[1] == "pending" }
        Detail.new(pending: pending.sort_by { [ it[4], it[0] ] }.map { pending_row(it) },
                   lifted: lifted.sort_by { [ it[5], it[0] ] }.reverse.map { lifted_row(it) })
      end

      private

      # Les élèves présents de la classe (ADR-0079) : adhésion non quittée, compte non anonymisé.
      def gaps(classroom_public_id)
        present = Queries::Classroom::AssignmentFollowUpQuery
                  .present_students(Orm::Classroom.where(public_id: classroom_public_id).select(:id)).select(:student_id)
        Orm::KnowledgeGap.joins(:student, essential: :course)
                         .where(student_id: present, essentials: { status: "published" }, courses: { status: "published" })
      end

      # « 2026-2027 » → du 1er septembre 2026 au 1er septembre 2027 (exclu), à l'heure d'Abidjan.
      def year_range(school_year)
        first = school_year.to_s[0, 4].to_i
        month = Entities::Classroom::SchoolYear::START_MONTH
        Time.zone.local(first, month, 1)...Time.zone.local(first + 1, month, 1)
      end

      def pending_row((_, _, first_name, last_name, created_at, _, failed_sessions_count))
        PendingRow.new(display_name: "#{first_name} #{last_name}", opened_on: created_at.in_time_zone.to_date,
                       failed_sessions_count:)
      end

      def lifted_row((_, _, first_name, last_name, _, resolved_at, _))
        LiftedRow.new(display_name: "#{first_name} #{last_name}", resolved_on: resolved_at.in_time_zone.to_date)
      end
    end
  end
end
