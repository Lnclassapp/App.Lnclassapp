# 🧠 DOMAINE · Entities::School::StaffPosition
# Rôle : les quatre fonctions de la direction (ADR-0044) et la table des gestes de chaque fonction
# ADR  : 0044, 0066
module Entities
  module School
    module StaffPosition
      ALL = %w[principal censor educator secretary].freeze
      MANAGERS = %w[principal censor].freeze
      EVERYONE = %i[read add_classroom place_student].freeze
      MANAGE = %i[invite_staff regenerate_code detach_teacher reinstate_teacher detach_staff].freeze
      GESTURES = {
        "principal" => [ *EVERYONE, *MANAGE ],
        "censor" => [ *EVERYONE, *MANAGE ],
        "educator" => EVERYONE,
        "secretary" => EVERYONE
      }.freeze
      # :invite_principal n'est à aucune fonction : l'équipe seule (StaffPolicy, règle 1).
      ALL_GESTURES = [ *EVERYONE, *MANAGE, :invite_principal ].freeze

      def self.allows?(position, gesture)
        raise ArgumentError, "geste inconnu : #{gesture.inspect}" unless ALL_GESTURES.include?(gesture)

        GESTURES.fetch(position, []).include?(gesture)
      end
    end
  end
end
