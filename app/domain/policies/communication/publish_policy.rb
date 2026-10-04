# 🧠 DOMAINE · Policies::Communication::PublishPolicy
# Rôle : qui rédige une annonce, et pour qui : l'équipe (nationale ou un établissement), la direction (le sien), l'enseignant (ses classes)
# ADR  : 0028, 0045, 0078 · UDR : 0071
module Policies
  module Communication
    class PublishPolicy
      FORBIDDEN = Shared::Result.failure(:forbidden)
      ROLE_AUDIENCES = %w[all students teachers school_admins].freeze
      # La direction n'écrit pas « à tous » (ADR-0078 §4.2).
      SCHOOL_ADMIN_AUDIENCES = %w[students teachers school_admins].freeze

      # Les faits arrivent tels qu'envoyés, même forgés : c'est ici qu'ils sont refusés. scope : "national" | "school" ;
      # school_id : l'établissement visé (nil si inconnu ou national) ; classroom_ids : les classes cochées (nil pour une
      # classe inconnue) ; teachable_classroom_ids : celles que l'enseignant peut viser (actives, de son établissement,
      # où il enseigne).
      def call(actor:, scope:, school_id:, audience:, classroom_ids:, teachable_classroom_ids:)
        case actor&.role
        when :team then allow(team_place?(scope, school_id) && ROLE_AUDIENCES.include?(audience) && classroom_ids.empty?)
        when :school_admin
          allow(own_school?(actor, scope, school_id) && SCHOOL_ADMIN_AUDIENCES.include?(audience) && classroom_ids.empty?)
        when :teacher then teacher(actor, scope, school_id, audience, classroom_ids, teachable_classroom_ids)
        else FORBIDDEN
        end
      end

      private

      def allow(allowed) = allowed ? Shared::Result.success : FORBIDDEN

      # Nationale sans établissement, ou un établissement connu.
      def team_place?(scope, school_id) = (scope == "national" && school_id.nil?) || (scope == "school" && !school_id.nil?)

      def own_school?(actor, scope, school_id) = scope == "school" && !school_id.nil? && school_id == actor.school_id

      # Aucune classe cochée est une erreur de saisie (« Choisis au moins une de tes classes. »), pas un refus : le
      # formulaire est re-rendu en 422 (PRD §3). Une classe hors de ses classes est un refus.
      def teacher(actor, scope, school_id, audience, classroom_ids, teachable_classroom_ids)
        return FORBIDDEN unless own_school?(actor, scope, school_id) && audience == "classrooms"
        return Shared::Result.failure(:invalid, errors: { classroom_public_ids: [ :no_classroom ] }) if classroom_ids.empty?

        allow((classroom_ids - teachable_classroom_ids).empty?)
      end
    end
  end
end
