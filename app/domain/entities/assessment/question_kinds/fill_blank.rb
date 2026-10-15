# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::FillBlank
# Rôle : texte à trous (ADR-0091 §4.3), livré au Lot D ; d'ici là, aucune question de ce type ne se crée
# ADR  : 0091
module Entities
  module Assessment
    module QuestionKinds
      class FillBlank
        INPUT = :response_text
        INVALID = { response_text: [ :blank_text ] }.freeze

        def self.structure_errors(**) = [ :not_available ]
        def self.well_formed?(_question, _response) = false
        def self.correct?(_question, _response) = false
      end
    end
  end
end
