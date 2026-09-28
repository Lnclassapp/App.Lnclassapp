# 🔌 INFRA · Queries::Identity::AccountLookupQuery
# Rôle : un compte trouvé par son numéro exact, après normalisation ; pas d'annuaire, pas de recherche partielle (V2)
# ADR  : 0031, 0032, 0050, 0060 · UDR : 0020, 0047
module Queries
  module Identity
    class AccountLookupQuery
      # own_account : le compte de la personne qui cherche, sur lequel aucune action n'est permise ; photo_version : nil sans photo.
      Row = Data.define(:public_id, :display_name, :role, :team_role, :classroom_name, :second_factor_confirmed, :own_account,
                        :photo_version)

      COLUMNS = %i[id public_id first_name last_name role team_role].freeze

      # → Row | nil (numéro inconnu ou hors format)
      def call(contact:, viewer_id:)
        normalized = Entities::Identity::Contact.normalize(contact)
        return if normalized.nil?

        id, public_id, first_name, last_name, role, team_role = Orm::User.where(contact: normalized).pick(*COLUMNS)
        return if id.nil?

        Row.new(public_id:, display_name: "#{first_name} #{last_name}", role: role.to_sym, team_role:,
                classroom_name: classroom_name(id), second_factor_confirmed: second_factor_confirmed?(id),
                own_account: id == viewer_id, photo_version: PhotoVersions.for(user_ids: [ id ])[id])
      end

      private

      def classroom_name(user_id)
        Orm::ClassroomStudent.joins(:classroom).where(student_id: user_id, primary: true, left_at: nil).pick("classrooms.name")
      end

      def second_factor_confirmed?(user_id) = Orm::TotpCredential.where(user_id:).where.not(confirmed_at: nil).exists?
    end
  end
end
