# 🧠 DOMAINE · UseCases::Catalog::CheckPractice
# Rôle : juge l'exercice d'entraînement d'une notion (« Je m'entraîne » de la fiche) case par case et rend le corrigé ; n'écrit rien
# ADR  : XXXX-entrainement-de-notion-corrige-sans-trace (§4), XXXX-questions-a-plusieurs-cases-et-indice, 0028, 0035 · UDR : XXXX-je-m-entraine-dans-la-fiche (§3.4)
module UseCases
  module Catalog
    # Aucun port d'écriture : l'absence de trace tient à la construction. Les réponses sont celles de la fiche, par question (clé = position
    # de la question, de 0) : { "blanks" => { "0" => "4,8" }, "ids" => ["2"], "order" => ["1", "0", "2"], "text" => "…" }. Les propositions
    # d'une liste, d'un QCM, d'un ordre ou d'un relier sont désignées par leur indice d'affichage (jamais leur identifiant), comme dans la
    # copie : la fiche et le use case mélangent avec la même graine, tirée de l'empreinte de l'entraînement.
    class CheckPractice
      TEXT_MAX = 200
      # verdicts : :correct, :wrong ou :blank, un par case ([] pour une réponse rédigée ou un cahier, qui n'ont pas de verdict) ;
      # expected : la bonne réponse de chaque case, en texte.
      QuestionResult = Data.define(:number, :kind_name, :verdicts, :expected, :explanation)
      # status : :all_correct, :some_wrong ou :incomplete (une case vide et aucune fausse) ; :done sans question corrigée.
      # practice : l'entraînement tel que la fiche le montre (CheckPractice.shown) ; notion_name : le nom de la notion.
      Check = Data.define(:questions, :status, :practice, :notion_name)

      def self.seed(digest) = digest.to_s.to_i(16) & 0x7fffffff

      # Les identifiants des propositions d'une question dans l'ordre où la fiche les montre, et où l'indice d'affichage les désigne.
      # La solution d'un ordre ou d'un relier n'est jamais donnée telle quelle.
      def self.display_ids(digest, question)
        solution = %w[ordering matching].include?(question.kind_name) ? question.ids_by_position : nil
        Entities::Assessment::AnswerShuffle.for(session_id: seed(digest), question_id: question.id, ids: question.answer_ids, avoid: solution)
      end

      # La bonne réponse de chaque case, en texte : le corrigé qui suit « Vérifier » et celui de l'équipe. → Array<String>
      def self.expected_for(question)
        case question.kind_name
        when "written", "notebook" then []
        when "ordering" then [ question.answers.sort_by(&:position).map(&:content).join(" → ") ]
        when "matching" then [ question.answers.sort_by(&:position).map { "#{it.content} → #{it.match_content}" }.join(" ; ") ]
        when "choice" then [ question.answers.select(&:correct).map(&:content).join(" ; ") ]
        else Array.new(question.blanks) { |blank| accepted(question, blank) }
        end
      end

      def self.accepted(question, blank)
        answers = question.answers.select { it.blank == blank }
        answers = answers.select(&:correct) if question.kind_name == "select"
        text = answers.map(&:content).join(" / ")
        question.unit.present? ? "#{text} #{question.unit}" : text
      end

      # L'entraînement montrable avant « Vérifier » : ni explication, ni réponse, ni `correct` (CA-3), les propositions dans l'ordre mélangé
      # que `display_ids` rend et que le use case relit pour juger.
      def self.shown(practice)
        hidden = practice.without_correction
        hidden.with(questions: hidden.questions.map do |question|
          by_id = question.answers.index_by(&:id)
          question.with(answers: display_ids(practice.digest, question).filter_map { by_id[it] })
        end)
      end

      # policy : Policies::Catalog::ReadPublishedPolicy ; level_policy : Policies::Catalog::ReadOwnLevelPolicy.
      def initialize(notions:, policy:, level_policy:)
        @notions = notions
        @policy = policy
        @level_policy = level_policy
      end

      # audience : Entities::Catalog::LevelAudience de l'élève (nil pour un autre rôle). → Shared::Result de Check
      def call(actor:, audience:, course_slug:, notion_slug:, digest:, responses:)
        notion = @notions.practice_for(course_slug:, notion_slug:, statuses: actor.team? ? %w[draft published] : %w[published])
        return Shared::Result.failure(:not_found) if notion.nil? || refused?(actor, audience, notion)
        return Shared::Result.failure(:conflict, errors: { base: [ :changed ] }) unless notion.practice.digest == digest

        results = notion.practice.questions.map { |question| judge(question, notion.practice.digest, input_for(responses, question)) }
        Shared::Result.success(Check.new(questions: results, status: status_of(results), practice: self.class.shown(notion.practice), notion_name: notion.name))
      end

      private

      def refused?(actor, audience, notion)
        @policy.call(actor:, content: notion).failure? ||
          @level_policy.call(actor:, audience:, course_level: { level_id: notion.level_id, series_id: notion.series_id }).failure?
      end

      def input_for(responses, question)
        input = responses.is_a?(Hash) ? responses[question.id.to_s] : nil
        input.is_a?(Hash) ? input : {}
      end

      def judge(question, digest, input)
        verdicts = verdicts_for(question, digest, input)
        QuestionResult.new(number: question.position, kind_name: question.kind_name, verdicts:, expected: self.class.expected_for(question), explanation: question.explanation)
      end

      def verdicts_for(question, digest, input)
        case question.kind_name
        when "written", "notebook" then []
        when "numeric", "fill_blank" then text_verdicts(question, texts(input, question))
        when "select" then select_verdicts(question, digest, input)
        when "choice" then [ choice_verdict(question, digest, input) ]
        else [ order_verdict(question, digest, input) ]
        end
      end

      # Une saisie vide est « à compléter » ; une seule case est jugée par la règle de la copie, plusieurs par la règle de chaque case.
      def text_verdicts(question, texts)
        return [ single_text_verdict(question, texts.first) ] if question.blanks == 1

        question.blank_results(texts).each_with_index.map { |ok, index| texts[index].strip.empty? ? :blank : (ok ? :correct : :wrong) }
      end

      def single_text_verdict(question, text)
        return :blank if text.strip.empty?

        question.well_formed?(text) && question.correct?(text) ? :correct : :wrong
      end

      def texts(input, question)
        given = input["blanks"].is_a?(Hash) ? input["blanks"] : {}
        Array.new(question.blanks) { given[it.to_s].to_s.slice(0, TEXT_MAX) }
      end

      # Chaque case est une liste déroulante : l'indice d'affichage de la proposition choisie, ou rien.
      def select_verdicts(question, digest, input)
        shuffled = self.class.display_ids(digest, question)
        given = input["blanks"].is_a?(Hash) ? input["blanks"] : {}
        picked = Array.new(question.blanks) { shuffled_at(shuffled, given[it.to_s]) }
        return [ select_verdict(question, picked.first) ] if question.blanks == 1

        by_id = question.answers.index_by(&:id)
        results = question.blank_results(picked.map { by_id[it]&.content.to_s })
        picked.each_with_index.map { |id, index| id.nil? ? :blank : (results[index] ? :correct : :wrong) }
      end

      # La proposition que désigne l'indice posté ; rien si l'indice est vide, illisible ou hors des bornes.
      def shuffled_at(shuffled, value)
        at = index_of(value)
        shuffled[at] if at&.between?(0, shuffled.size - 1)
      end

      def select_verdict(question, id)
        return :blank if id.nil?

        question.well_formed?([ id ]) && question.correct?([ id ]) ? :correct : :wrong
      end

      def choice_verdict(question, digest, input)
        indices = Array(input["ids"]).map { index_of(it) }
        return :blank if indices.empty?

        ids = indices.all? ? Entities::Assessment::AnswerShuffle.select(self.class.display_ids(digest, question), indices) : []
        question.well_formed?(ids) && question.correct?(ids) ? :correct : :wrong
      end

      # Un rang laissé sur « Choisir » est une case à compléter ; un ordre qui n'est pas une permutation est faux.
      def order_verdict(question, digest, input)
        given = Array(input["order"]).first(question.answers.size)
        return :blank if given.size < question.answers.size || given.any? { it.to_s.strip.empty? }

        indices = given.map { index_of(it) }
        ids = indices.all? ? Entities::Assessment::AnswerShuffle.pick(self.class.display_ids(digest, question), indices) : []
        question.well_formed?(ids) && question.correct?(ids) ? :correct : :wrong
      end

      def index_of(value) = Integer(value.to_s, 10, exception: false)

      def status_of(results)
        verdicts = results.flat_map(&:verdicts)
        return :done if verdicts.empty?
        return :some_wrong if verdicts.include?(:wrong)

        verdicts.include?(:blank) ? :incomplete : :all_correct
      end
    end
  end
end
