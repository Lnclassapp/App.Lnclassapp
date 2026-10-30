# 🧠 DOMAINE · Entities::Assessment::Question
# Rôle : une question d'exercice ; sa structure, la forme d'une réponse et la correction sont déléguées à son type
# ADR  : 0039, 0054, 0091 (§4.3 : un type par classe, sous question_kinds/), 0105, 0115, 0120-questions-a-plusieurs-cases-et-indice
module Entities
  module Assessment
    # answers : [Answer], dans l'ordre des positions ; numeric_tolerance : marge d'un type numeric (BigDecimal | nil) ;
    # image_description : l'image annoncée par l'import (ADR-0105 §4.6) ; image : Shared::ContentImage | nil.
    # ADR-0115 : points (BigDecimal, 0,5 à 20 par demi-point, 1 par défaut) ; unit : l'unité d'une réponse chiffrée ;
    # starter : le début de phrase d'une réponse rédigée ; criteria : sa grille de vérification (jamais enregistrée côté élève).
    # hint : l'indice facultatif (500 caractères) ; les cases d'une réponse sont portées par Answer#blank.
    Question = Data.define(:id, :position, :content, :explanation, :question_type, :answers, :numeric_tolerance,
                           :image_description, :image, :points, :unit, :starter, :criteria, :hint) do
      # Les six premiers attributs sont obligatoires ; la marge, l'image, les points et le reste sont facultatifs.
      def initialize(numeric_tolerance: nil, image_description: nil, image: nil, points: BigDecimal("1"), unit: nil, starter: nil,
                     criteria: [], hint: nil, **) = super

      # Classe de règles du type (QuestionKinds::Choice, FillBlank…), ou nil pour un type inconnu.
      def self.kind_for(question_type)
        name = Question::KINDS[question_type.to_s]
        name && QuestionKinds.const_get(name)
      end

      # Nom court du type de règles (« choice », « fill_blank »…), celui des partials par type. → String | nil
      def self.kind_name_for(question_type) = Question::KINDS[question_type.to_s]&.then { Question::KIND_NAMES.fetch(it) }

      # Règles de l'ADR-0039, du PRD (AS-03), de l'ADR-0091 §4.2 et de l'ADR-0115 → [Symbol], vide si la question est bien construite.
      # answers : objets qui répondent à correct, content et match_content (Answer, ou proposition importée).
      def self.structure_errors_for(question_type:, answers:, content: nil, numeric_tolerance: nil, explanation: nil, points: BigDecimal("1"),
                                    unit: nil, starter: nil, criteria: [])
        kind = kind_for(question_type)
        return [ :unknown_question_type ] if kind.nil?

        kind.structure_errors(question_type: question_type.to_s, answers:, content: content.to_s, numeric_tolerance:, explanation:, unit:,
                              starter:, criteria:) + common_errors(kind, points:, unit:, starter:, criteria:)
      end

      # Points de 0,5 à 20 par demi-point ; unité, début de phrase et grille seulement sur le type qui les porte.
      def self.common_errors(kind, points:, unit:, starter:, criteria:)
        errors = []
        errors << :points_out_of_range unless Question::POINTS.cover?(points) && ((points * 2) % 1).zero?
        errors << :unit_not_allowed if given?(unit) && kind != QuestionKinds::Numeric
        errors << :starter_not_allowed if given?(starter) && kind != QuestionKinds::Written
        errors << :criteria_not_allowed if criteria.any? && kind != QuestionKinds::Written
        errors
      end

      def self.given?(text) = !text.to_s.strip.empty?

      def kind = Question.kind_for(question_type)
      def kind_name = Question.kind_name_for(question_type)
      def expected_count = Question::EXPECTED.fetch(question_type.to_s.to_sym)
      # Nombre de cases : la plus haute case des réponses plus un (0 à 5 : de 1 à 6 cases), 1 sans réponse.
      def blanks = (answers.map(&:blank).max || 0) + 1

      # Verdict de chaque case pour la réponse de l'élève (une liste de textes, une par case) → [Boolean]. Le contrat est posé ici ;
      # la règle de chaque type vit dans sa classe (QuestionKinds), qui répond à blank_results quand elle juge case par case.
      def blank_results(response)
        raise NotImplementedError, "#{question_type} ne juge pas case par case" unless kind.respond_to?(:blank_results)

        kind.blank_results(self, response)
      end

      def answer_ids = answers.map(&:id)
      def correct_answer_ids = answers.select(&:correct).map(&:id)
      # Identifiants dans l'ordre des positions : le bon ordre d'une question « ordering », la colonne de gauche d'un « matching ».
      def ids_by_position = answers.sort_by(&:position).map(&:id)

      # response : identifiants (choix, ordre, relier) ou texte saisi (trous, nombre), selon kind::INPUT.
      def well_formed?(response) = kind.well_formed?(self, response)
      def correct?(response) = kind.correct?(self, response)

      def structure_errors
        Question.structure_errors_for(question_type:, answers:, content:, numeric_tolerance:, explanation:, points:, unit:, starter:, criteria:)
      end

      # Corrigée par la machine (ADR-0115) : seules ces questions entrent dans la note. Un type inconnu ne l'est pas.
      def auto_graded? = kind ? kind::AUTO_GRADED : false

      # Ce qui manque pour publier, sans gêner l'enregistrement d'un brouillon (ADR-0105 §4.4) → [Symbol].
      def image_errors
        return [ :image_alt_blank ] if image && !image.alt?
        return [ :image_missing ] if image.nil? && !image_description.to_s.strip.empty?

        []
      end

      # Copie montrable avant une tentative : aucune proposition ne dit si elle est correcte.
      def without_correction = with(answers: answers.map { |answer| answer.with(correct: nil) })
    end
    Question::EXPECTED = QuestionKinds::Choice::EXPECTED
    # Type de question → classe de règles. L'ordre est celui du menu de l'équipe.
    Question::KINDS = {
      "true_false" => :Choice, "single_choice" => :Choice, "multiple_correct_2" => :Choice, "multiple_correct_3" => :Choice,
      "fill_blank" => :FillBlank, "numeric" => :Numeric, "ordering" => :Ordering, "matching" => :Matching,
      "select" => :Select, "written" => :Written, "notebook" => :Notebook
    }.freeze
    Question::KIND_NAMES = { Choice: "choice", FillBlank: "fill_blank", Numeric: "numeric", Ordering: "ordering",
                             Matching: "matching", Select: "select", Written: "written", Notebook: "notebook" }.freeze
    # ADR-0115 : de 0,5 à 20 points, par demi-point (la contrainte SQL questions_points_range dit la même chose).
    Question::POINTS = (BigDecimal("0.5")..BigDecimal("20"))
    Question::TYPES = Question::KINDS.keys.freeze
  end
end
