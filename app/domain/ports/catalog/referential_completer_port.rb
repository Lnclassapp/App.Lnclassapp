# 🧠 DOMAINE · Ports::Catalog::ReferentialCompleterPort
# Rôle : contrat du complément du référentiel de Develop (crée ce qui manque du référentiel, du barème et des DRENA, ne touche à rien d'existant)
# ADR  : 0123
module Ports
  module Catalog
    module ReferentialCompleterPort
      # Crée, s'ils manquent (par slug), les niveaux, séries, couples niveau/série et matières (PROGRAMME_MATERIALS, EDHC comprise)
      # d'Entities::Catalog::BaseReferential, les entrées absentes du barème des classes (ADR-0058) et les 41 DRENA ; ne modifie ni ne
      # supprime aucun enregistrement. Une valeur unique déjà prise par un autre enregistrement n'est pas créée.
      # → { levels:, series:, pairs:, materials:, plan_entries:, drenas:, conflicts: } : ce qui a été créé (noms ; ids pour le barème), et
      # ce qui ne l'a pas été (« niveau 1ère », « matière SVT »…)
      def complete
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end
    end
  end
end
