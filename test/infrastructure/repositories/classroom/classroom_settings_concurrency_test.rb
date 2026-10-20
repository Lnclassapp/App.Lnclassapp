require "test_helper"

# ADR-0098 : une arrivée d'élève et une baisse du plafond sur la même classe passent l'une après l'autre, sous le verrou de
# la classe (ADR-0041) ; la classe ne compte jamais plus d'élèves que son plafond. Hors transaction de test : chaque fil a la sienne.
class ClassroomSettingsConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  PAUSE = 0.3

  setup do
    @school = create_school
    @level = create_level
    @classroom = create_classroom(school: @school, level: @level, name: "6ème 3", max_students: 3)
    @present = Array.new(2) { create_student(classroom: @classroom) }
    @newcomer = create_user(role: "student")
  end

  teardown do
    Orm::ClassroomStudent.where(classroom_id: @classroom.id).delete_all
    Orm::User.where(id: @present.map(&:id) << @newcomer.id).delete_all
    @classroom.delete
    @level.delete
    drena = @school.drena_id
    @school.delete
    Orm::Drena.where(id: drena).delete_all
  end

  # Le verrou de la classe est pris par ClassroomDesignation ; `hold` fait attendre l'élève une fois la classe verrouillée.
  class HoldingClassrooms < Repositories::Classroom::ClassroomRepository
    def initialize(hold)
      super()
      @hold = hold
    end

    def lock_by_public_id(public_id:) = super.tap { @hold&.call }
  end

  # Le vrai parcours d'adhésion : JoinAsStudent, qui désigne la classe par ClassroomDesignation, sous verrou.
  def join(hold: nil)
    ActiveRecord::Base.connection_pool.with_connection do
      result = UseCases::Classroom::JoinAsStudent.new(
        classrooms: HoldingClassrooms.new(hold), schools: Repositories::School::SchoolRepository.new,
        taxonomy: Repositories::Catalog::TaxonomyRepository.new, memberships: Repositories::Classroom::MembershipRepository.new,
        policy: Policies::Classroom::JoinPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
      ).call(actor: Entities::Identity::Actor.new(user_id: @newcomer.id, role: :student),
             dto: Dtos::Classroom::StudentRegistrationInput.new(school_public_id: @school.public_id, level_slug: @level.slug,
                                                                classroom_public_id: @classroom.public_id))
      next :joined if result.success?

      result.errors[:base] == [ :classroom_full ] ? :full : result
    end
  end

  def lower_cap(hold: nil)
    ActiveRecord::Base.connection_pool.with_connection do
      Orm::Classroom.transaction do
        Repositories::Classroom::ClassroomRepository.new.update_settings(id: @classroom.id, name: "6ème 3", max_students: 2)
                                                    .tap { hold&.call }
      end
    end
  end

  def present_count = Orm::ClassroomStudent.where(classroom_id: @classroom.id, left_at: nil).count

  test "l'élève entre le premier : le plafond sous le nouvel effectif est refusé" do
    locked = Queue.new
    student = Thread.new { join(hold: -> { locked << true && sleep(PAUSE) }) }
    locked.pop
    cap = Thread.new { lower_cap }

    assert_equal :joined, student.value
    assert_equal({ max_students: [ :below_headcount ], headcount: 3 }, cap.value.errors)
    assert_equal [ 3, 3 ], [ present_count, @classroom.reload.max_students ]
  end

  test "le plafond passe le premier : l'élève trouve la classe complète" do
    locked = Queue.new
    cap = Thread.new { lower_cap(hold: -> { locked << true && sleep(PAUSE) }) }
    locked.pop
    student = Thread.new { join }

    assert cap.value.success?
    assert_equal :full, student.value
    assert_equal [ 2, 2 ], [ present_count, @classroom.reload.max_students ]
  end
end
