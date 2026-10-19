# 🔌 INFRA · Queries::School::StudentSearchQuery
# Rôle : les élèves présents d'un établissement dont le nom contient le terme (prénom ou nom d'abord), avec leur classe
# ADR  : 0006, 0036, 0065, 0092 · UDR : 0094 · une requête ; index trigramme des noms ; jamais le numéro de téléphone
module Queries
  module School
    class StudentSearchQuery
      Row = Data.define(:display_name, :classroom_public_id, :classroom_name, :level_name)

      # Trois lettres au moins, après le traitement de la recherche (sans casse, accents ni espaces en trop).
      MIN_LENGTH = 3
      # 20 affichés ; le 21e lu dit seulement qu'il y en a d'autres (UDR-0094 §3.2).
      SHOWN = 20
      # Les expressions des index index_users_on_searchable_full_name et _reversed_name (migration des index trigrammes).
      NAMES = [ "users.first_name || ' ' || users.last_name", "users.last_name || ' ' || users.first_name" ].freeze
      # Un élève présent : adhésion principale non quittée (un élève retiré l'a quittée), compte non anonymisé.
      PRESENT = "JOIN classroom_students ON classroom_students.student_id = users.id AND classroom_students.left_at IS NULL " \
                "AND classroom_students.primary"
      COLUMNS = [ Arel.sql("users.first_name || ' ' || users.last_name"), "classrooms.public_id", "classrooms.name", "levels.name" ].freeze

      def self.searchable?(term) = Queries::Shared::TextSearch.normalize(term).length >= MIN_LENGTH

      # school_id : current_actor.school_id, jamais un paramètre. Classes actives de l'année de cet établissement seulement.
      # → [Row], au plus `limit`, par nom puis classe ; [] sans requête si le terme est trop court.
      def call(school_id:, term:, limit: SHOWN + 1, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        return [] unless self.class.searchable?(term)

        scope = Orm::User.joins(PRESENT).joins("JOIN classrooms ON classrooms.id = classroom_students.classroom_id")
                         .joins("JOIN levels ON levels.id = classrooms.level_id")
                         .where(users: { role: "student", anonymized_at: nil },
                                classrooms: { school_id:, school_year:, status: "active" })
        Queries::Shared::TextSearch.apply(scope, term, columns: NAMES)
                                   .order("users.last_name", "users.first_name", "classrooms.name", "users.id").limit(limit)
                                   .pluck(*COLUMNS).map { Row.new(*it) }
      end
    end
  end
end
