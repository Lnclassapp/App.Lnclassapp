# 🧠 DOMAINE · UseCases::School::StartCodeRegeneration
# Rôle : lance une régénération de masse (codes d'établissement ou liens des classes) : compte, confirme, rapport, job
# ADR  : 0056, 0057, 0085, 0096 · UDR : 0104 · rien n'est écrit dans schools ni classrooms ici
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
      #   { typed_count: [:mismatch] }) | :conflict (une régénération du même genre déjà en cours)
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.details.transform_values { it.pluck(:error) }) unless dto.valid?

        now = @clock.now
        kind = dto.target
        # Même limite que les imports : un rapport bloqué depuis 10 minutes ne bloque plus le genre (ADR-0039).
        @reports.fail_stale(kind:, before: now - UseCases::Catalog::StartImport::STALE_AFTER, at: now)
        school_year = (Entities::Classroom::SchoolYear.current(now.to_date) if kind == Kind::CLASSROOM_LINK_REGENERATION && dto.current_year_only)
        count = count(kind, dto.selection, school_year, now)
        refused = confirmation_error(count, dto)
        return Shared::Result.failure(:invalid, errors: refused) if refused

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
        @queue.enqueue(kind:, report_id: created.value.id) if created.success?
        created
      end
    end
  end
end
