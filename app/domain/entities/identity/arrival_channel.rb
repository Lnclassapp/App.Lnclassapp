# 🧠 DOMAINE · Entities::Identity::ArrivalChannel
# Rôle : liste fermée des voies d'arrivée d'un enseignant (teacher_profiles.joined_via) ; « code » est historique, plus écrit
# ADR  : 0082
module Entities
  module Identity
    module ArrivalChannel
      ALL = %w[standard colleague direction team code].freeze
      WRITABLE = %w[standard colleague direction team].freeze
    end
  end
end
