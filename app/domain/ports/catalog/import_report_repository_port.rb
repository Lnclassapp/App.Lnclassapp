# 🧠 DOMAINE · Ports::Catalog::ImportReportRepositoryPort
# Rôle : contrat des rapports d'import, un seul import en cours par type
# ADR  : 0039, 0056, 0068
module Ports
  module Catalog
    module ImportReportRepositoryPort
      # Rapport queued ; checksum_sha256 nil pour un rapport sans fichier (génération des classes, ADR-0056) ;
      # files : [Entities::Catalog::ImportFileReport] en attente, dans l'ordre d'envoi (ADR-0068).
      # → Result(Entities::Catalog::ImportReport) | failure(:conflict, errors: { kind: [:already_running] })
      def create(kind:, checksum_sha256:, imported_by_id:, at:, files: [])
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Entities::Catalog::ImportReport | nil
      def find(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # → Entities::Catalog::ImportReport | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Passe failed les rapports validating ou importing commencés avant `before` (job tué), et les rapports queued créés
      # avant `before` (job jamais pris). → Integer
      def fail_stale(kind:, before:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #fail_stale"
      end

      # UPDATE … SET status = 'validating' WHERE status = 'queued'. → Boolean (false : déjà pris)
      def claim(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #claim"
      end

      # Progression, au plus une écriture toutes les 100 racines. → true
      def advance(id:, status:, processed_count:, format_version: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #advance"
      end

      # status ∈ completed, rejected, failed ; counts : { total_count:, imported_count:, skipped_count:, error_count: } ;
      # errors : [Entities::Catalog::ImportError], tronqué à ImportKind::MAX_ERRORS ;
      # files : [Entities::Catalog::ImportFileReport] traités, ou nil pour garder ceux du rapport. → true
      def finish(id:, status:, counts:, details:, errors:, at:, files: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #finish"
      end
    end
  end
end
