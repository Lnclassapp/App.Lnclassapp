# 🧠 DOMAINE · Ports::Catalog::ReferentialCompleterPort
# Rôle : contrat du complément du référentiel de Develop (crée ce qui manque du référentiel de base, ne touche à rien d'existant)
# ADR  : 0123
module Ports
  module Catalog
    module ReferentialCompleterPort
      # Crée, s'ils manquent (par slug), les niveaux, séries, couples niveau/série et matières d'Entities::Catalog::BaseReferential ;
      # ne modifie ni ne supprime aucun enregistrement. Un nom ou un nom court déjà pris par un autre enregistrement n'est pas créé.
      # → { levels:, series:, pairs:, materials:, conflicts: } : les noms créés, et ceux non créés (« niveau 1ère », « matière SVT »…)
      def complete
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end
    end
  end
end
