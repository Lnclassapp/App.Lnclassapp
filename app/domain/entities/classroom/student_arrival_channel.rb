# 🧠 DOMAINE · Entities::Classroom::StudentArrivalChannel
# Rôle : liste fermée des voies d'arrivée d'un élève dans une classe (classroom_students.joined_via) ; « code » est celui du code de classe
# ADR  : 0085, 0109 (§4.6)
module Entities
  module Classroom
    module StudentArrivalChannel
      ALL = %w[standard link code].freeze
      WRITABLE = %w[standard link code].freeze
    end
  end
end
