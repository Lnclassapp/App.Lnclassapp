# 🧠 DOMAINE · UseCases::School::RegenerateInBulk
# Rôle : moteur des régénérations de masse : rapport pris ou repris, droit revérifié, lots de 200, « déjà changé », rejeu
# ADR  : 0039, 0056, 0057, 0096 · sous-classes : RegenerateSchoolCodes, Classroom::RegenerateClassroomLinks
module UseCases
  module School
    # Une sous-classe fournit `prepare`, `fetch(selection:, school_year:, created_before:, after_id:, limit:)`,
    # `replace(candidates, at:, unchanged_since:)` → [ids écrits] et `audit_entry(candidate)` → sujet et métadonnées.
    class RegenerateInBulk
      BATCH_SIZE = 200
      # Un code tiré déjà pris est refusé par l'index unique : un objet est rejoué cinq fois au plus, sur collision seulement ;
      # tout autre refus de la base n'est tenté qu'une fois (ADR-0057, ADR-0096 §4.3).
      ATTEMPTS = 5

      # reports : Ports::Catalog::ImportReportRepositoryPort ; users : Ports::Identity::UserRepositoryPort ;
      # audit_log : Ports::Identity::AuditLogPort ; policy : Policies::School::RegenerateCodesInBulkPolicy, revérifiée
      # pour l'auteur ; batch_size : objets par transaction, injectable pour les tests.
      def initialize(reports:, users:, audit_log:, transaction:, policy:, clock:, batch_size: BATCH_SIZE)
        @reports = reports
        @users = users
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
        @batch_size = batch_size
      end

      # → Result(ImportReport completed) | :conflict (ni à prendre ni à reprendre : déjà fini, ou inconnu ; ou plus en cours en
      # chemin : passé failed par un nouveau lancement) | :forbidden (droit retiré ou compte anonymisé : failed, avec son motif).
      # Une exception imprévue passe le rapport failed, puis remonte au job.
      def call(report_id:)
        now = @clock.now
        # Repris : Solid Queue ne relance un job qu'après un arrêt propre du processus ; un processus tué net laisse le rapport
        # importing jusqu'au prochain lancement, qui le passe failed (fail_stale). La garde « inchangé depuis le lancement » évite le double.
        unless @reports.claim(id: report_id, at: now) || @reports.resume(id: report_id, at: now)
          return Shared::Result.failure(:conflict, errors: { base: [ :already_claimed ] })
        end

        @tally = UseCases::Catalog::RunImport::Tally.new
        report = @reports.find(id: report_id)
        begin
          run(report)
        rescue StandardError
          finish(report, "failed")
          raise
        end
      end

      private

      def run(report)
        actor = @users.actor_for(user_id: report.imported_by_id)
        return forbid(report) if @policy.call(actor:).failure?
        return stopped unless @reports.advance(id: report.id, status: "importing", processed_count: 0)

        prepare
        return stopped unless regenerate(report) && finish(report, "completed")

        audit(report)
        Shared::Result.success(@reports.find(id: report.id))
      end

      # Le motif est au rapport (UDR-0105) : le droit de l'auteur a été retiré, ou son compte anonymisé, depuis le lancement.
      def forbid(report)
        @tally.note([ Entities::Catalog::ImportError.new(path: "$", code: "forbidden") ])
        finish(report, "failed")
        Shared::Result.failure(:forbidden)
      end

      # Un nouveau lancement a passé ce rapport failed (fail_stale) pendant que le job tournait encore : il s'arrête sans rien dire de plus.
      def stopped = Shared::Result.failure(:conflict, errors: { base: [ :no_longer_running ] })

      # La sélection est rejouée lot après lot, bornée au lancement : un objet créé ensuite n'en est pas (RM-14).
      # → false si le rapport n'est plus en cours (advance refusé) : le moteur s'arrête.
      def regenerate(report)
        selection = Dtos::School::SchoolSelection.from(report.details["selection"])
        school_year = report.details.dig("selection", "school_year")
        after_id = 0
        done = 0
        loop do
          batch = fetch(selection:, school_year:, created_before: report.created_at, after_id:, limit: @batch_size)
          break if batch.empty?

          write_batch(batch, report)
          after_id = batch.last.id
          return false unless @reports.advance(id: report.id, status: "importing", processed_count: done += batch.size)
        end
        true
      end

      # Changé depuis le lancement (un par un, ou avant la mort du job) : compté « déjà changé », jamais réécrit.
      def write_batch(batch, report)
        fresh, already = batch.partition { !it.changed_since?(report.created_at) }
        already.each { @tally.skip }
        return if fresh.empty?

        written = @transaction.attempt { write(fresh, report) }
        return count(fresh, written.value) if written.success?

        # Lot refusé : rejoué objet par objet.
        fresh.each { write_one(it, report) }
      end

      # Rejoué seulement sur collision (code ou jeton déjà pris, un autre sera tiré) ; toute autre cause : une seule tentative.
      def write_one(candidate, report)
        refusal = nil
        ATTEMPTS.times do
          written = @transaction.attempt_with_cause { write([ candidate ], report) }
          return count([ candidate ], written.value) if written.success?

          refusal = written
          break unless written.errors[:cause] == [ :collision ]
        end
        refuse(candidate, report, refusal.errors.fetch(:exception).first)
      end

      # L'objet est en erreur avec la classe de l'exception ; le journal nomme le rapport et l'objet, jamais un code ni un jeton.
      def refuse(candidate, report, exception)
        Rails.logger.warn("[regeneration] écriture refusée : rapport #{report.public_id}, #{candidate.label}, #{exception}")
        @tally.invalid([ Entities::Catalog::ImportError.new(path: candidate.label, code: "write_failed", params: { exception: }) ])
      end

      # Un seul UPDATE gardé, puis une ligne d'audit par objet écrit, dans la même transaction. → [ids écrits]
      def write(candidates, report)
        at = @clock.now
        ids = replace(candidates, at:, unchanged_since: report.created_at)
        entries = candidates.select { ids.include?(it.id) }.map do |candidate|
          entry = audit_entry(candidate)
          { action: "school.changed", actor_id: report.imported_by_id, at:, subject_type: "School", subject_id: entry.fetch(:subject_id),
            metadata: entry.fetch(:metadata).merge(report_public_id: report.public_id) }
        end
        @audit_log.record_many(entries:)
        ids
      end

      # Écarté par la garde de l'UPDATE (changé entre la lecture et l'écriture) : « déjà changé ».
      def count(candidates, ids)
        @tally.add({ imported: ids.size, details: {} })
        (candidates.size - ids.size).times { @tally.skip }
      end

      # Les détails restent ceux du lancement (sélection, nombre attendu) : jamais un code ni un jeton.
      def finish(report, status)
        @reports.finish(id: report.id, status:, counts: @tally.counts, details: report.details,
                        errors: @tally.errors.first(Entities::Catalog::ImportKind::MAX_ERRORS), at: @clock.now)
      end

      def audit(report)
        @audit_log.record(action: "import.run", actor_id: report.imported_by_id, at: @clock.now, subject_type: "ImportReport",
                          subject_id: report.id, metadata: { kind: report.kind, status: "completed", **@tally.counts })
      end

      def prepare = nil
    end
  end
end
