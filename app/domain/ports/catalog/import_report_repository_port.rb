# 🧠 DOMAINE · Ports::Catalog::ImportReportRepositoryPort
# Rôle : contrat des rapports d'import, un seul import en cours par type
# ADR  : 0039, 0056, 0068, 0096, chargement-automatique-des-lecons-hors-production
module Ports
  module Catalog
    module ImportReportRepositoryPort
      # Rapport queued ; checksum_sha256 nil pour un rapport sans fichier (génération des classes, ADR-0056) ;
      # files : [Entities::Catalog::ImportFileReport] en attente, dans l'ordre d'envoi (ADR-0068) ; details : ce que le lancement
      # mémorise (sélection d'une régénération, ADR-0096), jamais un secret.
      # → Result(Entities::Catalog::ImportReport) | failure(:conflict, errors: { kind: [:already_running] })
      def create(kind:, checksum_sha256:, imported_by_id:, at:, files: [], details: {})
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Chargement automatique : un rapport rejeté d'emblée, jamais en cours (il ne bloque aucun import), avec ses erreurs
      # (Entities::Catalog::ImportError) et aucun fichier. → Entities::Catalog::ImportReport
      def record_rejection(kind:, checksum_sha256:, imported_by_id:, at:, errors:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_rejection"
      end

      # Chargement automatique : l'empreinte du dernier rapport de ce type terminé sans erreur dont le fichier s'appelle file_name
      # (un rapport refusé, échoué ou en erreur ne compte pas : la leçon sera retentée). → String | nil
      def last_loaded_checksum(kind:, file_name:)
        raise NotImplementedError, "#{self.class} doit implémenter #last_loaded_checksum"
      end

      # → Entities::Catalog::ImportReport | nil
      def find(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # → Entities::Catalog::ImportReport | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Passe failed les rapports validating ou importing sans signe de vie (updated_at, rafraîchi par claim, resume et advance)
      # depuis `before` (job tué), et les rapports queued créés avant `before` (job jamais pris). → Integer
      def fail_stale(kind:, before:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #fail_stale"
      end

      # UPDATE … SET status = 'validating' WHERE status = 'queued'. → Boolean (false : déjà pris)
      def claim(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #claim"
      end

      # ADR-0096 : reprend un rapport validating ou importing (job tué puis relancé), started_at = at. → Boolean
      def resume(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #resume"
      end

      # Progression, au plus une écriture toutes les 100 racines. Ne touche qu'un rapport encore en cours : un rapport passé failed
      # entre-temps (fail_stale) ne repart pas. → Boolean (false : le rapport n'est plus en cours, l'appelant s'arrête)
      def advance(id:, status:, processed_count:, format_version: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #advance"
      end

      # status ∈ completed, rejected, failed ; counts : { total_count:, imported_count:, skipped_count:, error_count: } ;
      # errors : [Entities::Catalog::ImportError], tronqué à ImportKind::MAX_ERRORS ;
      # files : [Entities::Catalog::ImportFileReport] traités, ou nil pour garder ceux du rapport. Comme advance, ne touche qu'un
      # rapport encore en cours. → Boolean (false : déjà terminé ou passé failed, rien n'est écrit)
      def finish(id:, status:, counts:, details:, errors:, at:, files: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #finish"
      end
    end
  end
end
