# 🧠 DOMAINE · UseCases::Classroom::StartClassroomGeneration
# Rôle : lance la génération des classes manquantes : rapport queued sans fichier, job mis en file ; rien n'est écrit ici
# ADR  : 0028, 0039, 0056
module UseCases
  module Classroom
    class StartClassroomGeneration
      KIND = Entities::Catalog::ImportKind::CLASSROOM_GENERATION

      # reports : Ports::Catalog::ImportReportRepositoryPort ; queue : Ports::Catalog::ImportQueuePort ;
      # policy : Policies::School::ManageSchoolPolicy, celle de l'import d'établissements (ADR-0028).
      def initialize(reports:, queue:, policy:, clock:)
        @reports = reports
        @queue = queue
        @policy = policy
        @clock = clock
      end

      # → Result(ImportReport) | :forbidden | :conflict (une génération déjà en cours)
      def call(actor:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        now = @clock.now
        # Même limite que les imports : un rapport bloqué depuis 10 minutes ne bloque plus le type (ADR-0039).
        @reports.fail_stale(kind: KIND, before: now - UseCases::Catalog::StartImport::STALE_AFTER, at: now)
        created = @reports.create(kind: KIND, checksum_sha256: nil, imported_by_id: actor.user_id, at: now)
        @queue.enqueue(kind: KIND, report_id: created.value.id) if created.success?
        created
      end
    end
  end
end
