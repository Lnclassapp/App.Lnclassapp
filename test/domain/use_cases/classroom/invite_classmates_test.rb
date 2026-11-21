require "test_helper"

module UseCases
  module Classroom
    # Lot B (partage-classe-k-factor): the student shares the classroom link with his own invite code; no database here.
    class InviteClassmatesTest < ActiveSupport::TestCase
      Target = Data.define(:name, :school_name, :link_token)

      class FakeCodes
        include Ports::Classroom::InviteCodeRepositoryPort
        attr_reader :asked

        def initialize(result = Shared::Result.success("k7m4q2zp")) = @result = result

        def code_for(student_id:)
          (@asked ||= []) << student_id
          @result
        end
      end

      def student = Entities::Identity::Actor.new(user_id: 7, role: :student)
      def target = Target.new(name: "3e B", school_name: "Collège Moderne", link_token: "abc123def456")
      def use_case(codes) = InviteClassmates.new(invite_codes: codes, policy: Policies::Classroom::InviteClassmatesPolicy.new)

      test "an active classroom gives the invitation with the student's code" do
        codes = FakeCodes.new
        result = use_case(codes).call(actor: student, classroom: target)

        assert_predicate result, :success?
        assert_equal %w[3e\ B Collège\ Moderne abc123def456 k7m4q2zp],
                     result.value.then { [ it.classroom_name, it.school_name, it.link_token, it.code ] }
        assert_equal [ 7 ], codes.asked
      end

      test "no active classroom: no code is created" do
        codes = FakeCodes.new
        result = use_case(codes).call(actor: student, classroom: nil)

        assert_equal :not_found, result.code
        assert_nil codes.asked
      end

      test "another role is refused before anything is written" do
        codes = FakeCodes.new
        %i[teacher school_admin team].each do |role|
          result = use_case(codes).call(actor: Entities::Identity::Actor.new(user_id: 1, role:), classroom: target)

          assert_equal :forbidden, result.code
        end
        assert_nil codes.asked
      end

      test "a code that cannot be made fails the invitation" do
        result = use_case(FakeCodes.new(Shared::Result.failure(:unavailable))).call(actor: student, classroom: target)

        assert_equal :unavailable, result.code
      end
    end
  end
end
