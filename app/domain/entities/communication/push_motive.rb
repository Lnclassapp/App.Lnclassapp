# 🧠 DOMAINE · Entities::Communication::PushMotive
# Rôle : les sept motifs de notification, leur priorité quand plusieurs sont prêts
# ADR  : 0146 (§3.2) · XXXX envois de notifications (§4, §6) · PRD §3.1
module Entities
  module Communication
    module PushMotive
      # Du plus urgent au moins urgent : un seul motif part par passage (PRD §3.2).
      PRIORITY = %w[quiz_prep assignment_due assignment_new announcement unfinished result inactive].freeze
      ALL = PRIORITY
      # Les trois seuls motifs qu'un admin peut laisser partir seuls (case « Automatique ») ; les relances se valident chaque jour.
      AUTOMATABLE = %w[quiz_prep assignment_due assignment_new].freeze
      # Ce que l'équipe peut valider dans le plan du jour : tout sauf l'annonce, décidée à la publication.
      PLANNABLE = (PRIORITY - %w[announcement]).freeze

      # 0 pour le plus urgent ; un motif inconnu lève, il ne passe pas en silence.
      def self.rank(motive) = PRIORITY.index(motive) || raise(ArgumentError, "motif inconnu : #{motive.inspect}")
      def self.valid?(motive) = PRIORITY.include?(motive)
      def self.automatable?(motive) = AUTOMATABLE.include?(motive)
    end
  end
end
