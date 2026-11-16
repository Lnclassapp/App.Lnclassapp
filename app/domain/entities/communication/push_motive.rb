# 🧠 DOMAINE · Entities::Communication::PushMotive
# Rôle : les six motifs de notification, leur priorité quand plusieurs sont prêts
# ADR  : XXXX-notifications-web-push-aux-eleves (§3.2) · PRD §3.1
module Entities
  module Communication
    module PushMotive
      # Du plus urgent au moins urgent : un seul motif part par passage (PRD §3.2).
      PRIORITY = %w[quiz_prep assignment_due announcement unfinished result inactive].freeze
      ALL = PRIORITY

      # 0 pour le plus urgent ; un motif inconnu lève, il ne passe pas en silence.
      def self.rank(motive) = PRIORITY.index(motive) || raise(ArgumentError, "motif inconnu : #{motive.inspect}")
      def self.valid?(motive) = PRIORITY.include?(motive)
    end
  end
end
