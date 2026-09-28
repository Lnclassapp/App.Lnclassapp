require "test_helper"

module Policies
  module Identity
    class SecondFactorPolicyTest < ActiveSupport::TestCase
      NOW = Time.utc(2026, 9, 25, 8)

      def session(role: "team", confirmed: false, verified_at: nil)
        Entities::Identity::SessionState.new(id: 1, user_id: 7, role:, created_at: NOW, last_seen_at: NOW,
                                             second_factor_verified_at: verified_at, second_factor_confirmed: confirmed)
      end

      def call(session, step, actor: nil) = SecondFactorPolicy.new.call(actor:, session:, step:)

      test "un compte team non confirmé s'enrôle" do
        assert call(session, :enroll).success?
        assert_equal [ :already_enrolled ], call(session(confirmed: true), :enroll).errors[:base]
      end

      test "un compte team confirmé vérifie une fois par session" do
        assert call(session(confirmed: true), :verify).success?
        assert_equal [ :not_enrolled ], call(session, :verify).errors[:base]
        assert_equal [ :already_verified ], call(session(confirmed: true, verified_at: NOW), :verify).errors[:base]
      end

      test "refuse hors équipe, sans session ou pour la session d'un autre" do
        assert_equal :forbidden, call(session(role: "teacher"), :enroll).code
        assert_equal :forbidden, call(nil, :verify).code
        assert_equal :forbidden, call(session, :enroll, actor: Entities::Identity::Actor.new(user_id: 8, role: :team)).code
        assert call(session, :enroll, actor: Entities::Identity::Actor.new(user_id: 7, role: :team)).success?
      end

      # ADR-0066 §4.2 : la direction a le second facteur de l'équipe.
      test "un compte de la direction s'enrôle et vérifie comme l'équipe" do
        assert call(session(role: "school_admin"), :enroll).success?
        assert call(session(role: "school_admin", confirmed: true), :verify).success?
        assert_equal :forbidden, call(session(role: "student"), :verify).code
      end

      test "une étape inconnue lève ArgumentError" do
        assert_raises(ArgumentError) { call(session, :reset) }
      end
    end
  end
end
