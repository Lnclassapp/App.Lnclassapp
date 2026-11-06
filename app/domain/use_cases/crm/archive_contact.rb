# 🧠 DOMAINE · UseCases::Crm::ArchiveContact
# Rôle : retire un contact en l'archivant (jamais de suppression : les échanges qui le citent gardent son nom) ; sans effet s'il l'est déjà
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class ArchiveContact
      def initialize(contacts:, policy:, clock:)
        @contacts = contacts
        @policy = policy
        @clock = clock
      end

      # → Result(Contact) | :forbidden | :not_found
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        @contacts.archive(public_id:, at: @clock.now)
      end
    end
  end
end
