require "test_helper"

# ADR-0147 §4.2, amendement du 2026-11-27 (II) : plus aucune validation n'est écrite ; celles d'avant restent lues par
# l'historique, puis purgées à 90 jours avec leurs destinataires.
module Repositories
  module Communication
    class PushApprovalRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = PushApprovalRepository.new
        @staff = create_team_member
        @awa = create_student
        @kofi = create_student
        @day = Date.new(2026, 11, 25)
        @at = Time.utc(2026, 11, 25, 10, 12)
      end

      def approve(on_date: @day, motive: "inactive", at: @at, recipients: [ [ @awa.id, "inactive:a" ], [ @kofi.id, "inactive:b" ] ])
        create_push_approval(on_date:, motive:, approved_by: @staff, approved_at: at, recipients:)
      end

      test "history rend les validations depuis une date, la plus récente d'abord, en entités" do
        approve(on_date: @day - 20, motive: "result", at: @at - 20.days)
        approve(on_date: @day - 3, at: @at - 3.days)
        approve

        history = @repository.history(since: @at - 14.days)

        assert_equal [ @at, @at - 3.days ], history.map(&:approved_at)
        assert_instance_of Entities::Communication::PushApproval, history.first
        assert_equal [ "inactive", @staff.id, 2, @day ], [ history.first.motive, history.first.approved_by_id, history.first.recipients_count, history.first.on_date ]
      end

      test "purge_before supprime validations et destinataires de plus de 90 jours" do
        approve(on_date: @day - 100, at: @at - 100.days)
        approve

        assert_equal 1, @repository.purge_before(before: @at - 90.days)
        assert_equal 1, Orm::Communication::PushApproval.count
        assert_equal 2, Orm::Communication::PushApprovalRecipient.count
      end

      test "la base refuse un motif inconnu" do
        assert_raises(ActiveRecord::StatementInvalid) { approve(motive: "promo") }
      end

      test "le port seul refuse d'être appelé" do
        bare = Class.new { include Ports::Communication::PushApprovalRepositoryPort }.new

        assert_raises(NotImplementedError) { bare.history(since: @at) }
        assert_raises(NotImplementedError) { bare.purge_before(before: @at) }
      end

      test "supprimer l'élève supprime ses lignes de destinataire (anonymisation)" do
        approve
        Orm::Communication::PushApprovalRecipient.where(user_id: @awa.id).delete_all

        assert_equal [ [ @kofi.id, "inactive:b" ] ], Orm::Communication::PushApprovalRecipient.pluck(:user_id, :object_key)
      end
    end
  end
end
