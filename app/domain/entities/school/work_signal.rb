# 🧠 DOMAINE · Entities::School::WorkSignal
# Rôle : pastille de la direction lue sur le taux de rendu : vert dès 70 %, jaune dès 40 %, rouge en dessous, rien sans taux
# UDR  : 0072 (§2.5) · seuils fixes décidés par le porteur, testés à leurs bornes
module Entities
  module School
    module WorkSignal
      GREEN_FROM = 70
      YELLOW_FROM = 40
      # L'ordre de la légende.
      ALL = %i[green yellow red].freeze

      # rate : taux de rendu en % entier, ou nil quand il n'est pas calculé (aucun élève, aucun devoir). → Symbol | nil
      def self.for(rate)
        return if rate.nil?
        return :green if rate >= GREEN_FROM

        rate >= YELLOW_FROM ? :yellow : :red
      end
    end
  end
end
