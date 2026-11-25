require "test_helper"

# ADR-XXXX §4.1, §4.2 : une validation par jour et par motif, avec la liste figée des destinataires.
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

      def create(on_date: @day, motive: "inactive", recipients: [ [ @awa.id, "inactive:a" ], [ @kofi.id, "inactive:b" ] ], by: @staff.id, at: @at)
        @repository.create(on_date:, motive:, by:, at:, recipients:)
      end

      test "créer enregistre la validation et ses destinataires" do
        assert_equal :created, create

        approval = @repository.for_date(on_date: @day).sole

        assert_instance_of Entities::Communication::PushApproval, approval
        assert_equal [ "inactive", @staff.id, @at, 2 ], [ approval.motive, approval.approved_by_id, approval.approved_at, approval.recipients_count ]
        assert_equal 2, Orm::Communication::PushApprovalRecipient.count
      end

      test "deux validations du même motif le même jour laissent une seule ligne" do
        assert_equal :created, create
        assert_equal :already_approved, create(recipients: [ [ @awa.id, "inactive:z" ] ], by: create_team_member.id)

        assert_equal 1, Orm::Communication::PushApproval.count
        assert_equal 2, Orm::Communication::PushApprovalRecipient.count
        assert_equal @staff.id, @repository.for_date(on_date: @day).sole.approved_by_id
      end

      test "le lendemain, le même motif se valide à nouveau" do
        create

        assert_equal :created, create(on_date: @day + 1)
      end

      test "approved_keys rend les triplets élève, motif, objet du jour" do
        create
        create(on_date: @day + 1, recipients: [ [ @awa.id, "inactive:later" ] ])

        assert_equal Set[[ @awa.id, "inactive", "inactive:a" ], [ @kofi.id, "inactive", "inactive:b" ]], @repository.approved_keys(on_date: @day)
      end

      test "une liste vide se valide (zéro élève)" do
        assert_equal :created, create(recipients: [])
        assert_equal 0, @repository.for_date(on_date: @day).sole.recipients_count
      end

      test "la base refuse un motif inconnu" do
        assert_raises(ActiveRecord::StatementInvalid) { create(motive: "promo") }
      end

      test "history rend les validations depuis une date, la plus récente d'abord" do
        create(on_date: @day - 20, motive: "result", at: @at - 20.days)
        create(on_date: @day - 3, at: @at - 3.days)
        create

        assert_equal [ @at, @at - 3.days ], @repository.history(since: @at - 14.days).map(&:approved_at)
      end

      test "purge_before supprime validations et destinataires de plus de 90 jours" do
        create(on_date: @day - 100, at: @at - 100.days)
        create

        assert_equal 1, @repository.purge_before(before: @at - 90.days)
        assert_equal 1, Orm::Communication::PushApproval.count
        assert_equal 2, Orm::Communication::PushApprovalRecipient.count
      end

      test "la fabrique écrit une validation lue comme le dépôt la lit" do
        create_push_approval(on_date: @day, motive: "result", recipients: [ [ @awa.id, "result:1" ] ])
        create_push_motive_setting

        assert_equal [ "result", 1 ], @repository.for_date(on_date: @day).map { [ it.motive, it.recipients_count ] }.sole
        assert_equal Set[[ @awa.id, "result", "result:1" ]], @repository.approved_keys(on_date: @day)
        assert_equal Set["assignment_due"], PushMotiveSettingRepository.new.automatic_motives
      end

      test "supprimer l'élève supprime ses lignes de destinataire (anonymisation)" do
        create
        Orm::Communication::PushApprovalRecipient.where(user_id: @awa.id).delete_all

        assert_equal Set[[ @kofi.id, "inactive", "inactive:b" ]], @repository.approved_keys(on_date: @day)
      end
    end
  end
end
