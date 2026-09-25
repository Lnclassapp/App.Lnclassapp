# 🧠 DOMAINE · Ports::School::DrenaRepositoryPort
# Rôle : contrat des DRENA, créées à l'écran (aucun import de DRENA)
# ADR  : 0034, 0036
module Ports
  module School
    module DrenaRepositoryPort
      # → [Entities::School::Drena], triées par nom
      def all
        raise NotImplementedError, "#{self.class} doit implémenter #all"
      end

      # → Entities::School::Drena | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # → Result(Drena) | failure(:conflict, errors: { name: [:taken] })
      def create(name:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Le slug reste figé. → Result(Drena) | failure(:conflict, errors: { name: [:taken] })
      def update(id:, name:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # → Result | failure(:conflict, errors: { base: [:has_schools] })
      def delete(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete"
      end

      # Résolution des imports d'écoles. → { "abidjan-1" => 12, … } (clé = slug)
      def ids_by_slug
        raise NotImplementedError, "#{self.class} doit implémenter #ids_by_slug"
      end
    end
  end
end
