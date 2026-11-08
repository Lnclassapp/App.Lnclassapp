require "test_helper"

module Policies
  module Billing
    class BillingPoliciesTest < ActiveSupport::TestCase
      def actor(role, team_role: nil) = Entities::Identity::Actor.new(user_id: 1, role:, team_role:)

      test "l'équipe gère la caisse, quel que soit son sous-rôle" do
        %w[admin content field].each { assert ManageBillingPolicy.new.call(actor: actor(:team, team_role: it)).success? }
      end

      test "les autres rôles et l'anonyme ne gèrent pas la caisse" do
        [ :student, :teacher, :school_admin ].each { assert_equal :forbidden, ManageBillingPolicy.new.call(actor: actor(it)).code }
        assert_equal :forbidden, ManageBillingPolicy.new.call(actor: nil).code
      end

      test "seul l'élève active une carte" do
        assert ActivateCardPolicy.new.call(actor: actor(:student)).success?
        [ :teacher, :school_admin ].each { assert_equal :forbidden, ActivateCardPolicy.new.call(actor: actor(it)).code }
        assert_equal :forbidden, ActivateCardPolicy.new.call(actor: actor(:team, team_role: "admin")).code
        assert_equal :forbidden, ActivateCardPolicy.new.call(actor: nil).code
      end

      test "le journal d'audit connaît les actions de la caisse" do
        %w[billing.relay_point_saved billing.card_batch_created billing.card_activated billing.card_cancelled
           billing.remittance_recorded].each { assert Entities::Identity::AuditAction.valid?(it), it }
      end
    end
  end
end
