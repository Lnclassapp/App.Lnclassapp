require "test_helper"

module UseCases
  module Identity
    # CP-04, CP-07 (ADR-0063): a click on « Partager » is recorded with its channel, for a teacher of an active school.
    class RecordReferralShareTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 28, 10)
      Clock = Data.define(:now)

      class FakeReferrals
        include Ports::Identity::ReferralRepositoryPort

        attr_reader :shares

        def initialize = @shares = []

        def record_share(user_id:, channel:, at:)
          @shares << [ user_id, channel, at ]
          Shared::Result.success
        end
      end

      class FakeSchools
        include Ports::School::SchoolRepositoryPort

        def initialize(*schools) = @schools = schools
        def find_by_id(id:) = @schools.find { it.id == id }
      end

      setup do
        @referrals = FakeReferrals.new
        @schools = FakeSchools.new(Entities::School::School.new(id: 31, status: "active"),
                                   Entities::School::School.new(id: 32, status: "draft"))
      end

      def record(actor:, channel: "whatsapp")
        RecordReferralShare.new(referrals: @referrals, schools: @schools, policy: Policies::Identity::InviteColleaguePolicy.new,
                                clock: Clock.new(NOW)).call(actor:, channel:)
      end

      def teacher(school_id: 31) = Entities::Identity::Actor.new(user_id: 7, role: :teacher, school_id:)

      test "records the share of a teacher of an active school, with its channel" do
        %w[whatsapp sms copy native].each { assert record(actor: teacher, channel: it).success? }

        assert_equal [ [ 7, "whatsapp", NOW ], [ 7, "sms", NOW ], [ 7, "copy", NOW ], [ 7, "native", NOW ] ], @referrals.shares
      end

      test "an unknown channel is invalid, nothing is recorded" do
        result = record(actor: teacher, channel: "email")

        assert_equal [ :invalid, { channel: [ :inclusion ] } ], [ result.code, result.errors ]
        assert_empty @referrals.shares
      end

      test "a teacher of a draft school, without school, a student or a visitor: forbidden, nothing is recorded" do
        [ teacher(school_id: 32), teacher(school_id: nil), Entities::Identity::Actor.new(user_id: 8, role: :student), nil ].each do |actor|
          assert_equal :forbidden, record(actor:).code
        end
        assert_empty @referrals.shares
      end
    end
  end
end
