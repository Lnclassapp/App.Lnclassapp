# 🧠 DOMAINE · UseCases::School::StartCodeRegeneration
# Rôle : lance une régénération de masse (codes d'établissement ou liens des classes) : compte, confirme, rapport, job
# ADR  : 0056, 0057, 0085, 0096 · UDR : 0104, 0105 · rien n'est écrit dans schools ni classrooms ici
module UseCases
  module School
    class StartCodeRegeneration
      Kind = Entities::Catalog::ImportKind

      # reports : Ports::Catalog::ImportReportRepositoryPort ; queue : Ports::Catalog::ImportQueuePort ;
      # schools : Ports::School::SchoolRepositoryPort ; classrooms : Ports::Classroom::ClassroomRepositoryPort ;
      # policy : Policies::School::RegenerateCodesInBulkPolicy (équipe admin).
      def initialize(reports:, queue:, schools:, classrooms:, policy:, clock:)
        @reports = reports
        @queue = queue
        @schools = schools
        @classrooms = classrooms
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::School::CodeRegenerationInput.
      # → Result(ImportReport) | :forbidden | :invalid ({ target: [:inclusion] }, { base: [:empty] },
      #   { typed_count: [:mismatch] }) | :conflict (une régénération du même genre déjà en cours) | :unavailable (la file a
      #   refusé le job : le rapport est passé failed, rien n'a été changé)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.details.transform_values { it.pluck(:error) }) unless dto.valid?

        now = @clock.now
        kind = dto.target
        school_year = (Entities::Classroom::SchoolYear.current(now.to_date) if kind == Kind::CLASSROOM_LINK_REGENERATION && dto.current_year_only)
        count = count(kind, dto.selection, school_year, now)
        refused = confirmation_error(count, dto)
        return Shared::Result.failure(:invalid, errors: refused) if refused

        # Après la validation : un nombre refusé ne touche aucun rapport. Même limite que les imports : un rapport sans signe de
        # vie depuis 10 minutes ne bloque plus le genre (ADR-0039).
        @reports.fail_stale(kind:, before: now - UseCases::Catalog::StartImport::STALE_AFTER, at: now)
        launch(actor, kind, now, { "selection" => dto.selection.to_h.merge("school_year" => school_year), "expected_count" => count })
      end

      private

      # La sélection est recomptée ici, au lancement : c'est ce nombre que l'équipe confirme (UDR-0104).
      def count(kind, selection, school_year, now)
        if kind == Kind::SCHOOL_CODE_REGENERATION
          @schools.count_for_code_regeneration(selection:, created_before: now)
        else
          @classrooms.count_for_link_regeneration(selection:, school_year:, created_before: now)
        end
      end

      # Une seule DRENA ou un seul établissement : la portée se lit dans la modale. Ailleurs, le nombre tapé doit être le bon.
      def confirmation_error(count, dto)
        return { base: [ :empty ] } if count.zero?

        { typed_count: [ :mismatch ] } unless dto.selection.scoped? || dto.typed_count == count
      end

      # Le rapport garde la sélection et le nombre attendu, jamais un code ni un jeton (ADR-0096 §2).
      def launch(actor, kind, now, details)
        created = @reports.create(kind:, checksum_sha256: nil, imported_by_id: actor.user_id, at: now, details:)
        return created if created.failure? || @queue.enqueue(kind:, report_id: created.value.id)

        unqueued(created.value, details, now)
      end

      # La file a refusé le job : sans lui le rapport resterait en file, et le genre bloqué, jusqu'à la limite.
      def unqueued(report, details, now)
        @reports.finish(id: report.id, status: "failed", counts: { total_count: 0, imported_count: 0, skipped_count: 0, error_count: 0 },
                        details:, errors: [ Entities::Catalog::ImportError.new(path: "$", code: "not_enqueued") ], at: now)
        Shared::Result.failure(:unavailable)
      end
    end
  end
end
