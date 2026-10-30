# 🧠 DOMAINE · Entities::Assessment::SheetGrade
# Rôle : la note de la feuille « Prépare interros », sur 10 au demi-point, sa mention et son détail, lus sur les questions justes
# ADR  : XXXX-sujets-de-devoir-et-verification-sur-la-feuille (§4) ; la note sur 20 des autres pages reste celle de Grading (ADR-0115)
module Entities
  module Assessment
    class SheetGrade
      OUT_OF = 10
      # Mentions de la maquette, de la plus haute à la plus basse : [seuil sur 10, symbole]. Les libellés sont dans les locales.
      MENTIONS = [ [ 9, :excellent ], [ 7, :very_good ], [ 5, :fair ] ].freeze
      LOWEST_MENTION = :needs_work

      attr_reader :correct, :total

      # correct : nombre de questions justes ; total : nombre de questions de l'exercice.
      def initialize(correct:, total:)
        raise ArgumentError, "correct doit être compris entre 0 et total (#{correct} / #{total})" unless correct.between?(0, total)

        @correct = correct
        @total = total
      end

      # Float sur 10, au demi-point le plus proche ; 0.0 sans question.
      def score = total.zero? ? 0.0 : (correct.fdiv(total) * 2 * OUT_OF).round / 2.0

      def mention = MENTIONS.find { |threshold, _| score >= threshold }&.last || LOWEST_MENTION

      # Les valeurs du libellé « x bonne(s) réponse(s) sur n. » (pluriel selon count).
      def detail = { count: correct, total: }
    end
  end
end
