# 🧠 DOMAINE · Ports::Billing::RelayPointRepositoryPort
# Rôle : contrat des points relais et de leurs écoles
# ADR  : 0126 (contexte billing, §4.1)
module Ports
  module Billing
    module RelayPointRepositoryPort
      # → [Entities::Billing::RelayPoint], triés par nom
      def list
        raise NotImplementedError, "#{self.class} doit implémenter #list"
      end

      # → Entities::Billing::RelayPoint | nil
      def find(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Crée (sans id) ou met à jour (avec id) le point relais et remplace ses écoles. → Result(RelayPoint)
      def save(relay_point:, school_ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #save"
      end

      # Points relais actifs qui desservent l'école. → [Entities::Billing::RelayPoint]
      def for_school(school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #for_school"
      end
    end
  end
end
