require "test_helper"

# ADR XXXX (§4.1, §4.2), UDR XXXX §3.3 : un admin règle la case « Automatique » d'un motif. Une relance ne devient jamais
# automatique ; un rôle d'équipe qui n'est pas admin ne change rien ; chaque réglage écrit sa ligne d'historique.
module UseCases
  module Communication
    class UpdatePushMotiveSettingTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 11, 25, 10)
      Clock = Data.define(:now)

      class FakeSettings
        include Ports::Communication::PushMotiveSettingRepositoryPort

        attr_reader :updates

        def initialize = @updates = []

        def update(motive:, automatic:, by:, at:) = @updates << { motive:, automatic:, by:, at: }
      end

      setup do
        @settings = FakeSettings.new
        @admin = Entities::Identity::Actor.new(user_id: 9, role: :team, team_role: "admin")
      end

      def update(motive, automatic = true, actor: @admin)
        UpdatePushMotiveSetting.new(settings: @settings, policy: Policies::Communication::ManagePushSettingsPolicy.new, clock: Clock.new(NOW))
                               .call(actor:, motive:, automatic:)
      end

      test "an admin turns « devoir à rendre » automatic : written with the author and the time" do
        result = update("assignment_due")

        assert_predicate result, :success?
        assert_equal [ { motive: "assignment_due", automatic: true, by: 9, at: NOW } ], @settings.updates
        assert_equal "assignment_due", result.value.motive
      end

      test "an admin unchecks a motive" do
        assert_predicate update("quiz_prep", false), :success?
        assert_equal false, @settings.updates.sole[:automatic]
      end

      test "content and field team members are refused, nothing is written" do
        %w[content field].each do |team_role|
          actor = Entities::Identity::Actor.new(user_id: 10, role: :team, team_role:)

          assert_equal :forbidden, update("assignment_due", actor:).code
        end
        assert_empty @settings.updates
      end

      test "a teacher, a student, a school admin and a visitor are refused" do
        [ :teacher, :student, :school_admin ].each do |role|
          assert_equal :forbidden, update("assignment_due", actor: Entities::Identity::Actor.new(user_id: 3, role:)).code
        end
        assert_equal :forbidden, update("assignment_due", actor: nil).code
        assert_empty @settings.updates
      end

      test "a reminder or an unknown motive cannot become automatic, even forged" do
        %w[inactive unfinished result announcement unknown].each do |motive|
          result = update(motive)

          assert_equal :invalid, result.code, motive
        end
        assert_empty @settings.updates
      end
    end
  end
end
