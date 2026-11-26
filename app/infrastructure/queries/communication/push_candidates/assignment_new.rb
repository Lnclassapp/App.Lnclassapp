# 🔌 INFRA · Queries::Communication::PushCandidates::AssignmentNew
# Rôle : candidats du motif assignment_new : exercices donnés depuis moins de 24 h à la classe principale de l'élève (de son niveau), pas encore tous rendus
# ADR  : XXXX envois de notifications (§6) · 0146 (§3.2) · 0121 (§4)
module Queries
  module Communication
    class PushCandidates
      # Mêmes lectures qu'AssignmentDue (élèves abonnés, classe principale, niveau, copies rendues) ; seul le filtre des envois change :
      # `assigned_at` dans les 24 h au lieu de l'échéance. Un envoi de plusieurs exercices ne fait qu'une notification.
      class AssignmentNew < AssignmentDue
        WINDOW = 24.hours
        NewRow = Data.define(:id, :public_id, :batch, :assigned_at, :material_name, :level_id, :series_id)

        # → [Entities::Communication::PushCandidate]
        def for(now:, user_ids: nil)
          student_ids = subscribed_user_ids(user_ids)
          memberships = student_ids.empty? ? [] : memberships(student_ids)
          return [] if memberships.empty?

          sheets = recent_sheets(memberships.map(&:last).uniq, now)
          return [] if sheets.empty?

          handed_in = handed_in(student_ids, sheets.values.flatten.map(&:id))
          audiences = audiences(memberships, now.utc.to_date)
          memberships.flat_map { |student_id, classroom_id| new_candidates(student_id, sheets.fetch(classroom_id, []), handed_in, audiences[student_id]) }
        end

        private

        # UDR-0013 : rien d'un autre niveau que celui de l'élève ; une feuille entièrement rendue n'est pas annoncée.
        def new_candidates(student_id, sheets, handed_in, audience)
          sheets.filter_map do |sheet|
            sheet = sheet.select { |row| audience.any? { |level_id, series_id| row.level_id == level_id && [ nil, series_id ].include?(row.series_id) } }
            next if sheet.empty? || sheet.all? { handed_in.include?([ student_id, it.id ]) }

            key = sheet.first.batch || sheet.first.public_id
            Entities::Communication::PushCandidate.new(
              user_id: student_id, motive: "assignment_new", object_key: "assignment_new:#{key}",
              url: Rails.application.routes.url_helpers.student_classroom_path(anchor: "devoir-#{key.downcase}"),
              variables: { material: sheet.first.material_name, count: sheet.size }, valid_until: sheet.map(&:assigned_at).min + WINDOW
            )
          end
        end

        # { classroom_id => [[NewRow] par envoi] } : les assignations actives d'exercices publiés, données dans les dernières 24 h.
        def recent_sheets(classroom_ids, now)
          rows = Orm::ClassroomAssignment
                 .joins("INNER JOIN exercises ON exercises.id = classroom_assignments.assignable_id " \
                        "INNER JOIN courses ON courses.id = exercises.course_id " \
                        "INNER JOIN materials ON materials.id = courses.material_id " \
                        "LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id")
                 .where(classroom_id: classroom_ids, status: "active", assignable_type: "Exercise", assigned_at: (now - WINDOW)..now)
                 .where(exercises: { status: "published", archived_at: nil }, courses: { status: "published" })
                 .where("essentials.id IS NULL OR essentials.status = 'published'")
                 .order("classroom_assignments.id")
                 .pluck("classroom_assignments.classroom_id", "classroom_assignments.id", "classroom_assignments.public_id",
                        "classroom_assignments.batch_public_id", "classroom_assignments.assigned_at", "materials.name", "courses.level_id", "courses.series_id")
          rows.group_by(&:first).transform_values do |classroom_rows|
            classroom_rows.map { |_, *values| NewRow.new(*values) }.group_by { it.batch || it.public_id }.values
          end
        end
      end
    end
  end
end
