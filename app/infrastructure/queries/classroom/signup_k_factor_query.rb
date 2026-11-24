# 🔌 INFRA · Queries::Classroom::SignupKFactorQuery
# Rôle : k-factor élève de la période, par classe et par établissement (agrégats seulement, jamais un nom d'élève) en 2 requêtes ; since : première attribution de toute la base
# ADR  : attribution-des-inscriptions-eleves (§4.1, §4.5) · UDR : partage-de-classe-qr-affiche-invitation (§3.4)
module Queries
  module Classroom
    class SignupKFactorQuery
      SOURCES = %i[qr student_invite teacher_link code cold].freeze
      LIMIT = 20

      # k = (qr + student_invite) ÷ inscrits, nil sans inscrit ; school_name : établissement d'une ligne de classe, nil sinon.
      Line = Data.define(:name, :school_name, :signups, *SOURCES) do
        def self.zero(name: nil, school_name: nil) = new(name:, school_name:, signups: 0, **SOURCES.index_with(0))

        def plus(other) = with(signups: signups + other.signups, **SOURCES.to_h { [ it, public_send(it) + other.public_send(it) ] })
        def k = signups.zero? ? nil : (qr + student_invite).fdiv(signups)
      end
      Result = Data.define(:total, :schools, :schools_more, :classrooms, :classrooms_more, :since)

      ROWS = <<~SQL.squish.freeze
        SELECT c.id AS classroom_id, c.name AS classroom_name, s.id AS school_id, s.name AS school_name,
               COUNT(*) AS signups,
               #{SOURCES.map { |source| "COUNT(*) FILTER (WHERE a.source = '#{source}') AS #{source}" }.join(', ')}
          FROM signup_attributions a
          JOIN users u ON u.id = a.student_id AND u.anonymized_at IS NULL
          JOIN classrooms c ON c.id = a.classroom_id
          JOIN schools s ON s.id = c.school_id
         WHERE a.created_at >= :from AND a.created_at < :to
         GROUP BY c.id, c.name, s.id, s.name
      SQL

      def call(from:, to:)
        rows = Orm::SignupAttribution.connection.select_all(Orm::SignupAttribution.sanitize_sql_array([ ROWS, { from:, to: } ])).to_a
        classrooms = rows.map { line(it, it["classroom_name"], it["school_name"]) }
        schools = rows.group_by { it["school_id"] }.values.map { |group| group.map { line(it, group.first["school_name"]) }.reduce(:plus) }
        classrooms, classrooms_more = cap(classrooms)
        schools, schools_more = cap(schools)
        Result.new(total: rows.map { line(it, nil) }.reduce(Line.zero, :plus), schools:, schools_more:,
                   classrooms:, classrooms_more:, since: Orm::SignupAttribution.minimum(:created_at))
      end

      private

      def line(row, name, school_name = nil)
        Line.new(name:, school_name:, signups: row["signups"].to_i, **SOURCES.index_with { row[it.to_s].to_i })
      end

      def cap(lines)
        sorted = lines.sort_by { [ -it.signups, it.name ] }
        [ sorted.first(LIMIT), [ sorted.size - LIMIT, 0 ].max ]
      end
    end
  end
end
