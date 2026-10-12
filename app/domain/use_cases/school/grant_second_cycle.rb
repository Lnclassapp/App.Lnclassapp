# 🧠 DOMAINE · UseCases::School::GrantSecondCycle
# Rôle : réparation unique : passe les établissements au premier cycle seul en « both » et leur génère le second cycle manquant
# ADR  : 0030, 0056, 0058
module UseCases
  module School
    class GrantSecondCycle
      BATCH_SIZE = 200
      PUBLIC_ID_LENGTH = 14
      Summary = Data.define(:schools, :classrooms, :failed)

      def initialize(schools:, classrooms:, taxonomy:, classroom_plan:, transaction:, clock:, batch_size: BATCH_SIZE)
        @schools = schools
        @classrooms = classrooms
        @taxonomy = taxonomy
        @classroom_plan = classroom_plan
        @transaction = transaction
        @clock = clock
        @batch_size = batch_size
      end

      # Chaque établissement est entier ou pas du tout : un refus de la base le met dans failed (ses public_id), les autres continuent.
      # Seules les classes du second cycle sont ajoutées : une classe du premier cycle retirée à la main n'est pas recréée.
      # Rejouable : un établissement réparé n'est plus au premier cycle. → Result(Summary)
      def call
        at = @clock.now
        @school_year = Entities::Classroom::SchoolYear.current(at.to_date)
        @lookup = @taxonomy.lookup
        @plan = @classroom_plan.plan
        @second_cycle_ids = @lookup.levels.reject(&:first_cycle?).to_set(&:id)
        repaired = created = 0
        failed = []
        after_id = 0
        loop do
          batch = @schools.first_cycle_after(after_id:, limit: @batch_size)
          break if batch.empty?

          batch.each do |school|
            outcome = @transaction.attempt { grant(school, at) }
            outcome.success? && outcome.value ? (repaired += 1) && (created += outcome.value) : failed << school.public_id
          end
          after_id = batch.last.id
        end
        Shared::Result.success(Summary.new(schools: repaired, classrooms: created, failed:))
      end

      private

      # → Integer (classes créées) | nil (école non enregistrée : rien n'a été écrit)
      def grant(school, at)
        school.cycle = "both"
        return if @schools.update(school:).failure?

        taken = @classrooms.names_in(school_id: school.id, school_year: @school_year)
        rows = Entities::Classroom::DefaultClassroomPlan.rows_for(school:, lookup: @lookup, plan: @plan).rows
        rows = rows.select { @second_cycle_ids.include?(it[:level_id]) && taken.exclude?(it[:name]) }
                   .map { it.merge(school_id: school.id, school_year: @school_year, public_id: SecureRandom.base58(PUBLIC_ID_LENGTH)) }
        @classrooms.insert_generated(rows:, at:)
      end
    end
  end
end
