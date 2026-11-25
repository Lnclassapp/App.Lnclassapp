require "test_helper"

# ADR-XXXX §4.1, §4.2 : un réglage par motif automatisable, écrit avec sa ligne d'historique ; absence de ligne = décoché.
module Repositories
  module Communication
    class PushMotiveSettingRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = PushMotiveSettingRepository.new
        @admin = create_team_member
        @at = Time.utc(2026, 11, 25, 9)
      end

      def update(motive: "assignment_due", automatic: true, at: @at) = @repository.update(motive:, automatic:, by: @admin.id, at:)

      test "sans ligne, aucun motif n'est automatique" do
        assert_empty @repository.automatic_motives
        assert_empty @repository.all
      end

      test "cocher ouvre le motif et décocher le referme" do
        update
        update(motive: "quiz_prep")

        assert_equal Set["assignment_due", "quiz_prep"], @repository.automatic_motives

        update(automatic: false, at: @at + 1.hour)

        assert_equal Set["quiz_prep"], @repository.automatic_motives
        assert_equal 2, Orm::Communication::PushMotiveSetting.count
      end

      test "all rend des entités avec l'auteur et l'heure" do
        update

        setting = @repository.all.sole

        assert_instance_of Entities::Communication::PushMotiveSetting, setting
        assert_equal [ "assignment_due", true, @admin.id, @at ], [ setting.motive, setting.automatic, setting.updated_by_id, setting.updated_at ]
      end

      test "chaque écriture ajoute une ligne d'historique, jamais modifiée" do
        update
        update(automatic: false, at: @at + 1.hour)

        changes = Orm::Communication::PushMotiveSettingChange.order(:changed_at).pluck(:motive, :automatic, :changed_by_id, :changed_at)

        assert_equal [ [ "assignment_due", true, @admin.id, @at ], [ "assignment_due", false, @admin.id, @at + 1.hour ] ], changes
      end

      test "tout ou rien : si l'historique échoue, le réglage n'a pas changé" do
        update(automatic: false)

        stub_method(Orm::Communication::PushMotiveSettingChange, :create!, ->(*, **) { raise ActiveRecord::StatementInvalid, "boom" }) do
          assert_raises(ActiveRecord::StatementInvalid) { update(automatic: true, at: @at + 1.hour) }
        end

        assert_equal false, @repository.all.sole.automatic
        assert_equal 1, Orm::Communication::PushMotiveSettingChange.count
      end

      test "la base refuse un motif qui n'est pas automatisable" do
        assert_raises(ActiveRecord::StatementInvalid) { update(motive: "inactive") }
        assert_empty @repository.all
        assert_equal 0, Orm::Communication::PushMotiveSettingChange.count
      end

      test "l'historique de plus de 90 jours est purgé, pas le réglage" do
        update(at: @at - 91.days)
        update(motive: "quiz_prep")

        assert_equal 1, @repository.purge_changes_before(before: @at - 90.days)
        assert_equal 1, Orm::Communication::PushMotiveSettingChange.count
        assert_equal 2, @repository.all.size
      end
    end
  end
end
