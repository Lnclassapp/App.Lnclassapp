# 🧠 DOMAINE · UseCases::Classroom::GenerateMissingClassrooms
# Rôle : donne leurs classes par défaut aux établissements sans classe de l'année, par lots, et tient le rapport
# ADR  : 0028, 0030, 0039, 0041, 0056, 0058
module UseCases
  module Classroom
    class GenerateMissingClassrooms
      BATCH_SIZE = 200
      PUBLIC_ID_LENGTH = 14
      Plan = Data.define(:school, :rows, :skipped)

      # policy : Policies::School::ManageSchoolPolicy, revérifiée pour l'auteur au démarrage (ADR-0028) ;
      # classroom_plan : le barème, lu une fois au démarrage (ADR-0058) ;
      # random : tirage des codes d'adhésion ; batch_size : établissements par transaction. Injectables pour les tests.
      def initialize(reports:, schools:, classrooms:, taxonomy:, classroom_plan:, users:, audit_log:, transaction:, policy:,
                     clock:, random: SecureRandom, batch_size: BATCH_SIZE)
        @reports = reports
        @schools = schools
        @classrooms = classrooms
        @taxonomy = taxonomy
        @classroom_plan = classroom_plan
        @users = users
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
        @random = random
        @batch_size = batch_size
      end

      # → Result(ImportReport completed) | :conflict (déjà pris par un autre job) | :forbidden (droit retiré : failed)
      # Une exception imprévue passe le rapport failed, puis remonte au job.
      def call(report_id:)
        return Shared::Result.failure(:conflict, errors: { base: [ :already_claimed ] }) unless @reports.claim(id: report_id, at: @clock.now)

        @tally = UseCases::Catalog::RunImport::Tally.new
        begin
          run(@reports.find(id: report_id))
        rescue StandardError
          finish(report_id, "failed")
          raise
        end
      end

      private

      def run(report)
        if @policy.call(actor: @users.actor_for(user_id: report.imported_by_id)).failure?
          finish(report.id, "failed")
          return Shared::Result.failure(:forbidden)
        end

        @reports.advance(id: report.id, status: "importing", processed_count: 0)
        generate(report)
        finish(report.id, "completed")
        audit(report)
        Shared::Result.success(@reports.find(id: report.id))
      end

      # Les candidats sont relus lot après lot : un établissement doté entre-temps n'en est plus un.
      def generate(report)
        at = @clock.now
        school_year = Entities::Classroom::SchoolYear.current(at.to_date)
        @lookup = @taxonomy.lookup
        @plan = @classroom_plan.plan
        @taken_codes = @classrooms.taken_join_codes
        after_id = 0
        done = 0
        loop do
          batch = @schools.without_classrooms(school_year:, after_id:, limit: @batch_size)
          break if batch.empty?

          write_batch(batch.map { plan_for(it, school_year) }, at)
          after_id = batch.last.id
          @reports.advance(id: report.id, status: "importing", processed_count: done += batch.size)
        end
      end

      def plan_for(school, school_year)
        generation = Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup: @lookup, plan: @plan)
        rows = generation.rows.map { it.merge(school_id: school.id, school_year:) }
        Plan.new(school:, rows:, skipped: generation.skipped)
      end

      # Un lot dans une transaction ; refusé, il est rejoué établissement par établissement, chacun entier ou pas du tout.
      def write_batch(plans, at)
        empty, plans = plans.partition { it.rows.empty? }
        empty.each { |plan| count(plan, :skip) }
        return if plans.empty?

        written = @transaction.attempt { insert(plans, at) }
        return plans.each { count(it, :add) } if written.success?

        plans.each { |plan| write_one(plan, at) }
      end

      def write_one(plan, at)
        return count(plan, :add) if @transaction.attempt { insert([ plan ], at) }.success?

        @tally.invalid([ Entities::Catalog::ImportError.new(path: plan.school.name, code: "write_failed", params: {}) ])
      end

      # Codes uniques en base et dans toute la génération (ADR-0041).
      def insert(plans, at)
        rows = plans.flat_map(&:rows)
        codes = Entities::Classroom::JoinCode.generate_unique(count: rows.size, taken: @taken_codes, random: @random)
        @classrooms.insert_generated(
          rows: rows.zip(codes).map { |row, join_code| row.merge(join_code:, public_id: SecureRandom.base58(PUBLIC_ID_LENGTH)) }, at:
        )
      end

      # Dotés et sans classe à générer comptent leurs niveaux et séries sautés, comme à l'import.
      def count(plan, outcome)
        skipped = { "skipped_levels" => plan.skipped[:levels].size, "skipped_series" => plan.skipped[:series].size }
        details = { "classrooms_created" => (outcome == :add ? plan.rows.size : 0), **skipped.select { |_, n| n.positive? } }
        @tally.add(imported: outcome == :add ? 1 : 0, details:)
        @tally.skip if outcome == :skip
      end

      def finish(report_id, status)
        details = { "classrooms_created" => 0 }.merge(@tally.details)
        @reports.finish(id: report_id, status:, counts: @tally.counts, details:,
                        errors: @tally.errors.first(Entities::Catalog::ImportKind::MAX_ERRORS), at: @clock.now)
      end

      def audit(report)
        @audit_log.record(action: "import.run", actor_id: report.imported_by_id, at: @clock.now, subject_type: "ImportReport",
                          subject_id: report.id, metadata: { kind: report.kind, status: "completed", **@tally.counts })
      end
    end
  end
end
