# 🧠 DOMAINE · Entities::Classroom::StudentArrivalChannel
# Rôle : liste fermée des voies d'arrivée d'un élève dans une classe (classroom_students.joined_via) ; « code » est historique
# ADR  : 0085
module Entities
  module Classroom
    module StudentArrivalChannel
      ALL = %w[standard link code].freeze
      WRITABLE = %w[standard link].freeze
    end
  end
end
