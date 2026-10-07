# 🧠 DOMAINE · Entities::School::Staff
# Rôle : rattachement d'un compte direction à son établissement : arrivée (invitation ou code), archivage, échéances
# ADR  : 0065, 0077
module Entities
  module School
    Staff = Data.define(:user_id, :user_public_id, :school_id, :joined_via, :joined_at, :archived_at, :archived_by_id) do
      # ADR-0077 §4 : 3 directions actives arrivées par le code, au plus ; les invitées n'y comptent pas.
      self::CODE_CAP = 3
      # Une direction arrivée depuis moins de 7 jours ne retire personne ; le bandeau d'arrivée dure autant.
      self::NEWCOMER_DAYS = 7
      # Un compte archivé se restaure 30 jours, puis il est supprimé.
      self::RETENTION_DAYS = 30
      self::DAY = 86_400
      self::JOINED_VIA = %w[invitation code].freeze

      def archived? = !archived_at.nil?
      def by_code? = joined_via == "code"
      def newcomer?(now) = joined_at > now - (self.class::NEWCOMER_DAYS * self.class::DAY)
      def deletion_due_at = archived_at && (archived_at + (self.class::RETENTION_DAYS * self.class::DAY))
    end
  end
end
