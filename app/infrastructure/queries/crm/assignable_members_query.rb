# 🔌 INFRA · Queries::Crm::AssignableMembersQuery
# Rôle : membres de l'équipe à qui l'on peut confier une école ou une relance : `admin` et `field`, non anonymisés
# ADR  : XXXX (contexte crm)
module Queries
  module Crm
    class AssignableMembersQuery
      Member = Data.define(:user_id, :public_id, :name)

      # → [Member], triés par nom
      def call
        Orm::User.where(role: "team", team_role: Policies::Crm::ManageCrmPolicy::TEAM_ROLES, anonymized_at: nil)
                 .order(:first_name, :last_name, :id)
                 .pluck(:id, :public_id, :first_name, :last_name)
                 .map { |id, public_id, first, last| Member.new(user_id: id, public_id:, name: [ first, last ].compact_blank.join(" ")) }
      end
    end
  end
end
