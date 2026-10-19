require "test_helper"

# Revue de la PR #250, constat 2 (ADR-0094 §4.4, §4.5) : quitter compte ses établissements sous le verrou du compte. Deux
# « Quitter » simultanés (deux appareils), ou un « Quitter » et un retrait par la direction, ne laissent jamais l'enseignant
# sans établissement ni sans principal. Hors transaction de test : chaque thread la sienne.
class TeacherLeaveConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # La policy passe pour les deux, puis attend : les deux gestes ont lu « deux établissements » avant d'écrire.
  class SlowLeavePolicy < Policies::School::LeaveSchoolPolicy
    def call(**)
      super.tap { sleep 0.3 }
    end
  end

  class SlowDetachPolicy < Policies::School::ManageSchoolTeachersPolicy
    def call(**)
      super.tap { sleep 0.3 }
    end
  end

  setup do
    @drena = create_drena
    @a, @b = Array.new(2) { create_school(drena: @drena) }
    @teacher = create_teacher(school: @a)
    add_teacher_school(@teacher, @b, at: 1.day.from_now)
  end

  teardown do
    users = [ @teacher.id, @admin&.id ].compact
    Orm::AuditEvent.where(actor_id: users).delete_all
    Orm::TeacherSchoolDeparture.where(teacher_id: @teacher.id).delete_all
    Orm::SchoolStaff.where(user_id: users).delete_all
    Orm::TeacherSchool.where(teacher_id: @teacher.id).delete_all
    profiles = Orm::TeacherProfile.where(user_id: @teacher.id)
    materials = profiles.pluck(:material_id)
    profiles.delete_all
    Orm::User.where(id: users).delete_all
    Orm::Material.where(id: materials).delete_all
    Orm::School.where(id: [ @a.id, @b.id, @c&.id ].compact).delete_all
    @drena.delete
  end

  def leave(school)
    UseCases::School::LeaveSchool.new(
      schools: Repositories::School::SchoolRepository.new, teachings: Repositories::Classroom::TeachingRepository.new,
      assignments: Repositories::Classroom::AssignmentRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      policy: SlowLeavePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(actor: Repositories::Identity::UserRepository.new.actor_for(user_id: @teacher.id), school_public_id: school.public_id)
  end

  def detach(school)
    actor = Entities::Identity::Actor.new(user_id: @admin.id, role: :school_admin, school_id: school.id)
    UseCases::School::DetachTeacher.new(
      schools: Repositories::School::SchoolRepository.new, users: Repositories::Identity::UserRepository.new,
      teachings: Repositories::Classroom::TeachingRepository.new, assignments: Repositories::Classroom::AssignmentRepository.new,
      departures: Repositories::School::TeacherDepartureRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      policy: SlowDetachPolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(actor:, school_id: school.id, teacher_public_id: @teacher.public_id)
  end

  def simultaneously(*gestures)
    gate = Queue.new
    threads = gestures.map do |gesture|
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { gesture.call }
      end
    end
    gestures.size.times { gate << true }
    threads.map(&:value)
  end

  def rows = Orm::TeacherSchool.where(teacher_id: @teacher.id).pluck(:school_id, :primary)

  test "two simultaneous leaves of a teacher of two schools: one passes, the other is refused, one primary school stays" do
    results = simultaneously(-> { leave(@a) }, -> { leave(@b) })

    assert_equal 1, results.count(&:success?), results.inspect
    refused = results.find(&:failure?)
    assert_equal [ :forbidden, { base: [ :last_school ] } ], [ refused.code, refused.errors ]
    assert_equal 1, rows.size
    assert rows.first.last, "le dernier établissement est principal"
  end

  # Trois établissements : il quitte B pendant que la direction de A, son principal, le retire. Les deux passent, dans un
  # ordre ou dans l'autre ; C, le seul qui reste, est principal.
  test "a leave of B while the direction of his primary school A withdraws him: the school left is primary" do
    @c = create_school(drena: @drena)
    add_teacher_school(@teacher, @c, at: 2.days.from_now)
    @admin = create_school_admin(school: @a)

    results = simultaneously(-> { leave(@b) }, -> { detach(@a) })

    assert results.all?(&:success?), results.inspect
    assert_equal [ [ @c.id, true ] ], rows
  end

  # Le plus ancien restant est lu, puis disparaît (un autre départ validé entre-temps) : rien n'est promu, nil le dit.
  test "promote_primary gives nil when the oldest remaining row disappears before it is marked" do
    Orm::TeacherSchool.where(teacher_id: @teacher.id, school_id: @a.id).delete_all
    deleted = Queue.new
    other = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Orm::TeacherSchool.transaction do
          Orm::TeacherSchool.where(teacher_id: @teacher.id, school_id: @b.id).delete_all
          deleted << true
          sleep 0.3
        end
      end
    end
    deleted.pop

    assert_nil Repositories::School::SchoolRepository.new.promote_primary(teacher_id: @teacher.id)
    other.join
    assert_empty rows
  end
end
