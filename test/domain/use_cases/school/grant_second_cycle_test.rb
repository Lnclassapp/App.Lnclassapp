require "test_helper"

# import-second-cycle-force: the one-off repair of the schools imported at first cycle only.
module UseCases
  module School
    class GrantSecondCycleTest < ActiveSupport::TestCase
      setup do
        @referential = seed_referential
        @drena = create_drena(name: "Abidjan 2")
      end

      def repair(batch_size: 200, classrooms: Repositories::Classroom::ClassroomRepository.new,
                 schools: Repositories::School::SchoolRepository.new)
        GrantSecondCycle.new(schools:, classrooms:,
                             taxonomy: Repositories::Catalog::TaxonomyRepository.new,
                             classroom_plan: Repositories::Classroom::ClassroomPlanRepository.new,
                             transaction: Repositories::Shared::Transaction.new, clock: Time.zone, batch_size:).call.value
      end

      def second_cycle_count(school) = school.classrooms.joins(:level).where(levels: { cycle: "second" }).count

      test "a first-cycle school gets both cycles and its second-cycle classes, the first cycle kept as it is" do
        school = create_school(drena: @drena, name: "Collège Moderne", cycle: "first")
        create_classroom(school:, level: @referential[:levels]["6eme"], name: "6ème 1")

        summary = repair

        assert_equal [ 1, 49, [] ], [ summary.schools, summary.classrooms, summary.failed ]
        assert_equal "both", school.reload.cycle
        assert_equal 49, second_cycle_count(school)
        assert_equal 1, school.classrooms.joins(:level).where(levels: { cycle: "first" }).count
      end

      test "private schools follow the private barème, and an inactive school is left alone" do
        private_school = create_school(drena: @drena, name: "Collège privé", school_type: "private", cycle: "first")
        inactive = create_school(drena: @drena, name: "Collège fermé", cycle: "first", status: "inactive")

        repair

        assert_equal 26, second_cycle_count(private_school)
        assert_equal "first", inactive.reload.cycle
        assert_equal 0, inactive.classrooms.count
      end

      test "it can be replayed, in small batches, and touches neither both-cycle schools nor existing names" do
        lycee = create_school(drena: @drena, name: "Lycée", cycle: "both")
        schools = 3.times.map { create_school(drena: @drena, cycle: "first") }
        create_classroom(school: schools.first, level: @referential[:levels]["2nde"], series: @referential[:series]["a"],
                         name: "2nde A 1")

        first_run = repair(batch_size: 2)
        replay = repair

        assert_equal 3, first_run.schools
        assert_equal [ 0, 0 ], [ replay.schools, replay.classrooms ]
        assert_equal 0, lycee.classrooms.count
        assert_equal 1, schools.first.classrooms.where(name: "2nde A 1").count
      end

      # The base refuses the classrooms of one school, every time.
      class FragileClassrooms < Repositories::Classroom::ClassroomRepository
        def insert_generated(rows:, at:)
          raise ActiveRecord::RecordNotUnique, "refus simulé" if Orm::School.exists?(id: rows.pluck(:school_id), name: "Collège Fragile")

          super
        end
      end

      test "a school the base refuses stays at first cycle with no class, and the others are repaired" do
        fragile = create_school(drena: @drena, name: "Collège Fragile", cycle: "first")
        solid = create_school(drena: @drena, name: "Collège Solide", cycle: "first")

        summary = repair(classrooms: FragileClassrooms.new)

        assert_equal [ 1, 49, [ fragile.public_id ] ], [ summary.schools, summary.classrooms, summary.failed ]
        assert_equal [ "first", 0 ], [ fragile.reload.cycle, fragile.classrooms.count ]
        assert_equal "both", solid.reload.cycle
      end

      # The school itself is refused (name taken): nothing is written for it.
      class RefusingSchools < Repositories::School::SchoolRepository
        def update(school:) = Shared::Result.failure(:conflict)
      end

      test "a school that cannot be saved is reported and gets no class" do
        school = create_school(drena: @drena, cycle: "first")

        summary = repair(schools: RefusingSchools.new)

        assert_equal [ 0, [ school.public_id ], 0 ], [ summary.schools, summary.failed, school.classrooms.count ]
      end
    end
  end
end
