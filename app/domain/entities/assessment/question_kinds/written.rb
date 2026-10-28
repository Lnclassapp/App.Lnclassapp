# 🧠 DOMAINE · Entities::Assessment::QuestionKinds::Written
# Rôle : réponse rédigée : un texte de 2 000 caractères au plus, vide admis, jamais noté ; le corrigé type est obligatoire
# ADR  : 0115 (§4 ; menace : docs/chantiers/correction-comme-en-classe/menace.md, W1 à W5)
module Entities
  module Assessment
    module QuestionKinds
      class Written
        AUTO_GRADED = false
        TEXT_MAX = 2000
        STARTER_MAX = 150
        CRITERIA_MAX = 8
        CRITERION_MAX = 150
        INPUT = :response_text
        INVALID = { response_text: [ :invalid_text ] }.freeze

        # Corrigé type (le champ explication) obligatoire, aucune proposition, grille de 8 critères de 150 caractères au plus.
        def self.structure_errors(answers:, explanation:, starter: nil, criteria: [], **)
          errors = []
          errors << :explanation_required if explanation.to_s.strip.empty?
          errors << :answers_not_allowed if answers.any?
          errors << :starter_too_long if starter.to_s.strip.length > STARTER_MAX
          errors.concat(criteria_errors(criteria))
        end

        def self.criteria_errors(criteria)
          errors = []
          errors << :criteria_too_many if criteria.size > CRITERIA_MAX
          errors << :criteria_too_long if criteria.any? { it.to_s.strip.length > CRITERION_MAX }
          errors << :criteria_blank if criteria.any? { it.to_s.strip.empty? }
          errors
        end

        # Du texte UTF-8 sans octet nul (PostgreSQL le refuse), de 2 000 caractères au plus ; le texte vide est permis.
        # Le texte n'est jamais transformé ni nettoyé : c'est la vue qui l'échappe.
        def self.well_formed?(_question, text)
          text.is_a?(String) && text.encoding == Encoding::UTF_8 && text.valid_encoding? && text.length <= TEXT_MAX && !text.include?("\0")
        end

        # Jamais notée par la machine (ADR-0115, D7).
        def self.correct?(_question, _text) = false
      end
    end
  end
end
