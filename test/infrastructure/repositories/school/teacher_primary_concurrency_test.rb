require "test_helper"

# Revue de la PR #250, constat 1 (ADR-0094 §4.5) : le drapeau « principal » se décide sous le verrou du compte, jamais
# avant. Deux « Rejoindre » simultanés d'un enseignant sans établissement, ou une réintégration et un « Rejoindre », ne
# lèvent pas et laissent exactement un établissement principal. Hors transaction de test : chaque thread la sienne.
class TeacherPrimaryConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # La policy passe pour les deux, puis attend : les deux gestes ont lu « aucun établissement » avant d'écrire.
  class SlowJoinPolicy < Policies::School::JoinSchoolWithCodePolicy
    def call(**)
      super.tap { sleep 0.3 }
    end
  end

  class SlowReinstatePolicy < Policies::School::ManageSchoolTeachersPolicy
    def call(**)
      super.tap { sleep 0.3 }
    end
  end

  setup do
    @drena = create_drena
    @a, @b = Array.new(2) { create_school(drena: @drena) }
    @teacher = create_teacher(school: nil)
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
    Orm::School.where(id: [ @a.id, @b.id ]).delete_all
    @drena.delete
  end

  def join(school)
    actor = Repositories::Identity::UserRepository.new.actor_for(user_id: @teacher.id)
    UseCases::School::JoinSchoolWithCode.new(
      schools: Repositories::School::SchoolRepository.new, drenas: Repositories::School::DrenaRepository.new,
      departures: Repositories::School::TeacherDepartureRepository.new, join_requests: Repositories::School::JoinRequestRepository.new,
      invite_links: Repositories::Identity::InviteLinkRepository.new, sessions: Repositories::Identity::SessionRepository.new,
      audit_log: Repositories::Identity::AuditLogRepository.new, policy: SlowJoinPolicy.new,
      transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(actor:, dto: Dtos::School::SchoolJoinInput.new(drena_public_id: @drena.public_id, school_public_id: school.public_id))
  end

  def reinstate
    actor = Entities::Identity::Actor.new(user_id: @admin.id, role: :school_admin, school_id: @a.id, staff_position: "head")
    UseCases::School::ReinstateTeacher.new(
      users: Repositories::Identity::UserRepository.new, schools: Repositories::School::SchoolRepository.new,
      departures: Repositories::School::TeacherDepartureRepository.new, audit_log: Repositories::Identity::AuditLogRepository.new,
      policy: SlowReinstatePolicy.new, transaction: Repositories::Shared::Transaction.new, clock: Time.zone
    ).call(actor:, school_id: @a.id, teacher_public_id: @teacher.public_id)
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

  test "two simultaneous joins of a teacher without a school: no error, and exactly one primary school" do
    results = simultaneously(-> { join(@a) }, -> { join(@b) })

    assert results.all? { it.success? || it.code == :conflict }, results.inspect
    assert results.any?(&:success?)
    assert_equal results.count(&:success?), rows.size
    assert_equal 1, rows.count(&:last)
  end

  test "a reinstatement and a join at the same time: no error, and exactly one primary school" do
    @admin = create_school_admin(school: @a)
    create_teacher_departure(teacher: @teacher, school: @a, detached_by: @admin)

    results = simultaneously(-> { reinstate }, -> { join(@b) })

    assert results.all?(&:success?), results.inspect
    assert_equal [ @a.id, @b.id ], rows.map(&:first).sort
    assert_equal 1, rows.count(&:last)
  end
end
