# 🔌 INFRA · Queries::Communication::PushCandidates::AssignmentDue
# Rôle : candidats du motif assignment_due : feuille de 3 exercices ou plus de la classe principale de l'élève, à rendre demain (date d'Abidjan), pas encore rendue
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · 0121 (§4) · PRD §3.1
module Queries
  module Communication
    class PushCandidates
      class AssignmentDue
        Row = Data.define(:id, :public_id, :batch, :due_on, :material_name)

        # Un nombre fixe de lectures : élèves abonnés, appartenances, assignations des envois dus demain, copies rendues.
        # → [Entities::Communication::PushCandidate]. Abidjan est à UTC+0 : la date UTC est la date d'Abidjan.
        def for(now:)
          today = now.utc.to_date
          student_ids = subscribed_user_ids
          memberships = student_ids.empty? ? [] : memberships(student_ids)
          return [] if memberships.empty?

          sheets = sheets_by_classroom(memberships.map(&:last).uniq, today + 1)
          handed_in = handed_in(student_ids, sheets.values.flatten.map(&:id))
          memberships.flat_map { |student_id, classroom_id| candidates(student_id, sheets.fetch(classroom_id, []), handed_in, today) }
        end

        private

        # Le motif porté par cette requête : l'interro (1 ou 2 exercices) ou le devoir (3 ou plus).
        def kind = :devoirs
        def motive = "assignment_due"
        def variables(material, _count) = { material: }

        def candidates(student_id, sheets, handed_in, today)
          sheets.filter_map do |sheet|
            next unless Entities::Classroom::SheetKind.for(sheet.size) == kind
            next if sheet.all? { handed_in.include?([ student_id, it.id ]) }

            key = sheet.first.batch || sheet.first.public_id
            Entities::Communication::PushCandidate.new(
              user_id: student_id, motive:, object_key: "#{motive}:#{key}",
              url: Rails.application.routes.url_helpers.student_classroom_path(anchor: "devoir-#{key.downcase}"),
              variables: variables(sheet.first.material_name, sheet.size), valid_until: today.in_time_zone("UTC").change(hour: 20)
            )
          end
        end

        # Abonnés, non coupés, non anonymisés.
        def subscribed_user_ids
          Orm::Communication::PushSubscription.joins(:user).where(users: { anonymized_at: nil })
                                              .where.not(user_id: Orm::Communication::PushPreference.where.not(turned_off_at: nil).select(:user_id))
                                              .distinct.pluck(:user_id)
        end

        # [[student_id, classroom_id]] : la classe principale active, jamais une classe quittée ou archivée.
        def memberships(student_ids)
          Orm::ClassroomStudent.joins(:classroom).where(student_id: student_ids, primary: true, left_at: nil, classrooms: { status: "active" })
                               .pluck(:student_id, :classroom_id)
        end

        # { classroom_id => [[Row] par envoi dont l'échéance la plus proche est demain] }, les assignations actives d'exercices publiés.
        def sheets_by_classroom(classroom_ids, tomorrow)
          batch_key = "COALESCE(classroom_assignments.batch_public_id, classroom_assignments.public_id)"
          rows = Orm::ClassroomAssignment
                 .joins("INNER JOIN exercises ON exercises.id = classroom_assignments.assignable_id " \
                        "INNER JOIN courses ON courses.id = exercises.course_id " \
                        "INNER JOIN materials ON materials.id = courses.material_id " \
                        "LEFT OUTER JOIN essentials ON essentials.id = exercises.essential_id")
                 .where(classroom_id: classroom_ids, status: "active", assignable_type: "Exercise")
                 .where(exercises: { status: "published", archived_at: nil }, courses: { status: "published" })
                 .where("essentials.id IS NULL OR essentials.status = 'published'")
                 .where("#{batch_key} IN (SELECT COALESCE(due.batch_public_id, due.public_id) FROM classroom_assignments due " \
                        "WHERE due.status = 'active' AND due.due_on = ?)", tomorrow)
                 .order("classroom_assignments.id")
                 .pluck("classroom_assignments.classroom_id", "classroom_assignments.id", "classroom_assignments.public_id",
                        "classroom_assignments.batch_public_id", "classroom_assignments.due_on", "materials.name")
          rows.group_by(&:first).transform_values do |classroom_rows|
            classroom_rows.map { |_, *values| Row.new(*values) }.group_by { it.batch || it.public_id }.values
                          .select { |sheet| sheet.filter_map(&:due_on).min == tomorrow }
          end
        end

        # Set de [student_id, assignment_id] : une copie terminée rattachée à l'assignation.
        def handed_in(student_ids, assignment_ids)
          return Set.new if assignment_ids.empty?

          Orm::ExerciseSession.where(student_id: student_ids, status: "completed", classroom_assignment_id: assignment_ids)
                              .distinct.pluck(:student_id, :classroom_assignment_id).to_set
        end
      end
    end
  end
end
