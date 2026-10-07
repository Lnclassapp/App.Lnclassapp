# 🧠 DOMAINE · Entities::Identity::FullName
# Rôle : découpe le « Nom complet » saisi en un champ : le premier mot est le nom, le reste les prénoms (ordre ivoirien)
# ADR  : 0037, 0082 · UDR : 0078
module Entities
  module Identity
    module FullName
      # « N'GUESSAN  Konan Jean-Baptiste » → ["N'GUESSAN", "Konan Jean-Baptiste"], casse gardée ; nil sous deux mots.
      def self.split(raw)
        last_name, first_name = raw.to_s.squish.split(" ", 2)
        [ last_name, first_name ] if first_name.present?
      end
    end
  end
end
