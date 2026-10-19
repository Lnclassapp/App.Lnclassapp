require "test_helper"

module UseCases
  module School
    # ME-08, ME-11 (ADR-0094 §4.4): the session moves to one of the teacher's schools; nothing else is written.
    class SwitchCurrentSchoolTest < ActiveSupport::TestCase
      A = Entities::School::School.new(id: 31, public_id: "sa", name: "Lycée moderne d'Abobo", status: "active")
      B = Entities::School::School.new(id: 32, public_id: "sb", name: "Collège Saint-Michel", status: "active")
      C = Entities::School::School.new(id: 33, public_id: "sc", name: "Collège Notre-Dame", status: "active")

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(attached) = @attached = attached
        def find_by_public_id(public_id:) = [ A, B, C ].find { it.public_id == public_id }
        def school_ids_for(teacher_id:) = @attached.fetch(teacher_id, [])
      end

      class FakeSessions
        include Ports::Identity::SessionRepositoryPort

        attr_reader :writes

        # revoked : ids de sessions supprimées entre la lecture et l'écriture (déconnexion sur un autre appareil).
        def initialize(revoked: []) = (@writes = []) && (@revoked = revoked)

        def set_current_school(id:, school_id:)
          return 0 if @revoked.include?(id)

          @writes << [ id, school_id ]
          1
        end
      end

      setup do
        @sessions = FakeSessions.new
        @use_case = SwitchCurrentSchool.new(schools: FakeSchools.new({ 7 => [ 31, 32 ] }), sessions: @sessions,
                                            policy: Policies::School::SwitchCurrentSchoolPolicy.new)
      end

      def teacher(school_id: 31) = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id:)

      test "a teacher of A and B switches their session to B and gets B back" do
        result = @use_case.call(actor: teacher, session_id: 5, school_public_id: "sb")

        assert_equal B, result.value
        assert_equal [ [ 5, 32 ] ], @sessions.writes
      end

      # Revue de la PR #250, constat 4 : aucune ligne écrite, aucun succès annoncé.
      test "a session revoked meanwhile is not found: no « switched to B » for a session that no longer exists" do
        use_case = SwitchCurrentSchool.new(schools: FakeSchools.new({ 7 => [ 31, 32 ] }), sessions: FakeSessions.new(revoked: [ 5 ]),
                                           policy: Policies::School::SwitchCurrentSchoolPolicy.new)

        assert_equal :not_found, use_case.call(actor: teacher, session_id: 5, school_public_id: "sb").code
      end

      test "a school the teacher is not attached to is refused, and the session is not written" do
        assert_equal :forbidden, @use_case.call(actor: teacher, session_id: 5, school_public_id: "sc").code
        assert_empty @sessions.writes
      end

      test "an unknown school is not found, and the session is not written" do
        assert_equal :not_found, @use_case.call(actor: teacher, session_id: 5, school_public_id: "zz").code
        assert_equal :not_found, @use_case.call(actor: teacher, session_id: 5, school_public_id: nil).code
        assert_empty @sessions.writes
      end

      test "a student or a visitor is refused before anything is read" do
        assert_equal :forbidden, @use_case.call(actor: Entities::Identity::Actor.new(user_id: 8, role: :student), session_id: 5,
                                                school_public_id: "sa").code
        assert_equal :forbidden, @use_case.call(actor: nil, session_id: 5, school_public_id: "sa").code
        assert_empty @sessions.writes
      end
    end
  end
end
