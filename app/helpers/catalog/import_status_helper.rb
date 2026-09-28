# 🌐 UI · Catalog::ImportStatusHelper — libellé du statut d'un rapport d'import, badge de la liste, du rapport et de l'accueil
# Rôle : libellé propre au type (génération des classes : « Génération en cours »), sinon celui des imports
# ADR  : 0039, 0056 · UDR : 0043
module Catalog
  module ImportStatusHelper
    def import_status_label(import)
      t("teams.imports.status.by_kind.#{import.kind}.statuses.#{import.status}",
        default: t("teams.imports.statuses.#{import.status}"))
    end
  end
end
