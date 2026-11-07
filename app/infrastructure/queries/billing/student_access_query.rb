# 🔌 INFRA · Queries::Billing::StudentAccessQuery
# Rôle : l'accès d'un élève (gratuit, abonné, bloqué) lu sur la création de son compte et ses cartes activées ; jamais bloqué hors élève
# ADR  : cartes-activation (contexte billing, §4.5 et §4.6)
module Queries
  module Billing
    class StudentAccessQuery
      include Ports::Billing::StudentAccessPort

      # Choix documenté : un enseignant, une direction, un membre de l'équipe ou un compte inconnu reçoit `Access.unrestricted`
      # (statut :subscribed, sans date), jamais un accès « gratuit » dont les jours s'épuiseraient.
      def call(student_id:, at:)
        role, created_at = Orm::User.where(id: student_id).pick(:role, :created_at)
        return Entities::Billing::Access.unrestricted unless role == "student"

        Entities::Billing::Access.for(account_created_on: created_at.to_date, today: at.to_date, subscribed_until: subscribed_until(student_id))
      end

      private

      def subscribed_until(student_id) = Orm::Billing::ActivationCard.where(student_id:, state: "activated").maximum(:valid_until)
    end
  end
end
