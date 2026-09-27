# 🧠 DOMAINE · Policies::Identity::ReadUserPolicy
# Rôle : lire un compte : soi-même, l'équipe (recherche B8), l'enseignant pour ses élèves sans le contact
# ADR  : 0028
module Policies
  module Identity
    class ReadUserPolicy
      Access = Data.define(:show_contact)

      # target : Entities::Identity::User, absent pour une recherche ; teaches_target : élève d'une classe active qu'il enseigne
      def call(actor:, target: nil, teaches_target: false)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success(Access.new(show_contact: true)) if actor.team? || target&.id == actor.user_id
        return Shared::Result.success(Access.new(show_contact: false)) if actor.teacher? && target&.student? && teaches_target

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
