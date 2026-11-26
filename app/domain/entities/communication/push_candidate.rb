# 🧠 DOMAINE · Entities::Communication::PushCandidate
# Rôle : un motif prêt pour un élève, lu au moment de l'envoi par une requête de candidats
# ADR  : 0146 (§4.1, §6)
module Entities
  module Communication
    # Contrat gelé au Lot 0. object_key : interdit le doublon (PRD §3.1) ; url : chemin de la même origine ;
    # variables : ce que le gabarit du motif utilise (matière, nombre d'exercices), jamais un nom ni une note ; valid_until : après, le motif expire.
    PushCandidate = Data.define(:user_id, :motive, :object_key, :url, :variables, :valid_until) do
      def initialize(user_id:, motive:, object_key:, url:, variables: {}, valid_until: nil)
        raise ArgumentError, "motif inconnu : #{motive.inspect}" unless PushMotive.valid?(motive)

        super
      end

      def priority = PushMotive.rank(motive)
      def expired?(now) = !valid_until.nil? && valid_until <= now
    end
  end
end
