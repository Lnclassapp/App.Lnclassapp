require "test_helper"

# ADR-0146 §4.1 : un envoi par élève, motif et clé ; delivered, gone et failed sont définitifs,
# disabled, not_configured et retry sont remplacés ; 90 jours de mémoire.
module Repositories
  module Communication
    class PushDeliveryRepositoryTest < ActiveSupport::TestCase
      setup do
        @repository = PushDeliveryRepository.new
        @student = create_student
        @at = Time.utc(2026, 11, 18, 12)
      end

      def record(status, key: "k", at: @at, motive: "inactive")
        @repository.record(user_id: @student.id, motive:, object_key: key, status:, at:)
      end

      def sent?(key: "k", motive: "inactive") = @repository.sent?(user_id: @student.id, motive:, object_key: key)

      test "sent_count compte les envois delivered du jour, pas les autres statuts ni les autres jours" do
        record("delivered", key: "a", at: Time.utc(2026, 11, 18, 8))
        record("delivered", key: "b", at: Time.utc(2026, 11, 18, 23, 59))
        record("failed", key: "c", at: Time.utc(2026, 11, 18, 9))
        record("retry", key: "d", at: Time.utc(2026, 11, 18, 9))
        record("delivered", key: "e", at: Time.utc(2026, 11, 19, 0, 1))
        record("delivered", key: "f", at: Time.utc(2026, 11, 17, 23, 59))
        create_push_delivery(user: create_student, object_key: "autre", sent_at: Time.utc(2026, 11, 18, 9))

        assert_equal 2, @repository.sent_count(user_id: @student.id, on_date: Date.new(2026, 11, 18))
        assert_equal 0, @repository.sent_count(user_id: @student.id, on_date: Date.new(2026, 11, 20))
      end

      test "un envoi nouveau est enregistré" do
        assert record("delivered")
        assert_equal [ [ "inactive", "k", "delivered" ] ], Orm::Communication::PushDelivery.pluck(:motive, :object_key, :status)
      end

      test "delivered, gone et failed sont définitifs : sent? vrai, rien ne les remplace" do
        %w[delivered gone failed].each do |status|
          key = "k-#{status}"
          assert record(status, key:)

          assert sent?(key:), status
          assert_not record("delivered", key:, at: @at + 1.hour), status
          assert_equal status, Orm::Communication::PushDelivery.find_by!(object_key: key).status
          assert_equal @at, Orm::Communication::PushDelivery.find_by!(object_key: key).sent_at
        end
      end

      test "disabled, not_configured et retry ne brûlent pas le motif et sont remplacés par le nouveau statut" do
        %w[disabled not_configured retry].each do |status|
          key = "k-#{status}"
          assert record(status, key:)
          assert_not sent?(key:), status

          assert record("delivered", key:, at: @at + 1.hour), status
          row = Orm::Communication::PushDelivery.find_by!(object_key: key)
          assert_equal [ "delivered", @at + 1.hour ], [ row.status, row.sent_at ]
        end
        assert_equal 3, Orm::Communication::PushDelivery.count
      end

      test "sent? est propre à l'élève, au motif et à la clé" do
        record("delivered")

        assert_not sent?(key: "autre")
        assert_not sent?(motive: "result")
        assert_not @repository.sent?(user_id: create_student.id, motive: "inactive", object_key: "k")
      end

      test "last_sent_at est le dernier envoi delivered de l'élève, nil sans envoi parti" do
        assert_nil @repository.last_sent_at(user_id: @student.id)

        record("disabled", key: "a", at: @at + 5.hours)
        record("delivered", key: "b", at: @at)
        record("delivered", key: "c", at: @at - 1.day)

        assert_equal @at, @repository.last_sent_at(user_id: @student.id)
      end

      test "purge_before supprime les envois plus anciens et les compte" do
        record("delivered", key: "old", at: @at - 91.days)
        record("delivered", key: "new", at: @at - 89.days)

        assert_equal 1, @repository.purge_before(before: @at - 90.days)
        assert_equal [ "new" ], Orm::Communication::PushDelivery.pluck(:object_key)
      end
    end
  end
end
