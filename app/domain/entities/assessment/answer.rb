# 🧠 DOMAINE · Entities::Assessment::Answer
# Rôle : un élément de question (proposition, réponse acceptée, valeur, étape ou paire) ; correct vaut nil dans une copie sans correction
# ADR  : 0054, 0091 (§4.2 : match_content, la colonne de droite d'une paire « matching »), XXXX-questions-a-plusieurs-cases-et-indice (§4 : blank)
module Entities
  module Assessment
    # blank : la case (0 à 5) à laquelle la réponse se rattache, 0 pour une question à une seule case.
    Answer = Data.define(:id, :position, :content, :correct, :match_content, :blank) do
      def initialize(match_content: nil, blank: 0, **) = super
    end
  end
end
