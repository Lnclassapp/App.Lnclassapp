# 🧠 DOMAINE · Entities::Assessment::Answer
# Rôle : un élément de question (proposition, réponse acceptée, valeur, étape ou paire) ; correct vaut nil dans une copie sans correction
# ADR  : 0054, 0091 (§4.2 : match_content, la colonne de droite d'une paire « matching »)
module Entities
  module Assessment
    Answer = Data.define(:id, :position, :content, :correct, :match_content) do
      def initialize(match_content: nil, **) = super
    end
  end
end
