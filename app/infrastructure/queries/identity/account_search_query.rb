# 🔌 INFRA · Queries::Identity::AccountSearchQuery
# Rôle : recherche d'un élève ou d'un enseignant (TR-11) par nom ou par 4 chiffres du numéro, 20 par page, numéro masqué
# ADR  : 0040, 0050, 0062 · UDR : 0049 · quatre requêtes au plus, quel que soit le nombre de résultats
module Queries
  module Identity
    class AccountSearchQuery
      PER_PAGE = 20
      MIN_LENGTH = 2
      MIN_DIGITS = 4
      ROLES = %w[student teacher].freeze
      # Un terme fait seulement de chiffres et de séparateurs est un numéro.
      NUMBER = /\A[\d\s.+-]+\z/
      # Élève : classroom_name, classrooms_count nil ; enseignant : classroom_name nil, classes enseignées cette année.
      Row = Data.define(:public_id, :display_name, :role, :school_name, :classroom_name, :classrooms_count, :contact)
      Page = Data.define(:rows, :total_count, :page, :pages, :term, :too_short)

      # Casse et accents ignorés, comme la liste des établissements ; le nom se lit dans les deux ordres.
      NAMES = [ "users.first_name || ' ' || users.last_name", "users.last_name || ' ' || users.first_name" ].map do
        "translate(lower(#{it}), '#{Queries::School::SchoolsQuery::ACCENTED}', '#{Queries::School::SchoolsQuery::PLAIN}') LIKE :pattern"
      end.join(" OR ").freeze

      def call(term:, page: 1, today: Date.current)
        term = term.to_s.strip
        condition = condition_for(term)
        return Page.new(rows: [], total_count: 0, page: 1, pages: 1, term:, too_short: term.present?) if condition.nil?

        scope = Orm::User.where(role: ROLES, anonymized_at: nil).where(*condition)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_i.clamp(1, pages)
        users = scope.order(:last_name, :first_name, :id).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
                     .pluck(:id, :public_id, :first_name, :last_name, :role, :contact)
        Page.new(rows: rows(users, Entities::Classroom::SchoolYear.current(today)), total_count:, page:, pages:, term:,
                 too_short: false)
      end

      private

      # → [sql, binds] | nil quand le terme est trop court pour être cherché
      def condition_for(term)
        if term.match?(NUMBER)
          digits = term.gsub(/\D/, "")
          [ "users.contact LIKE ?", "%#{digits}%" ] if digits.length >= MIN_DIGITS
        else
          text = ActiveSupport::Inflector.transliterate(term.squish).downcase
          [ NAMES, { pattern: "%#{Orm::User.sanitize_sql_like(text)}%" } ] if text.length >= MIN_LENGTH
        end
      end

      def rows(users, year)
        ids = users.map(&:first)
        placements = student_placements(ids, year)
        teachers = teacher_schools(ids, year)
        users.map do |id, public_id, first_name, last_name, role, contact|
          school_name, classroom_name, classrooms_count = role == "student" ? placements[id] : teachers[id]
          Row.new(public_id:, display_name: "#{first_name} #{last_name}", role: role.to_sym, school_name:,
                  classroom_name:, classrooms_count:, contact: Entities::Identity::Contact.mask(contact))
        end
      end

      # La classe principale, non quittée, active, de l'année (ADR-0040, ADR-0041).
      def student_placements(ids, year)
        Orm::ClassroomStudent.joins(classroom: :school)
                             .where(student_id: ids, primary: true, left_at: nil, classrooms: { status: "active", school_year: year })
                             .pluck(:student_id, "schools.name", "classrooms.name")
                             .to_h { |student_id, school_name, classroom_name| [ student_id, [ school_name, classroom_name, nil ] ] }
      end

      # L'établissement principal, et le nombre de classes actives de l'année enseignées, en une lecture.
      def teacher_schools(ids, year)
        taught = Orm::Classroom.joins(:teacher_classrooms).where(status: "active", school_year: year)
                               .where("teacher_classrooms.teacher_id = teacher_schools.teacher_id").select("COUNT(*)").to_sql
        Orm::TeacherSchool.joins(:school).where(teacher_id: ids, primary: true)
                          .pluck(:teacher_id, "schools.name", Arel.sql("(#{taught})"))
                          .to_h { |teacher_id, school_name, count| [ teacher_id, [ school_name, nil, count ] ] }
      end
    end
  end
end
