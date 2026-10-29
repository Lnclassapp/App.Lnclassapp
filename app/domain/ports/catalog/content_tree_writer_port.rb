# 🧠 DOMAINE · Ports::Catalog::ContentTreeWriterPort
# Rôle : contrat d'écriture en masse d'arbres de contenu déjà validés et identifiés, tout en draft
# ADR  : 0035, 0039, 0068, 0091, 0105, 0113, 0115, XXXX
module Ports
  module Catalog
    module ContentTreeWriterPort
      # Nœuds que remplissent les imports I1 à I3. slug et public_id sont tirés par le domaine avant l'insertion.
      # course_id (resp. essential_id) vaut nil pour un nœud porté par son parent, l'id du parent existant sinon.
      AnswerNode = Data.define(:position, :content, :correct, :match_content) do
        def initialize(match_content: nil, **) = super
      end
      # image_description : l'image annoncée par l'import, jamais l'image (ADR-0105 §4.6) ; nil sans image.
      # ADR-0115 : points (BigDecimal, 1 par défaut), unit et starter (nil s'ils sont vides), criteria (sans critère vide).
      QuestionNode = Data.define(:position, :content, :explanation, :question_type, :answers, :numeric_tolerance, :image_description,
                                 :points, :unit, :starter, :criteria) do
        def initialize(numeric_tolerance: nil, image_description: nil, points: BigDecimal("1"), unit: nil, starter: nil, criteria: [], **) = super

        # Une question d'un fichier d'import déjà validé (ContentNode), commune aux trois imports. L'ancienne application
        # nomme is_correct ce que le schéma nomme correct ; hors choix, chaque élément est juste (ADR-0091 §4.2).
        # L'image n'arrive que par sa description, et seul le schéma lnclass.course-tree l'admet (ADR-0105 §4.6).
        def self.from_import(question, position:)
          choice = %w[choice select].include?(Entities::Assessment::Question.kind_name_for(question["question_type"]))
          answers = Array(question["answers"]).each_with_index.map do |answer, rank|
            AnswerNode.new(position: rank + 1, content: answer["content"].strip,
                           correct: !choice || answer.fetch("correct") { answer["is_correct"] } == true,
                           match_content: answer["match"].to_s.strip.presence)
          end
          new(position:, content: question["content"].strip, explanation: question["explanation"].to_s.strip.presence,
              question_type: question["question_type"], numeric_tolerance: question["tolerance"]&.then { BigDecimal(it.to_s) }, answers:,
              image_description: question.dig("image", "description")&.squish,
              points: question["points"]&.then { BigDecimal(it.to_s) } || BigDecimal("1"), unit: question["unit"].to_s.strip.presence,
              starter: question["starter"].to_s.strip.presence, criteria: Array(question["criteria"]).map { it.to_s.strip }.reject(&:empty?))
        end
      end
      # position : indicative ; l'écrivain numérote les exercices par leçon, dans l'ordre où il les reçoit.
      # statement_blocks : le sujet en blocs, déjà validé par l'adaptateur (ADR-0115) ; nil sans blocs.
      # figure_key (v3, ADR-XXXX §4.3) : la clé de la figure de la leçon citée par l'exercice ; nil sans figure.
      ExerciseNode = Data.define(:public_id, :essential_id, :title, :statement, :exercise_type, :position, :questions, :statement_blocks,
                                 :figure_key) do
        def initialize(statement_blocks: nil, figure_key: nil, **) = super
      end
      # Une notion v3 (ADR-XXXX §4.1, §4.3) : sheet est la fiche au gabarit fixe, { remember:, method: [], example: { statement:, steps: [] },
      # pitfall:, figure_key: } (clés texte, jsonb tel quel) ; exercises : l'exercice de la notion. Pas de content (retiré).
      NotionNode = Data.define(:slug, :course_id, :name, :position, :sheet, :exercises)
      # existing_id : l'id de la notion déjà en base d'une leçon réimportée (ADR-0113 §4.4) ; nil pour une notion à créer.
      EssentialNode = Data.define(:slug, :course_id, :name, :subtitle, :content, :position, :exercises, :existing_id) do
        def initialize(existing_id: nil, **) = super
      end
      # exercises : les exercices de toute la leçon, sans notion (ADR-0113) ; ceux d'une notion sont portés par sa fiche.
      # existing_id : l'id d'une leçon déjà en base, réimportée : ni elle ni ses notions ne sont écrites, ses exercices sont archivés
      # puis remplacés par ceux du nœud ; nil pour une leçon à créer.
      # v3 : figures (Array<Hash> clés texte, jsonb tel quel), sheet_theme ("blue", "teal" ou "burgundy") et notions (NotionNode) ;
      # un nœud v3 laisse essentials vide.
      CourseNode = Data.define(:slug, :name, :subtitle, :content, :level_id, :series_id, :material_id, :essentials, :exercises,
                               :existing_id, :figures, :sheet_theme, :notions) do
        def initialize(exercises: [], existing_id: nil, figures: [], sheet_theme: "blue", notions: [], **) = super
      end

      # Appelé dans une transaction ; une table après l'autre, parents d'abord (insert_all ou COPY, ADR-0068) ; lève si la base refuse.
      # → { courses:, essentials:, exercises:, questions:, answers: } (lignes créées), archived: les exercices archivés des leçons réimportées
      def write(author_id:, at:, courses: [], essentials: [], exercises: [])
        raise NotImplementedError, "#{self.class} doit implémenter #write"
      end

      # ADR-XXXX §4.4 : remplace entière une leçon encore en brouillon, dans la transaction de l'appelant, la leçon verrouillée (FOR UPDATE) :
      # exercices, questions, réponses, séances et tentatives sur ces exercices, notions et leurs lectures, puis réécriture depuis `tree`
      # (CourseNode v3 avec existing_id: course_id). La leçon garde son id et son slug. Lève si un contenu n'est plus en brouillon.
      # → { courses:, essentials:, exercises:, questions:, answers: } (lignes créées)
      def replace_draft(course_id:, tree:)
        raise NotImplementedError, "#{self.class} doit implémenter #replace_draft"
      end
    end
  end
end
