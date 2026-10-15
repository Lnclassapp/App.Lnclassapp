# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Matching
# Rôle : relier (ADR-0091 §4.3), livré au Lot G ; d'ici là, aucune question de ce type ne se crée
# ADR  : 0091
module Entities
  module Assessment
    module QuestionKinds
      class Matching
        INPUT = :display_order
        INVALID = { display_order: [ :incomplete_pairs ] }.freeze

        def self.structure_errors(**) = [ :not_available ]
        def self.well_formed?(_question, _response) = false
        def self.correct?(_question, _response) = false
      end
    end
  end
end
