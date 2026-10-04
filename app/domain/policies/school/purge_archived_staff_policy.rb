# 🧠 DOMAINE · Policies::School::PurgeArchivedStaffPolicy
# Rôle : supprimer les comptes direction archivés depuis 30 jours : le système seul (tâche planifiée, aucun acteur)
# ADR  : 0028, 0077
module Policies
  module School
    class PurgeArchivedStaffPolicy
      def call(actor:)
        return Shared::Result.success if actor.nil?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
