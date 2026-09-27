# 🧠 DOMAINE · Dtos::Assessment::AttemptInput
# Rôle : réponse d'un élève à une question : la session, la question et les propositions cochées (identifiants)
# ADR  : 0026, 0054 · UDR : 0007, 0022
module Dtos
  module Assessment
    class AttemptInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      INTEGER = /\A\d+\z/

      attribute :session_public_id, :string
      attribute :question_id, :integer

      validates :session_public_id, :question_id, presence: true
      validates :answer_ids, presence: true

      # Cases à cocher et boutons radio envoient attempt[answer_ids][] ; une valeur seule se lit comme une liste.
      def answer_ids=(value)
        @answer_ids = Array(value).map(&:to_s).grep(INTEGER).map(&:to_i).uniq
      end

      def answer_ids = @answer_ids || []
    end
  end
end
